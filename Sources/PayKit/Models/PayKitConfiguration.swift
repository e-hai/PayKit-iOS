import Foundation

/// PayKit 初始化配置
public struct PayKitConfiguration: Sendable {
    /// 自动续期或非续期订阅商品 ID 集合
    public let subsProductIds: Set<String>
    /// 消耗型商品 ID 集合（购买后需发货并 finish）
    public let consumableProductIds: Set<String>
    /// 非消耗型商品 ID 集合（购买后永久生效）
    public let nonConsumableProductIds: Set<String>
    /// 自定义验签器（默认 LocalPurchaseVerifier）
    public let purchaseVerifier: PurchaseVerifier

    public init(
        subsProductIds: Set<String> = [],
        consumableProductIds: Set<String> = [],
        nonConsumableProductIds: Set<String> = [],
        purchaseVerifier: PurchaseVerifier = LocalPurchaseVerifier.shared
    ) {
        self.subsProductIds = subsProductIds
        self.consumableProductIds = consumableProductIds
        self.nonConsumableProductIds = nonConsumableProductIds
        self.purchaseVerifier = purchaseVerifier
    }

    /// 所有已注册的商品 ID 集合
    public var allProductIds: Set<String> {
        subsProductIds.union(consumableProductIds).union(nonConsumableProductIds)
    }

    /// 校验配置合法性（检查是否有重叠）
    public func validate() -> Result<Void, PayKitError> {
        let subsIntersectConsumable = subsProductIds.intersection(consumableProductIds)
        if !subsIntersectConsumable.isEmpty {
            return .failure(PayKitError(code: .unknown, message: "Configuration error: IDs appear in both subs and consumable: \(subsIntersectConsumable)"))
        }
        let subsIntersectNonConsumable = subsProductIds.intersection(nonConsumableProductIds)
        if !subsIntersectNonConsumable.isEmpty {
            return .failure(PayKitError(code: .unknown, message: "Configuration error: IDs appear in both subs and non-consumable: \(subsIntersectNonConsumable)"))
        }
        let consumableIntersectNonConsumable = consumableProductIds.intersection(nonConsumableProductIds)
        if !consumableIntersectNonConsumable.isEmpty {
            return .failure(PayKitError(code: .unknown, message: "Configuration error: IDs appear in both consumable and non-consumable: \(consumableIntersectNonConsumable)"))
        }
        return .success(())
    }
}
