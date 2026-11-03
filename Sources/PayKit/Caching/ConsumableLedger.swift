import Foundation

/// 消耗品履约账本（持久化记录已发货但尚未 finish/consume 的消耗品）
public final class ConsumableLedger: @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let storageKey: String
    private let lock = NSLock()

    public init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = "PayKit_ConsumableLedger"
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
    }

    /// 记录待完成/待消单消耗品
    public func recordPendingFulfill(purchaseToken: String, productId: String) {
        lock.lock()
        defer { lock.unlock() }

        var entries = loadEntriesInternal()
        // 去重
        entries.removeAll { $0.purchaseToken == purchaseToken }
        let newEntry = ConsumableLedgerEntry(purchaseToken: purchaseToken, productId: productId)
        entries.append(newEntry)
        saveEntriesInternal(entries)
        LogUtil.d(LogUtil.tagGeneral, "ConsumableLedger record token=\(purchaseToken) product=\(productId)")
    }

    /// 标记已完成/已消单，从账本移除
    public func remove(purchaseToken: String) {
        lock.lock()
        defer { lock.unlock() }

        var entries = loadEntriesInternal()
        let countBefore = entries.count
        entries.removeAll { $0.purchaseToken == purchaseToken }
        if entries.count != countBefore {
            saveEntriesInternal(entries)
            LogUtil.d(LogUtil.tagGeneral, "ConsumableLedger remove token=\(purchaseToken)")
        }
    }

    /// 检查指定 token 是否在待完成账本中
    public func contains(purchaseToken: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let entries = loadEntriesInternal()
        return entries.contains { $0.purchaseToken == purchaseToken }
    }

    /// 获取所有待完成账本条目
    public func allEntries() -> [ConsumableLedgerEntry] {
        lock.lock()
        defer { lock.unlock() }
        return loadEntriesInternal()
    }

    /// 清空账本
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        userDefaults.removeObject(forKey: storageKey)
    }

    private func loadEntriesInternal() -> [ConsumableLedgerEntry] {
        guard let data = userDefaults.data(forKey: storageKey) else {
            return []
        }
        do {
            let decoder = JSONDecoder()
            return try decoder.decode([ConsumableLedgerEntry].self, from: data)
        } catch {
            LogUtil.e(LogUtil.tagGeneral, "ConsumableLedger decode failed", error: error)
            return []
        }
    }

    private func saveEntriesInternal(_ entries: [ConsumableLedgerEntry]) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(entries)
            userDefaults.set(data, forKey: storageKey)
        } catch {
            LogUtil.e(LogUtil.tagGeneral, "ConsumableLedger encode failed", error: error)
        }
    }
}
