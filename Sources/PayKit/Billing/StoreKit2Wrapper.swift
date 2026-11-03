import Foundation
import StoreKit

/// 基于 StoreKit 2 的支付引擎实现
public final class StoreKit2Wrapper: BillingAbstract, @unchecked Sendable {
    private let configuration: PayKitConfiguration
    private let consumableLedger: ConsumableLedger
    private var updatesTask: Task<Void, Never>?
    private let syncQueue = DispatchQueue(label: "com.kit.pay.billing.syncQueue")

    /// 进行中的单笔购买回调（防止重复发起）
    private var activePurchaseCallback: PurchaseCallback?

    /// 外部更新通知回调（例如后台续费、家庭共享、家长同意后系统下发）
    public var onExternalPurchaseUpdated: (@Sendable (StoreTransaction) -> Void)?

    public init(configuration: PayKitConfiguration, consumableLedger: ConsumableLedger) {
        self.configuration = configuration
        self.consumableLedger = consumableLedger
    }

    deinit {
        endConnection()
    }

    public func startConnection() throws {
        syncQueue.sync {
            guard updatesTask == nil else { return }

            LogUtil.d(LogUtil.tagBilling, "startConnection: listening to Transaction.updates")
            updatesTask = Task.detached(priority: .background) { [weak self] in
                for await verificationResult in Transaction.updates {
                    guard let self = self else { return }
                    await self.handleIncomingTransaction(verificationResult)
                }
            }
        }
    }

    public func endConnection() {
        syncQueue.sync {
            updatesTask?.cancel()
            updatesTask = nil
            LogUtil.d(LogUtil.tagBilling, "endConnection: stopped Transaction.updates")
        }
    }

    public func queryProductDetails(productIds: Set<String>) async throws -> [StoreProduct] {
        guard !productIds.isEmpty else { return [] }

        LogUtil.d(LogUtil.tagBilling, "queryProductDetails ids=\(productIds)")
        do {
            let products = try await Product.products(for: productIds)
            return products.map { product in
                let isSubs = (product.type == .autoRenewable || product.type == .nonRenewable)
                let type: ProductType = isSubs ? .subs : .inapp

                // 计算微单位价格
                let priceAmountMicros = Int64(truncating: (product.price * 1_000_000) as NSDecimalNumber)

                var subPeriod: String? = nil
                var hasTrial = false
                var trialPeriodStr: String? = nil

                if let subscription = product.subscription {
                    subPeriod = formatSubscriptionPeriod(subscription.subscriptionPeriod)
                    if let intro = subscription.introductoryOffer, intro.paymentMode == .freeTrial {
                        hasTrial = true
                        trialPeriodStr = formatSubscriptionPeriod(intro.period)
                    }
                }

                return StoreProduct(
                    productId: product.id,
                    type: type,
                    title: product.displayName,
                    description: product.description,
                    price: product.displayPrice,
                    priceAmountMicros: priceAmountMicros,
                    priceCurrencyCode: product.priceFormatStyle.currencyCode,
                    subscriptionPeriod: subPeriod,
                    hasFreeTrial: hasTrial,
                    freeTrialPeriod: trialPeriodStr,
                    nativeProduct: product
                )
            }
        } catch {
            LogUtil.e(LogUtil.tagBilling, "queryProductDetails fail", error: error)
            throw PayKitError(code: .storeProblem, message: "Failed to query products from StoreKit 2", underlyingError: error)
        }
    }

    public func queryPurchases() async throws -> (subs: [StoreTransaction], inapp: [StoreTransaction]) {
        LogUtil.d(LogUtil.tagBilling, "queryPurchases starting")
        var subsList: [StoreTransaction] = []
        var inappList: [StoreTransaction] = []

        // 1. 查询当前有效权益 (Current Entitlements)
        for await verification in Transaction.currentEntitlements {
            guard case .verified(let transaction) = verification else {
                continue
            }
            let txn = makeStoreTransaction(from: transaction, rawJWS: verification.jwsRepresentation)
            if configuration.subsProductIds.contains(transaction.productID) {
                subsList.append(txn)
            } else {
                inappList.append(txn)
            }
        }

        // 2. 查询未完成的交易（包含待履约或挂起的消耗品）
        for await verification in Transaction.unfinished {
            guard case .verified(let transaction) = verification else {
                continue
            }
            if configuration.consumableProductIds.contains(transaction.productID) {
                let txn = makeStoreTransaction(from: transaction, rawJWS: verification.jwsRepresentation)
                if !inappList.contains(where: { $0.purchaseToken == txn.purchaseToken }) {
                    inappList.append(txn)
                }
            }
        }

        LogUtil.d(LogUtil.tagBilling, "queryPurchases done subs=\(subsList.count) inapp=\(inappList.count)")
        return (subsList, inappList)
    }

