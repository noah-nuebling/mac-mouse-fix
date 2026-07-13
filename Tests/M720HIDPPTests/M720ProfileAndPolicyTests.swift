import XCTest
@testable import Mac_Mouse_Fix_Helper

final class M720ProfileAndPolicyTests: XCTestCase {
    func testEligibilityRequiresExactBLEIdentity() {
        XCTAssertTrue(M720Profile.isEligible(vendorID: 0x046D, productID: 0xB015, transport: "Bluetooth Low Energy"))
        XCTAssertFalse(M720Profile.isEligible(vendorID: 0x046D, productID: 0xB015, transport: "USB"))
        XCTAssertFalse(M720Profile.isEligible(vendorID: 0x046D, productID: 0x405E, transport: "Bluetooth Low Energy"))
    }

    func testEffectiveButtonCountOverridesOnlyExactBLEModel() {
        XCTAssertEqual(Device.effectiveButtonCount(16, vendorID: 0x046D, productID: 0xB015, transport: "Bluetooth Low Energy"), 8)
        XCTAssertEqual(Device.effectiveButtonCount(16, vendorID: 0x046D, productID: 0xB015, transport: "USB"), 16)
        XCTAssertEqual(Device.effectiveButtonCount(12, vendorID: 0x1234, productID: 0x5678, transport: "Bluetooth Low Energy"), 12)
    }
}
