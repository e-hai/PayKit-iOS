import XCTest
@testable import PayKit

final class ConsumableLedgerTests: XCTestCase {
    var ledger: ConsumableLedger!
    let suiteName = "ConsumableLedgerTestsSuite"

    override func setUp() {
        super.setUp()
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        ledger = ConsumableLedger(userDefaults: userDefaults)
    }

    func testRecordAndRemove() {
        XCTAssertTrue(ledger.allEntries().isEmpty)

        ledger.recordPendingFulfill(purchaseToken: "token_123", productId: "coin_pack")
        XCTAssertEqual(ledger.allEntries().count, 1)
        XCTAssertTrue(ledger.contains(purchaseToken: "token_123"))

        // 重复记录应去重
        ledger.recordPendingFulfill(purchaseToken: "token_123", productId: "coin_pack")
        XCTAssertEqual(ledger.allEntries().count, 1)

        ledger.remove(purchaseToken: "token_123")
        XCTAssertFalse(ledger.contains(purchaseToken: "token_123"))
        XCTAssertTrue(ledger.allEntries().isEmpty)
    }
}