    public func launchBillingFlow(
        storeProduct: StoreProduct,
        callback: PurchaseCallback
    ) {
        let isBusy: Bool = syncQueue.sync {
            if activePurchaseCallback != nil {
                return true
            }
            activePurchaseCallback = callback
            return false
        }

        if isBusy {
            LogUtil.w(LogUtil.tagBilling, "launchBillingFlow rejected: purchase already in progress")
            MainActorHelper.runOnMain {
                callback.onError(error: PayKitError(
                    code: .purchaseInProgress,
                    message: "A purchase is already in progress. Please wait."
                ))
            }
            return
        }

        Task { [weak self] in
            guard let self = self else { return }
            await self.executePurchase(storeProduct: storeProduct)
        }
    }

    public func finishTransaction(purchaseToken: String) async throws {
        LogUtil.d(LogUtil.tagBilling, "finishTransaction token=\(purchaseToken)")
        for await verification in Transaction.unfinished {
            if case .verified(let transaction) = verification {
                if String(transaction.id) == purchaseToken {
                    await transaction.finish()
                    consumableLedger.remove(purchaseToken: purchaseToken)
                    LogUtil.d(LogUtil.tagBilling, "finishTransaction finished id=\(transaction.id)")
                    return
                }
            }
        }
        // 若在 unfinished 中未找到（可能已被系统或其他流程 finish），仍清理账本
        consumableLedger.remove(purchaseToken: purchaseToken)
    }

    // MARK: - Private Execution

    private func executePurchase(storeProduct: StoreProduct) async {
        let callback: PurchaseCallback? = syncQueue.sync {
            return activePurchaseCallback
        }

        guard let currentCallback = callback else { return }

        // 获取 StoreKit.Product
        let targetProduct: Product
        if let native = storeProduct.nativeProduct {
            targetProduct = native
        } else {
            do {
                let queried = try await Product.products(for: [storeProduct.productId])
                guard let first = queried.first else {
                    notifyError(currentCallback, error: PayKitError(
                        code: .productNotAvailable,
                        message: "Product \(storeProduct.productId) not found in StoreKit."
                    ))
                    return
                }
                targetProduct = first
            } catch {
                notifyError(currentCallback, error: PayKitError(
                    code: .storeProblem,
                    message: "Failed to fetch product details before purchase",
                    underlyingError: error
                ))
                return
            }
        }

        // 调用购买
        do {
            let purchaseResult = try await targetProduct.purchase()
            switch purchaseResult {
            case .success(let verificationResult):
                await handlePurchaseSuccess(verificationResult, callback: currentCallback)

            case .userCancelled:
                LogUtil.i(LogUtil.tagBilling, "purchase user cancelled product=\(storeProduct.productId)")
                notifyError(currentCallback, error: PayKitError(
                    code: .purchaseCancelled,
                    message: "User cancelled the purchase."
                ))

            case .pending:
                LogUtil.i(LogUtil.tagBilling, "purchase pending product=\(storeProduct.productId)")
                let pendingTxn = StoreTransaction(
                    productIds: [storeProduct.productId],
                    purchaseToken: UUID().uuidString,
                    purchaseState: .pending
                )
                MainActorHelper.runOnMain {
                    currentCallback.onPending(transaction: pendingTxn)
                }
                clearActiveCallback()

            @unknown default:
                notifyError(currentCallback, error: PayKitError(
                    code: .unknown,
                    message: "Unknown purchase result state"
                ))
            }
        } catch {
            LogUtil.e(LogUtil.tagBilling, "purchase failed product=\(storeProduct.productId)", error: error)
            notifyError(currentCallback, error: PayKitError(
                code: .storeProblem,
                message: "Purchase execution failed: \(error.localizedDescription)",
                underlyingError: error
            ))
        }
    }

