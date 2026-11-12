import Foundation
import OSLog

/// 统一日志工具（保持与 Android PayKit 一致的格式与标签）
public enum LogUtil {
    /// 全局日志开关
    public static var enabled: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _enabled
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _enabled = newValue
        }
    }

    /// 标签常量
    public static let tagGeneral = "PayKit"
    public static let tagBilling = "PayKit-Billing"
    public static let tagSample = "PayKit-Sample"

    private static let lock = NSLock()
    private static var _enabled: Bool = true
    private static var _customLogger: PayKitLogger?

    private static let logger = Logger(subsystem: "com.kit.pay", category: "PayKit")

    /// 注册或清除外部日志拦截器（接管模式）
    public static func setLogger(_ customLogger: PayKitLogger?) {
        lock.lock()
        defer { lock.unlock() }
        _customLogger = customLogger
    }

    public static func d(_ tag: String = tagGeneral, _ message: String) {
        dispatch(level: .debug, tag: tag, message: message, error: nil) {
            print("[\(tag)] \(message)")
        }
    }

    public static func i(_ tag: String = tagGeneral, _ message: String) {
        dispatch(level: .info, tag: tag, message: message, error: nil) {
            print("[\(tag)] \(message)")
        }
    }

    public static func w(_ tag: String = tagGeneral, _ message: String) {
        dispatch(level: .warn, tag: tag, message: message, error: nil) {
            print("[\(tag)] WARN: \(message)")
        }
    }

    public static func e(_ tag: String = tagGeneral, _ message: String, error: Error? = nil) {
        dispatch(level: .error, tag: tag, message: message, error: error) {
            if let err = error {
                print("[\(tag)] ERROR: \(message), error=\(err)")
            } else {
                print("[\(tag)] ERROR: \(message)")
            }
        }
    }

    private static func dispatch(
        level: PayKitLogLevel,
        tag: String,
        message: String,
        error: Error?,
        fallback: () -> Void
    ) {
        let (isEnabled, custom): (Bool, PayKitLogger?) = {
            lock.lock()
            defer { lock.unlock() }
            return (_enabled, _customLogger)
        }()
        guard isEnabled else { return }
        if let custom = custom {
            custom.log(level: level, tag: tag, message: message, error: error)
        } else {
            fallback()
        }
    }
}
