import Foundation
import OSLog

/// 统一日志工具（保持与 Android PayKit 一致的格式与标签）
public enum LogUtil {
    /// 全局日志开关
    public static var enabled: Bool = true

    /// 标签常量
    public static let tagGeneral = "PayKit"
    public static let tagBilling = "PayKit-Billing"
    public static let tagSample = "PayKit-Sample"

    private static let logger = Logger(subsystem: "com.kit.pay", category: "PayKit")

    public static func d(_ tag: String = tagGeneral, _ message: String) {
        guard enabled else { return }
        print("[\(tag)] \(message)")
    }

    public static func i(_ tag: String = tagGeneral, _ message: String) {
        guard enabled else { return }
        print("[\(tag)] \(message)")
    }

    public static func w(_ tag: String = tagGeneral, _ message: String) {
        guard enabled else { return }
        print("[\(tag)] WARN: \(message)")
    }

    public static func e(_ tag: String = tagGeneral, _ message: String, error: Error? = nil) {
        guard enabled else { return }
        if let err = error {
            print("[\(tag)] ERROR: \(message), error=\(err)")
        } else {
            print("[\(tag)] ERROR: \(message)")
        }
    }
}