    private func handlePurchaseSuccess(
        _ verificationResult: VerificationResult<Transaction>,
        callback: PurchaseCallback
    ) async {
        switch verificationResult {
        case .unverified(let transaction, let verificationError):
            LogUtil.e(LogUtil.tagBilling, "purchase verification failed id=\(transaction.id)", error: verificationError)
            notifyError(callback, error: PayKitError(
                code: .verificationFailed,
                message: "StoreKit 2 transaction verification failed",
                underlyingError: verificationError
            ))

        case .verified(let transaction):
            let txn = makeStoreTransaction(from: transaction, rawJWS: verificationResult.jwsRepresentation)
            let isConsumable = configuration.consumableProductIds.contains(transaction.productID)

            if isConsumable {
                // 1. 先记账本（防止发货后崩溃导致凭据丢失）
                consumableLedger.recordPendingFulfill(purchaseToken: txn.purchaseToken, productId: transaction.productID)

                // 2. 验签扩展（若配置了服务端验单）
                let verifyResult = await configuration.purchaseVerifier.verify(transaction: txn)
                switch verifyResult {
                case .success:
                    // 3. 通知宿主发货
                    MainActorHelper.runOnMain {
                        callback.onCompleted(transaction: txn)
                    }
                    clearActiveCallback()

                    // 4. 发货完成后 finish 交易并清理账本
                    await transaction.finish()
                    consumableLedger.remove(purchaseToken: txn.purchaseToken)
                    LogUtil.i(LogUtil.tagBilling, "consumable completed and finished token=\(txn.purchaseToken)")

                case .failure(let error):
                    LogUtil.e(LogUtil.tagBilling, "verifier rejected transaction", error: error)
                    notifyError(callback, error: error)
                }

            } else {
                // 订阅或非消耗品
                let verifyResult = await configuration.purchaseVerifier.verify(transaction: txn)
                switch verifyResult {
                case .success:
                    await transaction.finish()
                    MainActorHelper.runOnMain {
                        callback.onCompleted(transaction: txn)
                    }
                    clearActiveCallback()
                    LogUtil.i(LogUtil.tagBilling, "purchase completed and finished orderId=\(txn.orderId ?? "")")

                case .failure(let error):
                    notifyError(callback, error: error)
                }
            }
        }
    }

    private func handleIncomingTransaction(_ verificationResult: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = verificationResult else { return }
        let txn = makeStoreTransaction(from: transaction, rawJWS: verificationResult.jwsRepresentation)
        LogUtil.i(LogUtil.tagBilling, "incoming transaction update id=\(transaction.id) product=\(transaction.productID)")

        // 如果是订阅或非消耗品，自动 finish
        if !configuration.consumableProductIds.contains(transaction.productID) {
            await transaction.finish()
        }

        onExternalPurchaseUpdated?(txn)
    }

    private func notifyError(_ callback: PurchaseCallback, error: PayKitError) {
        clearActiveCallback()
        MainActorHelper.runOnMain {
            callback.onError(error: error)
        }
    }

    private func clearActiveCallback() {
        syncQueue.sync {
            activePurchaseCallback = nil
        }
    }

    private func makeStoreTransaction(from transaction: Transaction, rawJWS: String) -> StoreTransaction {
        let purchaseTime = Int64(transaction.purchaseDate.timeIntervalSince1970 * 1000)
        let token = String(transaction.id)

        let isRevoked = (transaction.revocationDate != nil)
        let isExpired: Bool
        if let expiration = transaction.expirationDate {
            isExpired = expiration <= Date()
        } else {
            isExpired = false
        }

        let state: PurchaseState
        if isRevoked || isExpired {
            state = .unspecified
        } else {
            state = .purchased
        }

        let jsonString = String(data: transaction.jsonRepresentation, encoding: .utf8)

        return StoreTransaction(
            orderId: String(transaction.id),
            originalTransactionId: String(transaction.originalID),
            productIds: [transaction.productID],
            purchaseTime: purchaseTime,
            purchaseToken: token,
            purchaseState: state,
            isAutoRenewing: true,
            isSuspended: false,
            expirationDate: transaction.expirationDate,
            revocationDate: transaction.revocationDate,
            signature: rawJWS,
            originalJson: jsonString
        )
    }

    private func formatSubscriptionPeriod(_ period: Product.SubscriptionPeriod) -> String {
        switch period.unit {
        case .day: return "P\(period.value)D"
        case .week: return "P\(period.value)W"
        case .month: return "P\(period.value)M"
        case .year: return "P\(period.value)Y"
        @unknown default: return "P\(period.value)M"
        }
    }
}
