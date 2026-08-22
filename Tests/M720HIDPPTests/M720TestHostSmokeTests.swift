import XCTest
@testable import Mac_Mouse_Fix_Helper

final class M720TestHostSmokeTests: XCTestCase {
    func testBundleLoadsTheRealHelperModuleWithoutProductionStartup() {
        XCTAssertEqual(ProcessInfo.processInfo.environment["MMF_M720_UNIT_TESTING"], "1")
        XCTAssertNotNil(Buttons.self)
        XCTAssertTrue(Bundle.main.bundleURL.lastPathComponent == "Mac Mouse Fix Helper.app")
    }
}
