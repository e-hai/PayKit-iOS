import Foundation

/// PayKit 内部日志级别
public enum PayKitLogLevel: String, Sendable {
    case debug
    case info
    case warn
    case error
}

/// 外部日志拦截器（接管模式）。
/// 通过 `PayKit.setLogger(...)` 注册后，SDK 内部日志将全部转发给该拦截器，
/// 不再重复执行默认 `print(...)` 输出。
public protocol PayKitLogger: Sendable {
    func log(level: PayKitLogLevel, tag: String, message: String, error: Error?)
}

/// 闭包形式的外部日志拦截器包装
public final class ClosurePayKitLogger: PayKitLogger, @unchecked Sendable {
    private let handler: @Sendable (PayKitLogLevel, String, String, Error?) -> Void

    public init(_ handler: @escaping @Sendable (PayKitLogLevel, String, String, Error?) -> Void) {
        self.handler = handler
    }

    public func log(level: PayKitLogLevel, tag: String, message: String, error: Error?) {
        handler(level, tag, message, error)
    }
}
