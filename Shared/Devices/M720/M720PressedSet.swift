import Foundation

enum M720ButtonEdge: Equatable {
    case down(cid: UInt16, button: Int)
    case up(cid: UInt16, button: Int)
}

struct M720PressedSet {
    private enum ParseError: Error {
        case invalidLength(Int)
        case duplicateCID(UInt16)
    }

    private(set) var orderedCIDs: [UInt16] = []

    mutating func consume(parameters: Data) throws -> [M720ButtonEdge] {
        guard parameters.count >= 8 else {
            throw ParseError.invalidLength(parameters.count)
        }

        var parsedCIDs: [UInt16] = []
        var seenCIDs = Set<UInt16>()
        for slot in 0..<4 {
            let highIndex = parameters.index(parameters.startIndex, offsetBy: slot * 2)
            let lowIndex = parameters.index(after: highIndex)
            let cid = UInt16(parameters[highIndex]) << 8 | UInt16(parameters[lowIndex])
            guard cid != 0 else { continue }
            guard seenCIDs.insert(cid).inserted else {
                throw ParseError.duplicateCID(cid)
            }
            parsedCIDs.append(cid)
        }

        let oldCIDs = Set(orderedCIDs)
        let newCIDs = Set(parsedCIDs)
        var edges = orderedCIDs.compactMap { cid -> M720ButtonEdge? in
            guard !newCIDs.contains(cid), let button = M720Profile.cidToButton[cid] else {
                return nil
            }
            return .up(cid: cid, button: button)
        }
        edges.append(contentsOf: parsedCIDs.compactMap { cid -> M720ButtonEdge? in
            guard !oldCIDs.contains(cid), let button = M720Profile.cidToButton[cid] else {
                return nil
            }
            return .down(cid: cid, button: button)
        })

        orderedCIDs = parsedCIDs
        return edges
    }

    mutating func releaseAll() -> [M720ButtonEdge] {
        let edges = orderedCIDs.compactMap { cid -> M720ButtonEdge? in
            guard let button = M720Profile.cidToButton[cid] else { return nil }
            return .up(cid: cid, button: button)
        }
        orderedCIDs = []
        return edges
    }
}
