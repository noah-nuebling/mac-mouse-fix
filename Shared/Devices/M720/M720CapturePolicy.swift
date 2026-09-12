import Foundation

enum M720CapturePolicy {
    static func requiredCIDs(
        remaps: NSDictionary,
        addMode: Bool,
        buttonsEnabled: Bool
    ) -> Set<UInt16> {
        guard buttonsEnabled else { return [] }
        if addMode { return Set(M720Profile.cidToButton.keys) }

        var configuredButtons = Set<Int>()
        for case let precondition as NSDictionary in remaps.allKeys {
            let modifiers = precondition.object(forKey: kMFModificationPreconditionKeyButtons) as? [NSDictionary] ?? []
            for modifier in modifiers {
                if let number = modifier.object(forKey: kMFButtonModificationPreconditionKeyButtonNumber) as? NSNumber {
                    configuredButtons.insert(number.intValue)
                }
            }
        }
        for case let modification as NSDictionary in remaps.allValues {
            for button in M720Profile.cidToButton.values
            where modification.object(forKey: NSNumber(value: button)) != nil {
                configuredButtons.insert(button)
            }
        }

        return Set(M720Profile.cidToButton.compactMap { entry in
            configuredButtons.contains(entry.value) ? entry.key : nil
        })
    }
}
