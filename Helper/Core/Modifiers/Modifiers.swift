//
// --------------------------------------------------------------------------
// Modifiers.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Foundation

extension Modifiers {
    
    static func modifiers(with event: CGEvent?) -> NSMutableDictionary {
        return __SWIFT_UNBRIDGED_modifiers(with: event) as! NSMutableDictionary
    }
    
    static func buttonModsChanged(to newMods: NSMutableArray) {
        __SWIFT_UNBRIDGED_buttonModsChanged(to: newMods)
    }
}
