//
// --------------------------------------------------------------------------
// Remap.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Foundation

extension Remap {
    
    static var remaps: NSDictionary {
        return __SWIFT_UNBRIDGED_remaps() as! NSDictionary
    }
    static func modifications(withModifiers modifiers: NSDictionary) -> NSDictionary? {
        return __SWIFT_UNBRIDGED_modifications(withModifiers: modifiers) as! NSDictionary?
    }
    static func concludeAddMode(withPayload payload: NSDictionary) {
        __SWIFT_UNBRIDGED_concludeAddMode(withPayload: payload)
    }
}
