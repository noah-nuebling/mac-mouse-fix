//
// --------------------------------------------------------------------------
// DisableSwiftBridging.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Foundation

/// On Swift Autobriding
/// Swift automatically bridges Foundation-type args (like NSDictionary) to native Swift types which is super slow. At least for Dictionaries. We've found a way to prevent this:
///
/// 1. In your objc header file, wrap all autobridging argument/return types with the `(MF_SWIFT_UNBRIDGED(<the type>))` macro. The macro will replace the type with `id` when swift is looking at it - which disables the autobridiging.
/// 2. When importing the method in Swift, the type will now appear as `Any`. To make the type show up as the proper foundation type, mark the objc implementation with the `NS_REFINED_FOR_SWIFT` flag, then create a Swift extension and implement a method that calls the original, type-erased implementation, and itself takes Foundation types like NSDictionary as arguments.
///  -> Now you can call the ObjC method from Swift using foundation types as arguments directly, instead of being forced to use native Swift types which are then autobridged.
///
/// Note:
/// - There was an older, more convoluted approach using the `MF_SWIFT_HIDDEN` macro and the `__SWIFT_UNBRIDGED_` method name prefix. We removed that in commit `83b93ad3f828764fa4d0e915857adf4623b4b155`.
/// - **TODO:** Test if the new approach actually prevents bridging (Check performance against the old approach)
///

extension NSString {
    
    /// NSString+Additions.h
    
    func substring(withRegex regex: NSString) -> NSString {
        return __substring(withRegex: regex) as! NSString
    }
    func attributed() -> NSAttributedString {
        return __attributed() as! NSAttributedString
    }
    func firstCaptialized() -> NSString {
        return __firstCapitalized() as! NSString
    }
    func stringByRemovingAllWhiteSpace() -> NSString {
        return __stringByRemovingAllWhiteSpace() as! NSString
    }
    func stringByTrimmingWhiteSpace() -> NSString {
        return __stringByTrimmingWhiteSpace() as! NSString
    }
    func string(byAddingIndent indent: NSInteger) -> NSString {
        return __string(byAddingIndent: indent) as! NSString
    }
    func string(byAddingIndent indent: Int, withCharacter character: NSString) -> NSString {
        return __string(byAddingIndent: indent, withCharacter: character) as! NSString
    }
    func string(byPrependingCharacter character: NSString, count: Int) -> NSString {
        return __string(byPrependingCharacter: character, count: count) as! NSString
    }
}

#if IS_MAIN_APP || IS_XC_TEST

extension NSAttributedString {
    
    /// NSString+Steganography.h
    
    func attributedStringByAppendingString(asSecretMessage message: NSString) -> NSAttributedString {
        return __attributedStringByAppendingString(asSecretMessage: message) as! NSAttributedString
    }
    func secretMessages() -> NSArray {
        return __secretMessages() as! NSArray
    }
}

extension NSString {
    
    /// NSString+Steganography.h
    
    func stringByAppendingString(asSecretMessage message: NSString) -> NSString {
        return __stringByAppendingString(asSecretMessage: message) as! NSString
    }
    func encodedAsSecretMessage() -> NSString {
        return __encodedAsSecretMessage() as! NSString
    }
    func secretMessages() -> NSArray {
        return __secretMessages() as! NSArray
    }
    func withoutSecretMessages() -> NSString {
        return __withoutSecretMessages() as! NSString
    }
    
}

#endif


#if IS_HELPER

extension Remap {
    
    static var remaps: NSDictionary {
        return __remaps() as! NSDictionary
    }
    static func modifications(withModifiers modifiers: NSDictionary) -> NSDictionary? {
        return __modifications(withModifiers: modifiers) as! NSDictionary?
    }
    static func sendAddModeFeedback(_ payload: NSDictionary) {
        __sendAddModeFeedback(payload)
    }
}

extension DeviceManager {
    
    static var attachedDevices: NSArray {
        return __attachedDevices() as! NSArray
    }
}

extension Modifiers {
    
    static func modifiers(with event: CGEvent?) -> NSMutableDictionary {
        return __modifiers(with: event) as! NSMutableDictionary
    }
    
    static func buttonModsChanged(to newMods: NSMutableArray) {
        __buttonModsChanged(to: newMods)
    }
}

extension ModifiedDrag {
    
    static func initializeDrag(withDict dict: NSDictionary) {
        __initializeDrag(withDict: dict)
    }
}

extension Actions {

    static func executeActionArray(_ array: NSArray, phase: MFActionPhase) {
        __executeActionArray(array, phase: phase)
    }
}

extension RemapsAnalyzer {
    
    static func modificationsModifyButtons(_ modifications: NSDictionary, maxButton: Int32) -> Bool {
        return __modificationsModifyButtons(modifications, maxButton: maxButton)
    }
    
    static func modificationsModifyScroll(_ modifications: NSDictionary) -> Bool {
        return __modificationsModifyScroll(modifications)
    }
    static func modificationsModifyPointing(_ modifications: NSDictionary) -> Bool {
        return __modificationsModifyPointing(modifications)
    }
    
    static func maxLevel(forButton button: NSNumber, remaps: NSDictionary, modificationsActingOnThisButton: NSDictionary) -> NSInteger {
        return __maxLevel(forButton: button, remaps: remaps, modificationsActingOnThisButton: modificationsActingOnThisButton)
    }
    
    static func effectExists(forButton button: NSNumber, remaps: NSDictionary, modificationsActingOnButton: NSDictionary) -> Bool {
        return __effectExists(forButton: button, remaps: remaps, modificationsActingOnButton: modificationsActingOnButton)
    }
    
    static func assessMappingLandscape(withButton button: NSNumber, level: NSNumber, modificationsActingOnThisButton: NSDictionary, remaps: NSDictionary, thisClickDoBe: UnsafeMutablePointer<ObjCBool>, thisDownDoBe: UnsafeMutablePointer<ObjCBool>, greaterDoBe: UnsafeMutablePointer<ObjCBool>) {
        __assessMappingLandscape(withButton: button, level: level, modificationsActingOnThisButton: modificationsActingOnThisButton, remaps: remaps, thisClickDoBe: thisClickDoBe, thisDownDoBe: thisDownDoBe, greaterDoBe: greaterDoBe)
    }
    
}

#endif
