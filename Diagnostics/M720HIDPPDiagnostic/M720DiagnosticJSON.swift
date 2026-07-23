import Foundation

enum M720DiagnosticJSON {
    static func encode(_ object: Any) throws -> Data {
        var data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys]
        )
        data.append(0x0A)
        return data
    }
}
