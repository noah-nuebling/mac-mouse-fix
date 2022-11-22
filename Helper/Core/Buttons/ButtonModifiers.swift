//
// --------------------------------------------------------------------------
// ButtonModifiers.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

/// Module for Buttons.swift

/// Threading:
///     This should only be used by Buttons.swift. Use buttons.swfits dispatchQueue to protect resources.

import Cocoa
import CocoaLumberjackSwift

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
        
        /// I don't think this has any effect under the current architecture. Not totally sure though.
        /// Should we also be notifying buttonModifers here?
        
        removeStateFor(button)
        
        DDLogDebug("buttonModifiers - kill - toState: \(stateDescription())")
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
