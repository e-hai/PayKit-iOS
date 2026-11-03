import XCTest
@testable import PayKit

final class PayKitConfigurationTests: XCTestCase {
    func testValidateSuccess() {
        let config = PayKitConfiguration(
            subsProductIds: ["sub_1"],
            consumableProductIds: ["coin_1"],
            nonConsumableProductIds: ["pass_1"]
        )
        let result = config.validate()
        guard case .success = result else {
            XCTFail("Should succeed")
            return
        }
    }

    func testValidateDuplicateOverlap() {
        let config = PayKitConfiguration(
            subsProductIds: ["duplicate_id"],
            consumableProductIds: ["duplicate_id"],
            nonConsumableProductIds: []
        )
        let result = config.validate()
        guard case .failure(let error) = result else {
            XCTFail("Should fail validation on overlap")
            return
        }
        XCTAssertTrue(error.message.contains("Configuration error"))
    }
}
