//
// --------------------------------------------------------------------------
// SwitchMaster.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

/// This class dynamically turns on or off interception of certain events from the device based on the current state.
///
/// The relevant state consists of:
/// - attachedDevices
/// - modifiers
/// - modifications (at the time of writing: remaps & scrollConfig)
///
/// The intercepted eventTypes are
/// - Keyboard modifier changes
/// - Scroll wheel input
/// - Mouse button clicks
/// - Mouse movement

import Cocoa

class SwitchMaster: NSObject {
    
    @objc static func load_Manual() {
        
        let attachedDevices = ReactiveDeviceManager.shared.attachedDevices
        let remaps = ReactiveRemaps.shared.remaps
        
        /// ---
        
        /// Base sginals
        
        /// attachedDevices x
        /// activeModifers
        /// remaps x
        ///
        /// scrollConfig (I think we only intended to use this for scrollDirection determination, but I think we'll just go back to calling it 'invert scrolling' and then we won't need this)
        
        /// ---
        
        /// Combine signals
        
        ///
        /// Decide kbModTap enable
        ///
        
        /// if (devicesWithUsableScrollingAreAttached || devicesWithUsableButtonsAreAttached || devicesWithUsablePointerAreAttached) == false { return false }
        /// if kbModsArePrecondition == false { return false }
        /// else { return true }

        ///
        /// Decide scrollTap enable
        ///
        
        /// if devicesWithUsableScrollingAreAttached == false { return false }
        /// if scrollConfigDoesTransform == true { return **true** }
        /// if swizzledScrollTransformsExist == false { return false }
        /// else { return true }
        
        ///
        /// Decide buttonTap enable
        ///
        
        /// if devicesWithUsableButtonsAreAttached == false { return false }
        /// if swizzledButtonTransformationsExistForUsableButtons == false { return false }
        /// else { return true }
        
        ///
        /// Decide dragTap enable
        ///
        
        /// if devicesWithUsablePointerAreAttached == false { return false } // I don't think there will ever be devices without a usable pointer
        /// if swizzledDragTransformsExist == false { return false }
        /// else { return true }
        
    }
    
}
