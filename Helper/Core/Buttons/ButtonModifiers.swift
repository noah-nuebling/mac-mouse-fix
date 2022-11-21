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

    private var state = Dictionary<ButtonNumber, ButtonState>()
    
    func update(button: ButtonNumber, clickLevel: ClickLevel, downNotUp mouseDown: Bool) {
        
        /// Debug
        DDLogDebug("buttonModifiers - update - lvl: \(clickLevel), mouseDown: \(mouseDown), btn: \(button)")
        
        /// Update state
        if mouseDown {
            let oldState = state[button]
            let pressTime = mouseDown ? CACurrentMediaTime() : (oldState?.pressTime ?? 0) /// Not sure if necessary to ever keep old pressTime
            let newState = ButtonState(button: button,
                                       clickLevel: clickLevel,
                                       isPressed: mouseDown,
                                       pressTime: pressTime)
            
            state[button] = newState
            
            /// Validate
            assert(oldState != newState)
            
        } else {
            state.removeValue(forKey: button)
        }
        
        /// Compile state for `Modifiers` class
        
        let buttonStates = Array(state.values)
        
        let result: [[String: Int]] = buttonStates.filter { bs in
            let isActive = bs.isPressed && bs.clickLevel != 0
            return isActive
        }.sorted { bs1, bs2 in
            bs1.pressTime < bs2.pressTime
        }.map { bs in
            return [
                kMFButtonModificationPreconditionKeyButtonNumber: bs.button,
                kMFButtonModificationPreconditionKeyClickLevel: bs.clickLevel
            ]
        }
        
        /// Debug
        DDLogDebug("buttonModifiers - gotMods: \(result)")
        
        /// Notify `Modifiers` class
        Modifiers.buttonModsChanged(to: result)
    }
    
    func kill(button: ButtonNumber) {
        
        /// I don't think this has any effect under the current architecture. Not totally sure though.
        
        /// Debug
        DDLogDebug("buttonModifiers - kill - btn: \(button)")
        
        state.removeValue(forKey: button)
    }
    
}
