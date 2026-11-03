import XCTest
@testable import PayKit

final class DeviceCacheTests: XCTestCase {
    var cache: DeviceCache!
    let suiteName = "DeviceCacheTestsSuite"

    override func setUp() {
        super.setUp()
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        cache = DeviceCache(userDefaults: userDefaults)
    }

    func testCacheAndRetrieve() {
        XCTAssertNil(cache.getCustomerInfo())

        let info = CustomerInfo(
            activeSubscriptions: ["subs_pro"],
            nonConsumablePurchases: ["lifetime"],
            allPurchaseRecords: [],
            unfulfilledConsumables: []
        )

        cache.cacheCustomerInfo(info)

        let loaded = cache.getCustomerInfo()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.activeSubscriptions, ["subs_pro"])
        XCTAssertEqual(loaded?.nonConsumablePurchases, ["lifetime"])

        cache.clear()
        XCTAssertNil(cache.getCustomerInfo())
    }
}
