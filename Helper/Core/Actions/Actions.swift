//
// --------------------------------------------------------------------------
// Actions.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#if IS_HELPER

import Cocoa
import Carbon

@objc public enum MFActionPhase: Int {
    case start
    case end
    case combined
}

public let kMFActionPhaseStart = MFActionPhase.start
public let kMFActionPhaseEnd = MFActionPhase.end
public let kMFActionPhaseCombined = MFActionPhase.combined

@objc(Actions)
public class Actions: NSObject {
    
    @objc public static func executeActionArray(_ actionArray: NSArray, phase: MFActionPhase) {
        DDLogDebug("Executing action array: \(actionArray), phase: \(phase.rawValue)")
        
        if phase == kMFActionPhaseEnd {
            return
        }
        
        for action in actionArray {
            guard let actionDict = action as? NSDictionary else { continue }
            guard let actionType = actionDict[kMFActionDictKeyType] as? String else { continue }
            
            if actionType == kMFActionDictTypeSymbolicHotkey {
                if let num = actionDict[kMFActionDictKeyGenericVariant] as? NSNumber {
                    let shk = num.intValue
                    SymbolicHotKeys.post(CGSSymbolicHotKey(UInt32(shk)))
                }
            } else if actionType == kMFActionDictTypeNavigationSwipe {
                
                // 通用前进后退
                DispatchQueue.main.async {
                    guard let dirString = actionDict[kMFActionDictKeyGenericVariant] as? String else { return }
                    let isLeft = (dirString == kMFNavigationSwipeVariantLeft)
                    let isRight = (dirString == kMFNavigationSwipeVariantRight)
                    
                    if phase == kMFActionPhaseEnd { return }
                    if !(isLeft || isRight) { return }
                    
                    let bundleID = HelperUtility.appUnderMousePointer(with: nil)?.bundleIdentifier
                    
                    func isBundle(_ prefix: String) -> Bool {
                        guard let bid = bundleID else { return false }
                        return bid.hasPrefix(prefix)
                    }
                    
                    if bundleID == nil || bundleID!.isEmpty {
                        bfmethod_mouseButton()
                        return
                    }
                    
                    if isBundle("com.operasoftware.Opera") { bfmethod_navigationSwipe(); return }
                    if isBundle("com.binarynights.ForkLift") { bfmethod_navigationSwipe(); return }
                    
                    if isBundle("org.zotero.zotero") { bfmethod_commandBracket(); return }
                    if isBundle("com.apple.systempreferences") { bfmethod_commandBracket(); return }
                    if isBundle("com.apple.AppStore") { bfmethod_commandBracket(); return }
                    if isBundle("com.adobe.Acrobat.Pro") { bfmethod_commandLeftRightArrow(); return }
                    
                    if isBundle("dev.warp.Warp") { bfmethod_commandBracket(); return }
                    
                    if isBundle("com.apple.Music") { bfmethod_commandBracket(); return }
                    if isBundle("com.apple.iCal") { bfmethod_commandLeftRightArrow(); return }
                    if isBundle("com.apple.AddressBook") { bfmethod_commandBracket(); return }
                    if isBundle("com.apple.Notes") { bfmethod_optionCommandBracket(); return }
                    if isBundle("com.apple.freeform") { bfmethod_optionCommandBracket(); return }
                    if isBundle("com.apple.TV") { bfmethod_commandBracket(); return }
                    if isBundle("com.apple.iBooksX") { bfmethod_commandBracket(); return }
                    if isBundle("com.apple.Preview") { bfmethod_commandBracket(); return }
                    
                    if isBundle("com.apple.") {
                        bfmethod_navigationSwipe()
                    } else {
                        bfmethod_mouseButton()
                    }
                    
                    func bfmethod_mouseButton() {
                        DDLogDebug("Actions.swift: NavigationSwipe: Posting bfmethod_mouseButton")
                        if isLeft {
                            ModificationUtility.postMouseButtonClicks(MFMouseButtonNumber(4), nOfClicks: 1)
                        } else {
                            ModificationUtility.postMouseButtonClicks(MFMouseButtonNumber(5), nOfClicks: 1)
                        }
                    }
                    
                    func bfmethod_navigationSwipe() {
                        DDLogDebug("Actions.swift: NavigationSwipe: Posting bfmethod_navigationSwipe")
                        if isLeft {
                            TouchSimulator.postNavigationSwipeEvent(withDirection: IOHIDSwipeMask(kIOHIDSwipeLeft))
                        } else {
                            TouchSimulator.postNavigationSwipeEvent(withDirection: IOHIDSwipeMask(kIOHIDSwipeRight))
                        }
                    }
                    
                    func bfmethod_commandBracket() {
                        DDLogDebug("Actions.swift: NavigationSwipe: Posting bfmethod_commandBracket")
                        let rawKey = isLeft ? kVK_ANSI_LeftBracket : kVK_ANSI_RightBracket
                        let shortcut = MFEmulateNSMenuItemRemapping(CGKeyCode(rawKey), .maskCommand)
                        postKeyboardShortcut(keyCode: shortcut.vkc, modifierFlags: CGSModifierFlags(UInt32(shortcut.modifierMask.rawValue)))
                    }
                    
                    func bfmethod_commandLeftRightArrow() {
                        DDLogDebug("Actions.swift: NavigationSwipe: Posting bfmethod_commandLeftRightArrow")
                        let rawKey = isLeft ? kVK_LeftArrow : kVK_RightArrow
                        postKeyboardShortcut(keyCode: CGKeyCode(rawKey), modifierFlags: CGSModifierFlags(UInt32(CGEventFlags.maskCommand.rawValue)))
                    }
                    
                    func bfmethod_optionCommandBracket() {
                        DDLogDebug("Actions.swift: NavigationSwipe: Posting bfmethod_optionCommandBracket")
                        let rawKey = isLeft ? kVK_ANSI_LeftBracket : kVK_ANSI_RightBracket
                        let mask: CGEventFlags = [.maskAlternate, .maskCommand]
                        let shortcut = MFEmulateNSMenuItemRemapping(CGKeyCode(rawKey), mask)
                        postKeyboardShortcut(keyCode: shortcut.vkc, modifierFlags: CGSModifierFlags(UInt32(shortcut.modifierMask.rawValue)))
                    }
                }
                
            } else if actionType == kMFActionDictTypeSmartZoom {
                TouchSimulator.postSmartZoomEvent()
            } else if actionType == kMFActionDictTypeKeyboardShortcut {
                if let keycodeNum = actionDict[kMFActionDictKeyKeyboardShortcutVariantKeycode] as? NSNumber,
                   let flagsNum = actionDict[kMFActionDictKeyKeyboardShortcutVariantModifierFlags] as? NSNumber {
                    postKeyboardShortcut(keyCode: CGKeyCode(keycodeNum.intValue), modifierFlags: CGSModifierFlags(UInt32(flagsNum.uint64Value)))
                }
            } else if actionType == kMFActionDictTypeSystemDefinedEvent {
                if let typeNum = actionDict[kMFActionDictKeySystemDefinedEventVariantType] as? NSNumber,
                   let flagsNum = actionDict[kMFActionDictKeySystemDefinedEventVariantModifierFlags] as? NSNumber {
                    let type = MFSystemDefinedEventType(rawValue: typeNum.uint32Value)
                    postSystemDefinedEvent(type: type, modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(flagsNum.uint64Value)))
                }
            } else if actionType == kMFActionDictTypeMouseButtonClicks {
                if let buttonNum = actionDict[kMFActionDictKeyMouseButtonClicksVariantButtonNumber] as? NSNumber,
                   let clicksNum = actionDict[kMFActionDictKeyMouseButtonClicksVariantNumberOfClicks] as? NSNumber {
                    ModificationUtility.postMouseButtonClicks(MFMouseButtonNumber(UInt32(buttonNum.intValue)), nOfClicks: Int64(clicksNum.intValue))
                }
            } else if actionType == kMFActionDictTypeAddModeFeedback {
                if let payload = actionDict.mutableCopy() as? NSMutableDictionary {
                    payload.removeObject(forKey: kMFActionDictKeyType)
                    Remap.sendAddModeFeedback(payload)
                }
            } else if actionType == kMFActionDictTypeToggleSmartShift {
                DDLogInfo("[SMARTSHIFT] Actions.swift - ToggleSmartShift action triggered")
                DispatchQueue.main.async {
                    if let activeDev = HelperState.shared.activeDevice {
                        DDLogInfo("[SMARTSHIFT] Actions.swift - ToggleSmartShift: activeDevice is \(activeDev.name) (iohidDevice: \(String(describing: activeDev.iohidDevice)))")
                        if let iohidDevice = activeDev.iohidDevice {
                            let success = LogitechActivator.shared.toggleSmartShiftForDevice(iohidDevice)
                            DDLogInfo("[SMARTSHIFT] Actions.swift - ToggleSmartShift executed. Success: \(success)")
                        }
                    } else {
                        DDLogWarn("[SMARTSHIFT] Actions.swift - ToggleSmartShift failed because no active device was found")
                    }
                }
            }
        }
    }
    
    private static func postSystemDefinedEvent(type: MFSystemDefinedEventType, modifierFlags: NSEvent.ModifierFlags) {
        let tapLoc = CGEventTapLocation.cgSessionEventTap
        let loc = NSEvent.mouseLocation
        
        var data = 0
        data |= Int(kMFSystemDefinedEventBase)
        data |= Int(type.rawValue << 16)
        
        let downData = data
        let upData = data | Int(kMFSystemDefinedEventPressedMask)
        
        let ts = ModificationUtility.nsTimeStamp()
        if let e = NSEvent.otherEvent(with: .systemDefined, location: loc, modifierFlags: modifierFlags, timestamp: ts, windowNumber: -1, context: nil, subtype: 8, data1: downData, data2: -1) {
            if let cgEvent = e.cgEvent {
                cgEvent.post(tap: tapLoc)
            }
        }
        
        let ts2 = ModificationUtility.nsTimeStamp()
        if let e2 = NSEvent.otherEvent(with: .systemDefined, location: loc, modifierFlags: modifierFlags, timestamp: ts2, windowNumber: -1, context: nil, subtype: 8, data1: upData, data2: -1) {
            if let cgEvent2 = e2.cgEvent {
                cgEvent2.post(tap: tapLoc)
            }
        }
    }
    
    private static func postKeyboardShortcut(keyCode: CGKeyCode, modifierFlags: CGSModifierFlags) {
        DDLogDebug("postKeyboardShortcut: Posting shortcut with keyCode: \(keyCode), modifierFlags: \(modifierFlags.rawValue)")
        let tapLoc = CGEventTapLocation.cgSessionEventTap
        
        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false),
              let modEvent = CGEvent(source: nil) else {
            return
        }
        
        keyDown.flags = CGEventFlags(rawValue: UInt64(modifierFlags.rawValue))
        keyUp.flags = CGEventFlags(rawValue: UInt64(modifierFlags.rawValue))
        modEvent.flags = []
        
        let currentLayout = MFKeyboardTypeCurrent()
        keyDown.setIntegerValueField(.keyboardEventKeyboardType, value: Int64(currentLayout.rawValue))
        keyUp.setIntegerValueField(.keyboardEventKeyboardType, value: Int64(currentLayout.rawValue))
        
        keyDown.post(tap: tapLoc)
        keyUp.post(tap: tapLoc)
        modEvent.post(tap: tapLoc)
    }
}

#endif
