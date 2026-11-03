import Foundation
import StoreKit

/// PayKit iOS 门面单例类
public final class PayKit: @unchecked Sendable {
    // MARK: - Singleton & Config

    private static var instance: PayKit?
    private static let lock = NSLock()

    /// 单例访问入口
    public static var shared: PayKit {
        lock.lock()
        defer { lock.unlock() }
        guard let inst = instance else {
            fatalError("PayKit must be configured before accessing PayKit.shared. Call PayKit.configure(configuration:) first.")
        }
        return inst
    }

    /// 初始化配置（幂等：仅首次调用生效，除非调用 reset）
    public static func configure(configuration: PayKitConfiguration) {
        lock.lock()
        defer { lock.unlock() }

        if instance != nil {
            LogUtil.w(LogUtil.tagGeneral, "PayKit is already configured. Ignoring configure call.")
            return
        }

        if case .failure(let error) = configuration.validate() {
            LogUtil.e(LogUtil.tagGeneral, "PayKitConfiguration validation failed: \(error.message)")
        }

        let newInstance = PayKit(configuration: configuration)
        instance = newInstance
        LogUtil.i(LogUtil.tagGeneral, "PayKit configured successfully.")

        try? newInstance.billing.startConnection()
        Task {
            _ = await newInstance.syncPurchases()
        }
    }

    /// 重置单例状态（测试或切换账号时使用）
    public static func reset(clearCache: Bool = true) {
        lock.lock()
        let old = instance
        instance = nil
        lock.unlock()

        if let oldInstance = old {
            oldInstance.billing.endConnection()
            if clearCache {
                oldInstance.deviceCache.clear()
                oldInstance.consumableLedger.clear()
            }
        }
        LogUtil.i(LogUtil.tagGeneral, "PayKit reset (clearCache=\(clearCache))")
    }

    // MARK: - Internal State

    public private(set) var configuration: PayKitConfiguration
    private let deviceCache: DeviceCache
    private let consumableLedger: ConsumableLedger
    private let billing: StoreKit2Wrapper
    private let stateLock = NSLock()

    private weak var customerInfoListener: UpdatedCustomerInfoListener?
    private var streamContinuation: AsyncStream<CustomerInfo>.Continuation?

    /// 权益变动的 AsyncStream，支持现代 SwiftUI Task 监听
    public private(set) lazy var customerInfoStream: AsyncStream<CustomerInfo> = {
        AsyncStream { continuation in
            self.streamContinuation = continuation
            // 发送初始缓存快照
            if let cached = self.deviceCache.getCustomerInfo() {
                continuation.yield(cached)
            }
        }
    }()

    private init(configuration: PayKitConfiguration) {
        self.configuration = configuration
        self.deviceCache = DeviceCache()
        self.consumableLedger = ConsumableLedger()
        self.billing = StoreKit2Wrapper(
            configuration: configuration,
            consumableLedger: self.consumableLedger
        )

        // 外部更新绑定
        self.billing.onExternalPurchaseUpdated = { [weak self] _ in
            guard let self = self else { return }
            Task {
                _ = await self.syncPurchases()
            }
        }
    }

    // MARK: - Public APIs

    /// 查询商品详情
    public func getProducts(productIds: Set<String>) async -> Result<[StoreProduct], PayKitError> {
        // 校验请求的 ID 是否包含在配置中
        let unregistered = productIds.subtracting(configuration.allProductIds)
        if !unregistered.isEmpty {
            LogUtil.w(LogUtil.tagGeneral, "getProducts contains unregistered ids=\(unregistered)")
        }
        if productIds.isDisjoint(with: configuration.allProductIds) {
            return .failure(PayKitError(
                code: .productNotAvailable,
                message: "None of the requested product IDs are declared in PayKitConfiguration."
            ))
        }

        do {
            let products = try await billing.queryProductDetails(productIds: productIds)
            return .success(products)
        } catch let error as PayKitError {
            return .failure(error)
        } catch {
            return .failure(PayKitError(code: .storeProblem, message: error.localizedDescription, underlyingError: error))
        }
    }

    /// 获取当前用户权益
    /// - Parameter forceSync: 是否强制联网从 StoreKit 2 同步（默认为 true；启动首屏建议 false 先读缓存）
    public func getCustomerInfo(forceSync: Bool = true) async -> CustomerInfo? {
        if !forceSync {
            if let cached = deviceCache.getCustomerInfo() {
                return cached
            }
        }
        let syncResult = await syncPurchases()
        switch syncResult {
        case .success(let info):
            return info
        case .failure:
            return deviceCache.getCustomerInfo()
        }
    }

    /// 显式同步购买记录并刷新权益快照
    public func syncPurchases() async -> Result<CustomerInfo, PayKitError> {
        LogUtil.d(LogUtil.tagGeneral, "syncPurchases start")
        do {
            let (subs, inapp) = try await billing.queryPurchases()
            let newCustomerInfo = CustomerInfoHelper.computeCustomerInfo(
                configuration: configuration,
                subsTransactions: subs,
                inappTransactions: inapp,
                consumableLedger: consumableLedger
            )

            // 持久化并通知
            deviceCache.cacheCustomerInfo(newCustomerInfo)
            notifyCustomerInfoUpdated(newCustomerInfo)

            LogUtil.i(LogUtil.tagGeneral, "syncPurchases done success=true activeSubs=\(newCustomerInfo.activeSubscriptions.count) nonConsumable=\(newCustomerInfo.nonConsumablePurchases.count) unfulfilled=\(newCustomerInfo.unfulfilledConsumables.count)")
            return .success(newCustomerInfo)
        } catch let error as PayKitError {
            LogUtil.e(LogUtil.tagGeneral, "syncPurchases failed", error: error)
            return .failure(error)
        } catch {
            let wrapped = PayKitError(code: .storeProblem, message: error.localizedDescription, underlyingError: error)
            LogUtil.e(LogUtil.tagGeneral, "syncPurchases failed", error: wrapped)
            return .failure(wrapped)
        }
    }

