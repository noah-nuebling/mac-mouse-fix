//
// --------------------------------------------------------------------------
// SwitchMaster.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
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
import CocoaLumberjackSwift

@objc class SwitchMaster: NSObject {
    
    @objc static func load_Manual() {
        
        let attachedDevicesSignal = ReactiveDeviceManager.shared.attachedDevices
        let remapsSignal = ReactiveRemaps.shared.remaps
        
        
        
        let modifiersSignal = ReactiveModifiers.shared.modifiers
        
        attachedDevicesSignal.combineLatest(with: remapsSignal).combineLatest(with: modifiersSignal).startWithValues { (arg0, modifiers: NSDictionary) in
            
            /// Destrucure args
            let (attachedDevices, remaps) = arg0
            
            /// Decide which input to switch on or off
            
            var enableKbModTap = false
            var enableButtonTap = false
            var enableScrollTap = false
            var enableDragTap = false
            
            let decide = {
                
                /// Analyze attached devices
                if attachedDevices.count == 0 { return }
                
                /// Analyze remaps
                
                /// Analyze modifiers
                
                
            }
            
            decide()
            
            DDLogError("Switch Master switching to - kbMod: \(enableKbModTap), button: \(enableButtonTap), scroll: \(enableScrollTap), drag: \(enableDragTap)")
            
            //            DispatchQueue.global(qos: .background).async(flags: defaultDFs) {
            //                decide()
            //            }
            
            
            /// Debug
            //            DDLogError("Switch Master switching with state - devs: \(attachedDevices), remaps: \(remaps), modifiers: \(modifiers)")
            
        }
    }
    
    /// ---
    
    /// Base sginals
    
    /// attachedDevices x
    /// activeModifers x
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
    
    /// Decide buttonModifier callback enable?
    
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
