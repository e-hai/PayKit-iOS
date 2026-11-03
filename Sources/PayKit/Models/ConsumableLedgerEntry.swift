import Foundation

/// 待 finish/consume 的消耗品账本条目
public struct ConsumableLedgerEntry: Codable, Equatable, Sendable {
    /// 唯一交易标识 / Token
    public let purchaseToken: String
    /// 商品 ID
    public let productId: String
    /// 记录添加时间戳（毫秒）
    public let addedAt: Int64

    public init(
        purchaseToken: String,
        productId: String,
        addedAt: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) {
        self.purchaseToken = purchaseToken
        self.productId = productId
        self.addedAt = addedAt
    }
}