    /// 恢复购买（对齐 Android 与 Apple 产品语义，底层执行同步与权益计算）
    public func restorePurchases() async -> Result<CustomerInfo, PayKitError> {
        LogUtil.i(LogUtil.tagGeneral, "restorePurchases called")
        // StoreKit 2 触发 AppStore 同步
        try? await AppStore.sync()
        return await syncPurchases()
    }

    /// 获取待确认/处理的交易列表
    public func getPendingPurchases() async -> [StoreTransaction] {
        if let info = await getCustomerInfo(forceSync: false) {
            return info.pendingPurchases
        }
        return []
    }

    /// 获取所有购买历史记录快照
    public func getPurchaseHistory() async -> [StoreTransaction] {
        if let info = await getCustomerInfo(forceSync: false) {
            return info.allPurchaseRecords
        }
        return []
    }

    /// 根据 purchaseToken (transactionId) 查找交易
    public func findTransaction(purchaseToken: String) -> StoreTransaction? {
        guard let cached = deviceCache.getCustomerInfo() else { return nil }
        return cached.allPurchaseRecords.first { $0.purchaseToken == purchaseToken }
    }

    /// 查找指定商品 ID 的活跃订阅交易
    public func findActiveSubscription(productId: String) -> StoreTransaction? {
        guard let cached = deviceCache.getCustomerInfo(),
              cached.activeSubscriptions.contains(productId) else { return nil }
        return cached.allPurchaseRecords.first {
            $0.productIds.contains(productId) && $0.purchaseState == .purchased
        }
    }

    /// 获取账本中已发货但待 finish 的消耗品
    public func getConsumablesPendingConsume() -> [ConsumableLedgerEntry] {
        return consumableLedger.allEntries()
    }

    /// 宿主补单发货后调用此方法消单（finish 交易并清理账本）
    public func markConsumableFulfilled(purchaseToken: String) async -> Result<Void, PayKitError> {
        LogUtil.i(LogUtil.tagGeneral, "markConsumableFulfilled token=\(purchaseToken)")
        do {
            try await billing.finishTransaction(purchaseToken: purchaseToken)
            _ = await syncPurchases()
            return .success(())
        } catch let error as PayKitError {
            return .failure(error)
        } catch {
            return .failure(PayKitError(code: .storeProblem, message: error.localizedDescription, underlyingError: error))
        }
    }

    /// 发起购买（回调方式）
    public func purchase(
        storeProduct: StoreProduct,
        callback: PurchaseCallback
    ) {
        LogUtil.i(LogUtil.tagGeneral, "purchase start productId=\(storeProduct.productId)")
        billing.launchBillingFlow(
            storeProduct: storeProduct,
            callback: InternalPurchaseCallbackWrapper(
                wrapped: callback,
                onSuccess: { [weak self] in
                    Task {
                        _ = await self?.syncPurchases()
                    }
                }
            )
        )
    }

    /// 发起购买（现代 async/await 方式）
    public func purchase(storeProduct: StoreProduct) async -> Result<StoreTransaction, PayKitError> {
        await withCheckedContinuation { continuation in
            let callback = ClosurePurchaseCallback(
                onCompleted: { txn in
                    continuation.resume(returning: .success(txn))
                },
                onPending: { txn in
                    continuation.resume(returning: .failure(PayKitError(
                        code: .purchasePending,
                        message: "Purchase is pending authorization"
                    )))
                },
                onError: { err in
                    continuation.resume(returning: .failure(err))
                }
            )
            self.purchase(storeProduct: storeProduct, callback: callback)
        }
    }

    /// 设置权益监听器（主线程分发）
    public func setUpdatedCustomerInfoListener(_ listener: UpdatedCustomerInfoListener?) {
        stateLock.lock()
        defer { stateLock.unlock() }
        self.customerInfoListener = listener
    }

    /// 运行时替换验单器
    public func setPurchaseVerifier(_ verifier: PurchaseVerifier) {
        stateLock.lock()
        defer { stateLock.unlock() }
        self.configuration = PayKitConfiguration(
            subsProductIds: configuration.subsProductIds,
            consumableProductIds: configuration.consumableProductIds,
            nonConsumableProductIds: configuration.nonConsumableProductIds,
            purchaseVerifier: verifier
        )
    }

    // MARK: - Private Helpers

    private func notifyCustomerInfoUpdated(_ customerInfo: CustomerInfo) {
        MainActorHelper.runOnMain { [weak self] in
            guard let self = self else { return }
            self.customerInfoListener?.onCustomerInfoUpdated(customerInfo)
            self.streamContinuation?.yield(customerInfo)
        }
    }
}

/// 内部包装回调，购买成功后自动触发权益同步
private final class InternalPurchaseCallbackWrapper: PurchaseCallback, @unchecked Sendable {
    private let wrapped: PurchaseCallback
    private let onSuccess: @Sendable () -> Void

    init(wrapped: PurchaseCallback, onSuccess: @escaping @Sendable () -> Void) {
        self.wrapped = wrapped
        self.onSuccess = onSuccess
    }

    func onCompleted(transaction: StoreTransaction) {
        wrapped.onCompleted(transaction: transaction)
        onSuccess()
    }

    func onPending(transaction: StoreTransaction) {
        wrapped.onPending(transaction: transaction)
    }

    func onError(error: PayKitError) {
        wrapped.onError(error: error)
    }
}
