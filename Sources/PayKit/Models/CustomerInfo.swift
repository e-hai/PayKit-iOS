import Foundation

/// 本地计算的用户权益快照（无后端设计，由本地订单与商店凭证计算而来）
public struct CustomerInfo: Codable, Equatable, Sendable {
    /// 当前生效的活跃订阅商品 ID 集合
    public let activeSubscriptions: Set<String>
    /// 已持有的非消耗品商品 ID 集合
    public let nonConsumablePurchases: Set<String>
    /// 当前商店查询到的所有交易快照
    public let allPurchaseRecords: [StoreTransaction]
    /// 待宿主发货/确认的消耗品订单列表
    public let unfulfilledConsumables: [StoreTransaction]

    /// 计算属性：待批准/待支付订单
    public var pendingPurchases: [StoreTransaction] {
        allPurchaseRecords.filter { $0.purchaseState == .pending }
    }

    /// 计算属性：已成功支付订单
    public var purchasedRecords: [StoreTransaction] {
        allPurchaseRecords.filter { $0.purchaseState == .purchased }
    }

    public init(
        activeSubscriptions: Set<String> = [],
        nonConsumablePurchases: Set<String> = [],
        allPurchaseRecords: [StoreTransaction] = [],
        unfulfilledConsumables: [StoreTransaction] = []
    ) {
        self.activeSubscriptions = activeSubscriptions
        self.nonConsumablePurchases = nonConsumablePurchases
        self.allPurchaseRecords = allPurchaseRecords
        self.unfulfilledConsumables = unfulfilledConsumables
    }
}
