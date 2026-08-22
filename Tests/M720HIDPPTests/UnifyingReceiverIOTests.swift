import XCTest
@testable import Mac_Mouse_Fix_Helper

final class UnifyingReceiverIOTests: XCTestCase {
    func testSelectsOnlyVendorInterfaceAtCandidateReceiverLocation() {
        let candidate = descriptor(
            registryEntryID: 10,
            usagePage: 0x01,
            usage: 0x02
        )
        let exact = descriptor(
            registryEntryID: 14,
            usagePage: 0xFF00,
            usage: 0x01
        )
        let devices = [
            candidate,
            descriptor(registryEntryID: 11, usagePage: 0x01, usage: 0x06),
            descriptor(registryEntryID: 12, usagePage: 0xFF00, usage: 0x02),
            descriptor(
                registryEntryID: 13,
                locationID: 0x9990000,
                usagePage: 0xFF00,
                usage: 0x01
            ),
            exact,
        ]

        XCTAssertEqual(
            UnifyingReceiverInterfaceMatcher.selectVendorInterface(
                for: candidate,
                from: devices
            ),
            exact
        )
    }

    func testRejectsNonReceiverCandidateAndMissingLocation() {
        let vendorInterface = descriptor(
            registryEntryID: 14,
            usagePage: 0xFF00,
            usage: 0x01
        )
        let bluetoothCandidate = descriptor(
            registryEntryID: 10,
            transport: "Bluetooth Low Energy",
            usagePage: 0x01,
            usage: 0x02
        )
        let missingLocation = descriptor(
            registryEntryID: 10,
            locationID: nil,
            usagePage: 0x01,
            usage: 0x02
        )

        XCTAssertNil(UnifyingReceiverInterfaceMatcher.selectVendorInterface(
            for: bluetoothCandidate,
            from: [vendorInterface]
        ))
        XCTAssertNil(UnifyingReceiverInterfaceMatcher.selectVendorInterface(
            for: missingLocation,
            from: [vendorInterface]
        ))
    }

    func testRejectsAmbiguousVendorInterfaces() {
        let candidate = descriptor(
            registryEntryID: 10,
            usagePage: 0x01,
            usage: 0x02
        )
        let first = descriptor(
            registryEntryID: 14,
            usagePage: 0xFF00,
            usage: 0x01
        )
        let second = descriptor(
            registryEntryID: 15,
            usagePage: 0xFF00,
            usage: 0x01
        )

        XCTAssertNil(UnifyingReceiverInterfaceMatcher.selectVendorInterface(
            for: candidate,
            from: [first, second]
        ))
    }

    private func descriptor(
        registryEntryID: UInt64,
        vendorID: Int = 0x046D,
        productID: Int = 0xC52B,
        transport: String = "USB",
        locationID: UInt32? = 0x2140000,
        usagePage: Int,
        usage: Int
    ) -> UnifyingReceiverInterfaceDescriptor {
        UnifyingReceiverInterfaceDescriptor(
            registryEntryID: registryEntryID,
            vendorID: vendorID,
            productID: productID,
            transport: transport,
            locationID: locationID,
            usagePage: usagePage,
            usage: usage
        )
    }
}
