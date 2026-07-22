import Foundation

enum DeviceDisplayOrder {
    static func moving(_ order: [String], sourceID: String, targetID: String) -> [String] {
        guard sourceID != targetID,
              let sourceIndex = order.firstIndex(of: sourceID),
              let targetIndex = order.firstIndex(of: targetID)
        else { return order }

        var result = order
        result.remove(at: sourceIndex)
        guard let adjustedTargetIndex = result.firstIndex(of: targetID) else { return order }
        let insertionIndex = sourceIndex < targetIndex ? adjustedTargetIndex + 1 : adjustedTargetIndex
        result.insert(sourceID, at: insertionIndex)
        return result
    }

    static func sorted(_ devices: [InputDeviceDescriptor], using order: [String]) -> [InputDeviceDescriptor] {
        let rank = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })
        return devices.sorted { lhs, rhs in
            let lhsRank = rank[lhs.id] ?? Int.max
            let rhsRank = rank[rhs.id] ?? Int.max
            if lhsRank != rhsRank { return lhsRank < rhsRank }
            if lhs.connected != rhs.connected { return lhs.connected && !rhs.connected }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}
