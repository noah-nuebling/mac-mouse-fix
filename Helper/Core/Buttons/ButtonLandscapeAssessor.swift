//
// --------------------------------------------------------------------------
// ButtonLandscapeAssessor.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Foundation

extension ButtonLandscapeAssessor {
    
    ///
    /// Turn off swift autobridging
    ///
    
    static func maxLevel(forButton button: NSNumber, remaps: NSDictionary, modificationsActingOnThisButton: NSDictionary) -> NSInteger {
        
        return self.__SWIFT_UNBRIDGED_maxLevel(forButton: button, remaps: remaps, modificationsActingOnThisButton: modificationsActingOnThisButton)
    }
    
    static func effectExists(forButton button: NSNumber, remaps: NSDictionary, modificationsActingOnButton: NSDictionary) -> Bool {
        
        return __SWIFT_UNBRIDGED_effectExists(forButton: button, remaps: remaps, modificationsActingOnButton: modificationsActingOnButton)
    }
    
    static func assessMappingLandscape(withButton button: NSNumber, level: NSNumber, modificationsActingOnThisButton: NSDictionary, remaps: NSDictionary, thisClickDoBe: UnsafeMutablePointer<ObjCBool>, thisDownDoBe: UnsafeMutablePointer<ObjCBool>, greaterDoBe: UnsafeMutablePointer<ObjCBool>) {
        
        __SWIFT_UNBRIDGED_assessMappingLandscape(withButton: button, level: level, modificationsActingOnThisButton: modificationsActingOnThisButton, remaps: remaps, thisClickDoBe: thisClickDoBe, thisDownDoBe: thisDownDoBe, greaterDoBe: greaterDoBe)
    }
    
    
    
}
