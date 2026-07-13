import Foundation

enum M720Profile {
    static let vendorID = 0x046D
    static let bluetoothLEProductID = 0xB015
    static let bluetoothLETransport = "Bluetooth Low Energy"
    static let featureID: UInt16 = 0x1B04
    static let maximumControlCount = 32

    static let cidToButton: [UInt16: Int] = [
        0x005B: 6,
        0x005D: 7,
        0x00D0: 8,
    ]

    static let nativeCIDs: Set<UInt16> = [0x0052, 0x0053, 0x0056]

    static func isEligible(vendorID: Int, productID: Int, transport: String) -> Bool {
        vendorID == self.vendorID &&
        productID == bluetoothLEProductID &&
        transport == bluetoothLETransport
    }
}
