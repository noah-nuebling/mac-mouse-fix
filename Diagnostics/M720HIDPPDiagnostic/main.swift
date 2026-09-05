import Darwin
import Foundation

private func writeStandardError(_ text: String) {
    FileHandle.standardError.write(Data(text.utf8))
}

do {
    let command = try M720DiagnosticCommand.parse(Array(CommandLine.arguments.dropFirst()))
    let snapshot: NSDictionary
    switch command {
    case .helperSnapshot:
        snapshot = try M720DiagnosticMessagePortClient().snapshot()
    case let .deviceSnapshot(vendorID, productID):
        snapshot = try M720DiagnosticIOHIDClient.production.snapshot(
            vendorID: vendorID,
            productID: productID
        )
    }
    FileHandle.standardOutput.write(try M720DiagnosticJSON.encode(snapshot))
} catch M720DiagnosticError.usage {
    writeStandardError(M720DiagnosticError.usageText + "\n")
    exit(2)
} catch {
    writeStandardError("M720 HIDPP Diagnostic: \(error)\n")
    exit(1)
}
