import Foundation
import XCTest
@testable import Mac_Mouse_Fix_Helper

final class M720PressedSetTests: XCTestCase {
    func testDiffsCompletePressedSnapshots() throws {
        var state = M720PressedSet()

        XCTAssertEqual(try state.consume(parameters: bytes(0x005B)), [.down(cid: 0x005B, button: 6)])
        XCTAssertEqual(try state.consume(parameters: bytes(0x005B, 0x005D)), [.down(cid: 0x005D, button: 7)])
        XCTAssertEqual(try state.consume(parameters: bytes(0x005D)), [.up(cid: 0x005B, button: 6)])
        XCTAssertEqual(try state.consume(parameters: bytes()), [.up(cid: 0x005D, button: 7)])
        XCTAssertEqual(state.orderedCIDs, [])
    }

    func testSupportsTwoThreeAndFourSlotsInProtocolOrder() throws {
        var state = M720PressedSet()

        XCTAssertEqual(try state.consume(parameters: bytes(0x005B, 0x005D)), [
            .down(cid: 0x005B, button: 6),
            .down(cid: 0x005D, button: 7),
        ])
        XCTAssertEqual(state.orderedCIDs, [0x005B, 0x005D])

        XCTAssertEqual(try state.consume(parameters: bytes(0x005B, 0x005D, 0x00D0)), [
            .down(cid: 0x00D0, button: 8),
        ])
        XCTAssertEqual(state.orderedCIDs, [0x005B, 0x005D, 0x00D0])

        XCTAssertEqual(try state.consume(parameters: bytes(0x005B, 0x005D, 0x00D0, 0x1234)), [])
        XCTAssertEqual(state.orderedCIDs, [0x005B, 0x005D, 0x00D0, 0x1234])
    }

    func testArbitraryReleaseOrderFollowsOldProtocolOrder() throws {
        var state = M720PressedSet()
        _ = try state.consume(parameters: bytes(0x005B, 0x005D, 0x00D0))

        XCTAssertEqual(try state.consume(parameters: bytes(0x00D0, 0x005B)), [
            .up(cid: 0x005D, button: 7),
        ])
        XCTAssertEqual(try state.consume(parameters: bytes(0x005B)), [
            .up(cid: 0x00D0, button: 8),
        ])
        XCTAssertEqual(try state.consume(parameters: bytes()), [
            .up(cid: 0x005B, button: 6),
        ])
    }

    func testOrderOnlyChangeUpdatesProtocolOrderWithoutEdges() throws {
        var state = M720PressedSet()
        _ = try state.consume(parameters: bytes(0x005B, 0x005D, 0x00D0))

        XCTAssertEqual(try state.consume(parameters: bytes(0x00D0, 0x005B, 0x005D)), [])
        XCTAssertEqual(state.orderedCIDs, [0x00D0, 0x005B, 0x005D])
    }

    func testEmitsUpsBeforeDownsUsingEachSnapshotOrder() throws {
        var state = M720PressedSet()
        _ = try state.consume(parameters: bytes(0x00D0, 0x005B))

        XCTAssertEqual(try state.consume(parameters: bytes(0x005D)), [
            .up(cid: 0x00D0, button: 8),
            .up(cid: 0x005B, button: 6),
            .down(cid: 0x005D, button: 7),
        ])
    }

    func testDuplicateNonzeroCIDThrowsWithoutChangingOldSnapshot() throws {
        var state = M720PressedSet()
        _ = try state.consume(parameters: bytes(0x005B, 0x005D))

        XCTAssertThrowsError(try state.consume(parameters: bytes(0x00D0, 0x005B, 0x00D0)))
        XCTAssertEqual(state.orderedCIDs, [0x005B, 0x005D])
        XCTAssertEqual(try state.consume(parameters: bytes(0x005D)), [
            .up(cid: 0x005B, button: 6),
        ])
    }

    func testEveryShortPayloadThrowsWithoutChangingOldSnapshot() throws {
        var state = M720PressedSet()
        _ = try state.consume(parameters: bytes(0x00D0))

        for length in 0..<8 {
            XCTAssertThrowsError(try state.consume(parameters: Data(repeating: 0, count: length)))
            XCTAssertEqual(state.orderedCIDs, [0x00D0])
        }
    }

    func testZeroSlotsArePaddingRatherThanTerminators() throws {
        var state = M720PressedSet()

        XCTAssertEqual(try state.consume(parameters: bytes(0x005B, 0, 0x005D, 0)), [
            .down(cid: 0x005B, button: 6),
            .down(cid: 0x005D, button: 7),
        ])
        XCTAssertEqual(state.orderedCIDs, [0x005B, 0x005D])

        XCTAssertEqual(try state.consume(parameters: bytes(0, 0x005D, 0, 0)), [
            .up(cid: 0x005B, button: 6),
        ])
        XCTAssertEqual(state.orderedCIDs, [0x005D])
    }

    func testUnknownCIDsRemainOrderedWithoutProducingEdges() throws {
        var state = M720PressedSet()

        XCTAssertEqual(try state.consume(parameters: bytes(0xBEEF, 0x005B, 0x1234)), [
            .down(cid: 0x005B, button: 6),
        ])
        XCTAssertEqual(state.orderedCIDs, [0xBEEF, 0x005B, 0x1234])

        XCTAssertEqual(try state.consume(parameters: bytes(0x1234, 0xBEEF)), [
            .up(cid: 0x005B, button: 6),
        ])
        XCTAssertEqual(state.orderedCIDs, [0x1234, 0xBEEF])
    }

    func testReadsFourSlotsFromDataWithNonzeroStartIndex() throws {
        var framed = Data([0xFF])
        framed.append(bytes(0x005B, 0, 0x005D, 0))
        let parameters = framed.dropFirst()
        XCTAssertNotEqual(parameters.startIndex, 0)

        var state = M720PressedSet()
        XCTAssertEqual(try state.consume(parameters: parameters), [
            .down(cid: 0x005B, button: 6),
            .down(cid: 0x005D, button: 7),
        ])
        XCTAssertEqual(state.orderedCIDs, [0x005B, 0x005D])
    }

    func testIgnoresParameterBytesAfterFourSlots() throws {
        var parameters = bytes(0x005B)
        parameters.append(contentsOf: [0xAA, 0xBB])

        var state = M720PressedSet()
        XCTAssertEqual(try state.consume(parameters: parameters), [
            .down(cid: 0x005B, button: 6),
        ])
        XCTAssertEqual(state.orderedCIDs, [0x005B])
    }

    func testReleaseAllUsesOldOrderThenClearsIdempotently() throws {
        var state = M720PressedSet()
        _ = try state.consume(parameters: bytes(0x00D0, 0xBEEF, 0x005B, 0x005D))

        XCTAssertEqual(state.releaseAll(), [
            .up(cid: 0x00D0, button: 8),
            .up(cid: 0x005B, button: 6),
            .up(cid: 0x005D, button: 7),
        ])
        XCTAssertEqual(state.orderedCIDs, [])
        XCTAssertEqual(state.releaseAll(), [])
    }

    private func bytes(_ cids: UInt16...) -> Data {
        precondition(cids.count <= 4)
        var result = [UInt8](repeating: 0, count: 8)
        for (index, cid) in cids.enumerated() {
            result[index * 2] = UInt8(cid >> 8)
            result[index * 2 + 1] = UInt8(cid & 0xFF)
        }
        return Data(result)
    }
}
