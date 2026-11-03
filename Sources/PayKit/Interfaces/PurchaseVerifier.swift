import Foundation

/// 订单验签协议（支持服务端扩展）
public protocol PurchaseVerifier: Sendable {
    /// 校验交易凭据
    /// - Parameter transaction: 当前交易对象
    /// - Returns: 校验成功返回 .success(())，校验失败返回对应 PayKitError
    func verify(transaction: StoreTransaction) async -> Result<Void, PayKitError>
}

/// 默认本地验签器（无后端）：信赖 Apple StoreKit 2 的 JWS 原生验证结果
public final class LocalPurchaseVerifier: PurchaseVerifier, @unchecked Sendable {
    public static let shared = LocalPurchaseVerifier()

    public init() {}

    public func verify(transaction: StoreTransaction) async -> Result<Void, PayKitError> {
        // 本地模式：StoreKit 2 内部已解析并校验 JWS 密码学签名
        return .success(())
    }
}
