import Foundation

/// CustomerInfo 本地缓存（快照持久化，冷启动秒开）
public final class DeviceCache: @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let cacheKey: String
    private let lock = NSLock()

    public init(
        userDefaults: UserDefaults = .standard,
        cacheKey: String = "PayKit_DeviceCache"
    ) {
        self.userDefaults = userDefaults
        self.cacheKey = cacheKey
    }

    /// 获取缓存的 CustomerInfo 快照
    public func getCustomerInfo() -> CustomerInfo? {
        lock.lock()
        defer { lock.unlock() }

        guard let data = userDefaults.data(forKey: cacheKey) else {
            return nil
        }
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(CustomerInfo.self, from: data)
        } catch {
            LogUtil.e(LogUtil.tagGeneral, "DeviceCache decode failed", error: error)
            return nil
        }
    }

    /// 持久化缓存 CustomerInfo
    public func cacheCustomerInfo(_ customerInfo: CustomerInfo) {
        lock.lock()
        defer { lock.unlock() }

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(customerInfo)
            userDefaults.set(data, forKey: cacheKey)
            LogUtil.d(LogUtil.tagGeneral, "DeviceCache saved subs=\(customerInfo.activeSubscriptions.count) nonConsumable=\(customerInfo.nonConsumablePurchases.count)")
        } catch {
            LogUtil.e(LogUtil.tagGeneral, "DeviceCache encode failed", error: error)
        }
    }

    /// 清空缓存
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        userDefaults.removeObject(forKey: cacheKey)
        LogUtil.d(LogUtil.tagGeneral, "DeviceCache cleared")
    }
}
