import Foundation

/// 统一的 PayKit 错误码定义（与 Android 保持一致）
public enum PayKitErrorCode: String, Codable, Sendable {
    /// 商店服务异常或连接失败
    case storeProblem = "STORE_PROBLEM"
    /// 用户主动取消购买
    case purchaseCancelled = "PURCHASE_CANCELLED"
    /// 购买待决（家长控制 Ask to Buy / 银行二次验证）
    case purchasePending = "PURCHASE_PENDING"
    /// 已有购买正在进行中，防止重复点击
    case purchaseInProgress = "PURCHASE_IN_PROGRESS"
    /// 设备或账号被限制内购
    case purchaseNotAllowed = "PURCHASE_NOT_ALLOWED"
    /// 请求的商品不可用或未找到
    case productNotAvailable = "PRODUCT_NOT_AVAILABLE"
    /// 用户已拥有该商品
    case itemAlreadyOwned = "ITEM_ALREADY_OWNED"
    /// 签名/凭据校验失败
    case verificationFailed = "VERIFICATION_FAILED"
    /// 网络异常
    case networkError = "NETWORK_ERROR"
    /// 未知异常
    case unknown = "UNKNOWN"
}

/// 统一的 PayKit 错误对象
public struct PayKitError: Error, CustomStringConvertible, Sendable {
    public let code: PayKitErrorCode
    public let message: String
    public let underlyingErrorDescription: String?

    public var description: String {
        if let underlying = underlyingErrorDescription {
            return "PayKitError(\(code.rawValue): \(message), underlying: \(underlying))"
        }
        return "PayKitError(\(code.rawValue): \(message))"
    }

    public init(
        code: PayKitErrorCode,
        message: String,
        underlyingError: Error? = nil
    ) {
        self.code = code
        self.message = message
        self.underlyingErrorDescription = underlyingError?.localizedDescription
    }
}
