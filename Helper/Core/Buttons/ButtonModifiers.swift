//
// --------------------------------------------------------------------------
// ButtonModifiers.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// Module for Buttons.swift

/// Threading:
///     This should only be used by Buttons.swift. Use buttons.swfits dispatchQueue to protect resources.
/// Optimization:
///     Switft does some weird bridging when when we call `state.add(NSDictionary(dictionaryLiteral:)`, that should be much faster in ObjC

import Cocoa

private struct ButtonState: Equatable {
    var button: ButtonNumber
    var clickLevel: ClickLevel
    var isPressed: Bool
    var pressTime: CFTimeInterval
}

class ButtonModifiers: NSObject {

    private var state = NSMutableArray()
    
    ///Full type`NSArray<NSDictionary<NSString, NSNumber>>`
    
    func update(button: ButtonNumber, clickLevel: ClickLevel, downNotUp mouseDown: Bool) {
        
        /// Copy old state
        let oldState = state.copy() as! NSArray
        
        /// Update state
        if mouseDown {
            state.add(NSDictionary(dictionaryLiteral:
                                    (kMFButtonModificationPreconditionKeyButtonNumber as NSString, button as NSNumber),
                                    (kMFButtonModificationPreconditionKeyClickLevel as NSString, clickLevel as NSNumber)))
            
        } else {
            removeStateFor(button)
        }
        
        if oldState != state {
                
            /// Debug
            DDLogDebug("buttonModifiers - update - toState: \(stateDescription())")
            
            /// Notify
            Modifiers.buttonModsChanged(to: state)
        }
        
//        /// Compile state for `Modifiers` class
//
//        let buttonStates = Array(state.values)
//
//        let result: [[String: Int]] = buttonStates.filter { bs in
//            let isActive = bs.isPressed && bs.clickLevel != 0
//            return isActive
//        }.sorted { bs1, bs2 in
//            bs1.pressTime < bs2.pressTime
//        }.map { bs in
//            return [
//                kMFButtonModificationPreconditionKeyButtonNumber: bs.button,
//                kMFButtonModificationPreconditionKeyClickLevel: bs.clickLevel
//            ]
//        }
//
//        /// Debug
//        DDLogDebug("buttonModifiers - gotMods: \(result)")
//
//        /// Notify `Modifiers` class
//        Modifiers.buttonModsChanged(to: result)
    }
    
    func kill(button: ButtonNumber) {

        return
        
        /// I don't really understand what this does anymore. Should compare this with before the refactor where we simplified ButtonModifers (commit 98470f5ec938454c986e34daf753f827c63b04a5)
        /// Edit:
        /// I think this is primarily so the drag modification is deactivated after hold has been triggered. Not sure if this is desirable behaviour, generally. It's desirable in addMode, but we should probably implement another mechanism where ModifiedScroll is reloaded when addMode is deactivated that would make this obsolete.
        // -> TODO: Try to do this when we implement SwitchMaster. Then turn this off if successful.
        
        /// Copy old state
        let oldState = state.copy() as! NSArray
        
        /// Update state
        removeStateFor(button)
        
        if oldState != state {
         
            /// Debug
            DDLogDebug("buttonModifiers - kill - toState: \(stateDescription())")
            
            /// Notify
            Modifiers.buttonModsChanged(to: state)
        }
    }
    
    /// Helper
    private func removeStateFor(_ button: ButtonNumber) {
        
        for i in 0..<state.count {
            let buttonState = state.object(at: i)
            let buttonNumber = ((buttonState as! NSDictionary).object(forKey: kMFButtonModificationPreconditionKeyButtonNumber) as! NSNumber)
            
            if buttonNumber == (button as NSNumber) {
                state.removeObject(at: i)
                return
            }
        }
    }
    
    /// Debug
    private func stateDescription() -> String {
        
        return (state as! [[String: Int]]).map({ (element: [String: Int]) -> String in
            return "(\(element[kMFButtonModificationPreconditionKeyButtonNumber]!), \(element[kMFButtonModificationPreconditionKeyClickLevel]!))"
        }).joined(separator: " ")
    }
    
}
