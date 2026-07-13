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

    func testDirectTriggerRequiresCorrespondingCID() {
        let required = M720CapturePolicy.requiredCIDs(
            remaps: makeRemaps(triggerButtons: [7]),
            addMode: false,
            buttonsEnabled: true
        )

        XCTAssertEqual(required, [0x005D])
    }

    func testButtonModifierRequiresCorrespondingCID() {
        let required = M720CapturePolicy.requiredCIDs(
            remaps: makeRemaps(buttonModifiers: [6]),
            addMode: false,
            buttonsEnabled: true
        )

        XCTAssertEqual(required, [0x005B])
    }

    func testAddModeRequiresOnlyTheThreeTargets() {
        let required = M720CapturePolicy.requiredCIDs(
            remaps: [:],
            addMode: true,
            buttonsEnabled: true
        )

        XCTAssertEqual(required, Set([0x005B, 0x005D, 0x00D0]))
        XCTAssertTrue(required.isDisjoint(with: M720Profile.nativeCIDs))
    }

    func testDisabledButtonsRequireNoCIDs() {
        let required = M720CapturePolicy.requiredCIDs(
            remaps: makeRemaps(buttonModifiers: [6], triggerButtons: [7, 8]),
            addMode: true,
            buttonsEnabled: false
        )

        XCTAssertEqual(required, [])
    }

    func testRemovingBindingsRemovesCaptureRequirement() {
        let configured = M720CapturePolicy.requiredCIDs(
            remaps: makeRemaps(buttonModifiers: [6], triggerButtons: [8]),
            addMode: false,
            buttonsEnabled: true
        )
        let removed = M720CapturePolicy.requiredCIDs(
            remaps: [:],
            addMode: false,
            buttonsEnabled: true
        )

        XCTAssertEqual(configured, Set([0x005B, 0x00D0]))
        XCTAssertEqual(removed, [])
    }

    func testNativeButtonTriggersAreExcludedFromCapture() {
        let required = M720CapturePolicy.requiredCIDs(
            remaps: makeRemaps(triggerButtons: [1, 2, 3, 6]),
            addMode: false,
            buttonsEnabled: true
        )

        XCTAssertEqual(required, [0x005B])
        XCTAssertTrue(required.isDisjoint(with: M720Profile.nativeCIDs))
    }

    func testStableErrorCodesExposeExactWireVocabulary() throws {
        let codes: [M720StableErrorCode] = [
            .unsupported,
            .protocol,
            .timeout,
            .conflict,
            .disconnected,
            .cancelled,
            .deviceSetChanged,
            .appUnavailable,
        ]

        XCTAssertEqual(codes.map(\.rawValue), [
            "unsupported",
            "protocol",
            "timeout",
            "conflict",
            "disconnected",
            "cancelled",
            "deviceSetChanged",
            "appUnavailable",
        ])
        XCTAssertEqual(
            try JSONDecoder().decode([M720StableErrorCode].self, from: JSONEncoder().encode(codes)),
            codes
        )
    }

    private func makeRemaps(
        buttonModifiers: [Int] = [],
        triggerButtons: [Int] = []
    ) -> NSDictionary {
        let precondition = NSMutableDictionary()
        if !buttonModifiers.isEmpty {
            let modifiers = buttonModifiers.map { button in
                [kMFButtonModificationPreconditionKeyButtonNumber: NSNumber(value: button)] as NSDictionary
            }
            precondition.setObject(modifiers, forKey: kMFModificationPreconditionKeyButtons as NSCopying)
        }

        let modification = NSMutableDictionary()
        for button in triggerButtons {
            modification.setObject(NSDictionary(), forKey: NSNumber(value: button))
        }

        let remaps = NSMutableDictionary()
        remaps.setObject(modification, forKey: precondition)
        return remaps
    }
}
