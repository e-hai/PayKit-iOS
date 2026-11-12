import XCTest
@testable import PayKit

final class LogUtilTests: XCTestCase {

    override func tearDown() {
        super.tearDown()
        PayKit.setLogger(nil)
        LogUtil.enabled = true
    }

    func testCustomLoggerInterceptsAllLevels() {
        final class Collector: @unchecked Sendable {
            private let lock = NSLock()
            var items: [(PayKitLogLevel, String, String, Bool)] = []
            func append(_ level: PayKitLogLevel, _ tag: String, _ msg: String, _ hasError: Bool) {
                lock.lock()
                defer { lock.unlock() }
                items.append((level, tag, msg, hasError))
            }
        }

        let collector = Collector()
        PayKit.setLogger(ClosurePayKitLogger { level, tag, message, error in
            collector.append(level, tag, message, error != nil)
        })

        LogUtil.d(LogUtil.tagGeneral, "debug msg")
        LogUtil.i(LogUtil.tagBilling, "info msg")
        LogUtil.w(LogUtil.tagGeneral, "warn msg")
        LogUtil.e(LogUtil.tagGeneral, "error msg", error: NSError(domain: "test", code: 1))

        XCTAssertEqual(collector.items.count, 4)
        XCTAssertEqual(collector.items[0].0, .debug)
        XCTAssertEqual(collector.items[0].1, LogUtil.tagGeneral)
        XCTAssertEqual(collector.items[0].2, "debug msg")
        XCTAssertEqual(collector.items[1].0, .info)
        XCTAssertEqual(collector.items[1].1, LogUtil.tagBilling)
        XCTAssertEqual(collector.items[2].0, .warn)
        XCTAssertEqual(collector.items[3].0, .error)
        XCTAssertTrue(collector.items[3].3)
    }

    func testDisabledLogUtilSuppressesCustomLogger() {
        final class Counter: @unchecked Sendable {
            private let lock = NSLock()
            var count = 0
            func inc() {
                lock.lock()
                defer { lock.unlock() }
                count += 1
            }
        }
        let counter = Counter()
        PayKit.setLogger(ClosurePayKitLogger { _, _, _, _ in
            counter.inc()
        })
        LogUtil.enabled = false

        LogUtil.d(LogUtil.tagGeneral, "ignored")
        LogUtil.e(LogUtil.tagGeneral, "ignored error")

        XCTAssertEqual(counter.count, 0)
    }
}
