//
// --------------------------------------------------------------------------
// RemapsAnalyzer.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Foundation

extension RemapsAnalyzer {
    
    ///
    /// Turn off swift autobridging
    ///
    
    static func modificationsModifyButtons(_ modifications: NSDictionary, maxButton: Int32) -> Bool {
        return __SWIFT_UNBRIDGED_modificationsModifyButtons(modifications, maxButton: maxButton)
    }
    
    static func modificationsModifyScroll(_ modifications: NSDictionary) -> Bool {
        return __SWIFT_UNBRIDGED_modificationsModifyScroll(modifications)
    }
    static func modificationsModifyPointing(_ modifications: NSDictionary) -> Bool {
        return __SWIFT_UNBRIDGED_modificationsModifyPointing(modifications)
    }
    
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
