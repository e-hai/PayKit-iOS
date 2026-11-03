import Foundation

/// 权益计算辅助器（纯本地逻辑）
public enum CustomerInfoHelper {
    /// 计算最新的 CustomerInfo 权益快照
    /// - Parameters:
    ///   - configuration: 当前生效的配置
    ///   - subsTransactions: 订阅类交易列表
    ///   - inappTransactions: 内购类交易列表
    ///   - consumableLedger: 消耗品履约账本
    /// - Returns: 计算后的 CustomerInfo
    public static func computeCustomerInfo(
        configuration: PayKitConfiguration,
        subsTransactions: [StoreTransaction],
        inappTransactions: [StoreTransaction],
        consumableLedger: ConsumableLedger
    ) -> CustomerInfo {
        let now = Date()

        // 1. 活跃订阅：属于配置的 subsProductIds，且状态为 purchased，未被撤销，且未过期
        var activeSubs = Set<String>()
        for txn in subsTransactions where txn.purchaseState == .purchased {
            if let revocation = txn.revocationDate, revocation <= now {
                continue
            }
            if let expiration = txn.expirationDate, expiration <= now {
                continue
            }
            for pid in txn.productIds {
                if configuration.subsProductIds.contains(pid) {
                    activeSubs.insert(pid)
                }
            }
        }

        // 2. 非消耗品：属于配置的 nonConsumableProductIds，状态为 purchased，未被撤销
        var nonConsumables = Set<String>()
        for txn in inappTransactions where txn.purchaseState == .purchased {
            if let revocation = txn.revocationDate, revocation <= now {
                continue
            }
            for pid in txn.productIds {
                if configuration.nonConsumableProductIds.contains(pid) {
                    nonConsumables.insert(pid)
                }
            }
        }

        // 3. 待履约的消耗品：属于 consumableProductIds，且记录在 ledger 中或尚未 finish
        let ledgerTokens = Set(consumableLedger.allEntries().map { $0.purchaseToken })
        var unfulfilledConsumables: [StoreTransaction] = []
        for txn in inappTransactions where txn.purchaseState == .purchased {
            let isConsumable = txn.productIds.contains { configuration.consumableProductIds.contains($0) }
            if isConsumable && ledgerTokens.contains(txn.purchaseToken) {
                unfulfilledConsumables.append(txn)
            }
        }

        // 合并所有交易作为当前快照
        let allRecords = subsTransactions + inappTransactions

        return CustomerInfo(
            activeSubscriptions: activeSubs,
            nonConsumablePurchases: nonConsumables,
            allPurchaseRecords: allRecords,
            unfulfilledConsumables: unfulfilledConsumables
        )
    }
}
