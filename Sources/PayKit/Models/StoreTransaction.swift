import Foundation

/// 统一的商店交易记录
public struct StoreTransaction: Codable, Equatable, Sendable {
    /// 商店订单号 / 交易 ID
    public let orderId: String?
    /// 原始交易 ID（订阅续期、重购等保留的初次购买 ID）
    public let originalTransactionId: String?
    /// 购买关联的商品 ID 列表
    public let productIds: [String]
    /// 购买时间戳（毫秒）
    public let purchaseTime: Int64
    /// 交易凭据 Token（在 iOS 上可为 JWS 签名串或 transactionId）
    public let purchaseToken: String
    /// 购买状态
    public let purchaseState: PurchaseState
    /// 订阅是否自动续期
    public let isAutoRenewing: Bool
    /// 订阅是否处于中止/扣款失败保留期
    public let isSuspended: Bool
    /// 订阅到期时间（若适用）
    public let expirationDate: Date?
    /// 撤销时间（若退款、家长撤销等）
    public let revocationDate: Date?
    /// JWS 签名或收据签名
    public let signature: String?
    /// 原始 JSON / Payload
    public let originalJson: String?

    public init(
        orderId: String? = nil,
        originalTransactionId: String? = nil,
        productIds: [String] = [],
        purchaseTime: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        purchaseToken: String,
        purchaseState: PurchaseState = .purchased,
        isAutoRenewing: Bool = false,
        isSuspended: Bool = false,
        expirationDate: Date? = nil,
        revocationDate: Date? = nil,
        signature: String? = nil,
        originalJson: String? = nil
    ) {
        self.orderId = orderId
        self.originalTransactionId = originalTransactionId
        self.productIds = productIds
        self.purchaseTime = purchaseTime
        self.purchaseToken = purchaseToken
        self.purchaseState = purchaseState
        self.isAutoRenewing = isAutoRenewing
        self.isSuspended = isSuspended
        self.expirationDate = expirationDate
        self.revocationDate = revocationDate
        self.signature = signature
        self.originalJson = originalJson
    }
}
