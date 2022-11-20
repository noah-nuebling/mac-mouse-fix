//
// --------------------------------------------------------------------------
// RemapSwift.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Cocoa

class RemapSwift: NSObject {
    
    @objc static func load_Manual() {
        
        /// ---
        
        /// Base sginals
        
        /// attachedDevices
        /// activeModifers
        /// remaps
        /// scrollConfig
        
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
