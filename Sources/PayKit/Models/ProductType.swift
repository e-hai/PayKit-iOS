import Foundation

/// 商品类型枚举：对齐 Play Billing 与 StoreKit 2 的概念模型。
public enum ProductType: String, Codable, Sendable {
    /// 自动续期订阅或非续期订阅
    case subs = "SUBS"
    /// 一次性购买（消耗型或非消耗型）
    case inapp = "INAPP"
}
