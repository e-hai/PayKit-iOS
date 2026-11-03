import Foundation

/// 购买状态枚举
public enum PurchaseState: String, Codable, Sendable {
    /// 已成功购买且有效
    case purchased = "PURCHASED"
    /// 待支付或家长控制待批准（Ask to Buy / SCA）
    case pending = "PENDING"
    /// 未指定或未知状态
    case unspecified = "UNSPECIFIED"
}
