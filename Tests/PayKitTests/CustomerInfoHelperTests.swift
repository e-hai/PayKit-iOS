import XCTest
@testable import PayKit

final class CustomerInfoHelperTests: XCTestCase {
    func testComputeCustomerInfo_activeSubscription() {
        let config = PayKitConfiguration(
            subsProductIds: ["subs_pro", "subs_plus"],
            consumableProductIds: ["coins_100"],
            nonConsumableProductIds: ["lifetime_pass"]
        )
        let ledger = ConsumableLedger(userDefaults: UserDefaults(suiteName: "TestCustomerInfoHelper")!)
        ledger.clear()

        let now = Date()
        let future = now.addingTimeInterval(3600 * 24 * 30) // 30 days later

        let subTxn = StoreTransaction(
            orderId: "1001",
            originalTransactionId: "1001",
            productIds: ["subs_pro"],
            purchaseTime: Int64(now.timeIntervalSince1970 * 1000),
            purchaseToken: "token_sub_1",
            purchaseState: .purchased,
            expirationDate: future
        )

        let customerInfo = CustomerInfoHelper.computeCustomerInfo(
            configuration: config,
            subsTransactions: [subTxn],
            inappTransactions: [],
            consumableLedger: ledger
        )

        XCTAssertTrue(customerInfo.activeSubscriptions.contains("subs_pro"))
        XCTAssertEqual(customerInfo.activeSubscriptions.count, 1)
        XCTAssertEqual(customerInfo.purchasedRecords.count, 1)
    }

    func testComputeCustomerInfo_expiredSubscription() {
        let config = PayKitConfiguration(
            subsProductIds: ["subs_pro"],
            consumableProductIds: [],
            nonConsumableProductIds: []
        )
        let ledger = ConsumableLedger(userDefaults: UserDefaults(suiteName: "TestCustomerInfoHelperExpired")!)
        ledger.clear()

        let past = Date().addingTimeInterval(-3600) // 1 hour ago

        let subTxn = StoreTransaction(
            orderId: "1002",
            productIds: ["subs_pro"],
            purchaseToken: "token_sub_expired",
            purchaseState: .purchased,
            expirationDate: past
        )

        let customerInfo = CustomerInfoHelper.computeCustomerInfo(
            configuration: config,
            subsTransactions: [subTxn],
            inappTransactions: [],
            consumableLedger: ledger
        )

        XCTAssertFalse(customerInfo.activeSubscriptions.contains("subs_pro"))
    }

    func testComputeCustomerInfo_unfulfilledConsumables() {
        let config = PayKitConfiguration(
            subsProductIds: [],
            consumableProductIds: ["coins_100"],
            nonConsumableProductIds: []
        )
        let suite = UserDefaults(suiteName: "TestCustomerInfoHelperConsumable")!
        let ledger = ConsumableLedger(userDefaults: suite)
        ledger.clear()

        ledger.recordPendingFulfill(purchaseToken: "token_coins_1", productId: "coins_100")

        let consumableTxn = StoreTransaction(
            orderId: "2001",
            productIds: ["coins_100"],
            purchaseToken: "token_coins_1",
            purchaseState: .purchased
        )

        let customerInfo = CustomerInfoHelper.computeCustomerInfo(
            configuration: config,
            subsTransactions: [],
            inappTransactions: [consumableTxn],
            consumableLedger: ledger
        )

        XCTAssertEqual(customerInfo.unfulfilledConsumables.count, 1)
        XCTAssertEqual(customerInfo.unfulfilledConsumables.first?.purchaseToken, "token_coins_1")

        // 履约移除后
        ledger.remove(purchaseToken: "token_coins_1")
        let updatedInfo = CustomerInfoHelper.computeCustomerInfo(
            configuration: config,
            subsTransactions: [],
            inappTransactions: [consumableTxn],
            consumableLedger: ledger
        )
        XCTAssertEqual(updatedInfo.unfulfilledConsumables.count, 0)
    }
}
