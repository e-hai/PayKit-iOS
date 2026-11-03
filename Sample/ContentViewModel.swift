import Foundation
import Combine
import PayKit

public enum UserTier: String, CaseIterable, Identifiable {
    case free = "Free"
    case plus = "Plus"
    case pro = "Pro"

    public var id: String { rawValue }
}

@MainActor
public final class ContentViewModel: ObservableObject {
    @Published public var currentTier: UserTier = .free
    @Published public var selectedTier: UserTier = .pro
    @Published public var products: [StoreProduct] = []
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    @Published public var activeSubscriptions: Set<String> = []
    @Published public var nonConsumables: Set<String> = []
    @Published public var coinBalance: Int = 0

    private var listener: UpdatedCustomerInfoListener?

    public init() {
        setupPayKit()
    }

    private func setupPayKit() {
        let config = PayKitConfiguration(
            subsProductIds: Constants.allSubs,
            consumableProductIds: Constants.allConsumables,
            nonConsumableProductIds: Constants.allNonConsumables
        )
        PayKit.configure(configuration: config)

        // 注册权益监听
        let listenerObj = ClosureCustomerInfoListener { [weak self] customerInfo in
            Task { @MainActor [weak self] in
                self?.handleCustomerInfo(customerInfo)
            }
        }
        self.listener = listenerObj
        PayKit.shared.setUpdatedCustomerInfoListener(listenerObj)

        // 加载初始商品与权益
        Task {
            await loadProducts()
            if let initialInfo = await PayKit.shared.getCustomerInfo(forceSync: false) {
                handleCustomerInfo(initialInfo)
            }
        }
    }

    public func loadProducts() async {
        isLoading = true
        let allIds = Constants.allSubs.union(Constants.allConsumables).union(Constants.allNonConsumables)
        let result = await PayKit.shared.getProducts(productIds: allIds)
        isLoading = false

        switch result {
        case .success(let prods):
            self.products = prods
            LogUtil.i(LogUtil.tagSample, "loadProducts completed, loaded count=\(prods.count)")
        case .failure(let error):
            self.errorMessage = "加载商品失败: \(error.message)"
            LogUtil.e(LogUtil.tagSample, "loadProducts failed: \(error.message)")
        }
    }

    public func purchase(product: StoreProduct) {
        isLoading = true
        errorMessage = nil

        let callback = ClosurePurchaseCallback(
            onCompleted: { [weak self] txn in
                Task { @MainActor [weak self] in
                    self?.isLoading = false
                    if txn.productIds.contains(Constants.inappCoins100) {
                        self?.coinBalance += 100
                    }
                }
            },
            onPending: { [weak self] txn in
                Task { @MainActor [weak self] in
                    self?.isLoading = false
                    self?.errorMessage = "交易待授权，请耐心等待或联系家长"
                }
            },
            onError: { [weak self] error in
                Task { @MainActor [weak self] in
                    self?.isLoading = false
                    if error.code != .purchaseCancelled {
                        self?.errorMessage = error.message
                    }
                }
            }
        )

        PayKit.shared.purchase(storeProduct: product, callback: callback)
    }

    public func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        let result = await PayKit.shared.restorePurchases()
        isLoading = false

        switch result {
        case .success(let info):
            handleCustomerInfo(info)
        case .failure(let error):
            self.errorMessage = "恢复购买失败: \(error.message)"
        }
    }

    private func handleCustomerInfo(_ info: CustomerInfo) {
        self.activeSubscriptions = info.activeSubscriptions
        self.nonConsumables = info.nonConsumablePurchases

        // 判定档位：Pro > Plus > Free
        if info.activeSubscriptions.contains(Constants.subsProMonthly) ||
            info.activeSubscriptions.contains(Constants.subsProYearly) ||
            info.nonConsumablePurchases.contains(Constants.inappLifetime) {
            self.currentTier = .pro
        } else if info.activeSubscriptions.contains(Constants.subsPlusMonthly) ||
                    info.activeSubscriptions.contains(Constants.subsPlusYearly) {
            self.currentTier = .plus
        } else {
            self.currentTier = .free
        }

        // 处理未履约消耗品（补单逻辑）
        for unfulfilled in info.unfulfilledConsumables {
            if unfulfilled.productIds.contains(Constants.inappCoins100) {
                self.coinBalance += 100
                Task {
                    _ = await PayKit.shared.markConsumableFulfilled(purchaseToken: unfulfilled.purchaseToken)
                }
            }
        }
    }
}
