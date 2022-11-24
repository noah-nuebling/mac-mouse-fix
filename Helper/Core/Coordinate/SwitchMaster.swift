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
/// - modifications (at the time of writing: remaps & scrollConfig)
/// - modifiers
///
/// The intercepted eventTypes are
/// - Keyboard modifier changes
/// - Scroll wheel input
/// - Mouse button clicks
/// - Mouse movement
///
/// On listening to activeDevice
/// - This would let us turn off buttonTap / scrollTap for mice that don't support buttons / don't support scrolling. However then we couldn't re-enable the tap when another mouse sends scroll or button input because we wouldn't be listening to that input. So it's better to just listen to all attachedDevices.
///
/// On using reactive signals
/// - It's pretty unnecessary since we're not using any fancy ReactiveSwift features like we thought we would. We could just as well use simple callbacks.
//  -> TODO: Remove Reactive stuff if it's too slow
///
/// On Optimization
/// - We could toggle buttonModifier listening. Modifers.m has that capability
/// - Cache some of the remaps analysis methods
/// - Store maxNOfNumbers on the deviceManger and don't recalculate nOfButtons in Device class
///
// TODO: Implement killSwitch signals

import Cocoa
import CocoaLumberjackSwift

@objc class SwitchMaster: NSObject {
    
    ///
    /// Singleton
    ///
    
    @objc static let shared = SwitchMaster()
    
    ///
    /// State
    ///
    
    /// Derived from: Attached Devices
    
    var someDeviceHasScroll = false
    var someDeviceHasPointer = false
    var someDeviceHasUsableButtons = false
    var maxNOfButtons: Int32 = 0 // TODO: Store this on the device manager
    
    /// Derived from: Various
    
    var defaultModifiesScroll = false /// Derives from: Scroll Config
    let defaultModifiesPointer = false /// Always false
    var defaultModifiesButtonOnSomeDevice = false /// Derives from: Remaps & Attached Devices
    
    /// Derived from: Remaps
    
    var somekbModModifiesScroll = false
    var somekbModModifiesPointer = false
    var somekbModModifiesButtonOnSomeDevice = false /// & derives from: Attached Devices
    
    var someButtonModifiesScroll = false
    var someButtonModifiesPointer = false
    var someButtonModifiesButtonOnSomeDevice = false /// & derives from: Attached Devices
    
    /// Derived from: Modifiers & Remaps
    
    var modificationModifiesScroll = false
    var modificationModifiesPointer = false
    var modificationModifiesButtonOnSomeDevice = false /// & derives from: Attached Devices
    
    ///
    /// Init
    ///
    
    @objc func load_Manual() {
        
        /// Get signals
        
        let attachedDevicesSignal = ReactiveDeviceManager.shared.attachedDevices
        let remapsSignal = ReactiveRemaps.shared.remaps
        let scrollConfigSignal = ReactiveScrollConfig.shared.scrollConfig
        let modifiersSignal = ReactiveModifiers.shared.modifiers
        
        ///
        ///
        /// State update callbacks
        ///
        ///
        
        ///
        /// Attached devices
        ///
        
        attachedDevicesSignal.startWithValues { devices in
            
            var scroll = false
            var point = false
            var buttons: Int32 = 0
            
            if devices.count > 0 {
                scroll = true
                point = true
                for device in devices {
                    let device = device as! Device
                    let b = device.nOfButtons()
                    if b > buttons { buttons = b }
                }
            }
            
            self.someDeviceHasScroll = scroll
            self.someDeviceHasPointer = point
            self.someDeviceHasUsableButtons = buttons > 2
            self.maxNOfButtons = buttons
        }
        
        ///
        /// Remaps
        ///
        
        remapsSignal.startWithValues { remaps in
            
            var kbSwayScroll = false
            var kbSwayPoint = false
            var btnSwayScroll = false
            var btnSwayPoint = false
            
            remaps.enumerateKeysAndObjects(options: [/*.concurrent*/]) { modifiers, modification, stop in
                
                /// Notes:
                ///  - `.concurrent` option should make things slower for small arrays. See https://darkdust.net/writings/objective-c/nsarray-enumeration-performance
                ///   - All these if statements totally overcomplicate things. It's what I call "Premature Boptimization"
                ///   - Notice how we made it even faster by first looking at the modifers and then looking at the modification because the modifiers have less keys usually.
                ///   - This only happens when the remaps change, and we should just cache this if it's slow. There is no reason whatsoever to make this so fast and unreadable.
                ///   - Just using a for...in loop on the dict also gives you the keys and values in Swift, so using `enumerateKeysAndObjects` is probably not the best idea since it might be slower than a simple loop.
                
                var keyboard = false
                var button = false
                
                if !kbSwayPoint || !kbSwayScroll {
                    keyboard = (modifiers as! NSDictionary).object(forKey: kMFModificationPreconditionKeyKeyboard) != nil
                }
                if !btnSwayPoint || !btnSwayScroll {
                    button = (modifiers as! NSDictionary).object(forKey: kMFModificationPreconditionKeyButtons) != nil
                }
                
                if keyboard || button {
                    
                    if (!kbSwayPoint && keyboard) || (!btnSwayPoint && button) {
                        let point = self.modificationModfiesPointer(modification as? NSDictionary)
                        btnSwayPoint = button && point
                        kbSwayPoint = keyboard && point
                    }
                    if (!kbSwayScroll && keyboard) || (!btnSwayScroll && button) {
                        let scroll = self.modificationModifiesScroll(modification as? NSDictionary)
                        btnSwayScroll = button && scroll
                        kbSwayScroll = keyboard && scroll
                    }
                }
                
                if kbSwayScroll && kbSwayPoint && btnSwayScroll && btnSwayPoint {
                    stop.pointee = ObjCBool.init(true)
                }
            }
            
            self.somekbModModifiesScroll = kbSwayScroll
            self.somekbModModifiesPointer = kbSwayPoint
            self.someButtonModifiesScroll = btnSwayScroll
            self.someButtonModifiesPointer = btnSwayPoint
            
        }
        
        ///
        /// Remaps & Attached Devices
        ///
        
        remapsSignal.combineLatest(with: attachedDevicesSignal).startWithValues { (remaps, attachedDevices) in
            
            var kbModSways = false
            var btnSways = false
            
            remaps.enumerateKeysAndObjects(options: [/*.concurrent*/]) { modifiers, modification, stop in
                
                var keyboard = false
                var button = false
                
                if !kbModSways {
                    keyboard = (modifiers as! NSDictionary).object(forKey: kMFModificationPreconditionKeyKeyboard) != nil
                }
                if !btnSways {
                    button = (modifiers as! NSDictionary).object(forKey: kMFModificationPreconditionKeyButtons) != nil
                }
                
                if keyboard || button {
                    
                    if (!kbModSways && keyboard) || (!btnSways && button) {
                        let doesModify = self.modificationModifiesButtons(modification: (modification as! NSDictionary), maxButton: self.maxNOfButtons)
                        if doesModify {
                            kbModSways = keyboard
                            btnSways = button
                        }
                    }
                }
                
                if kbModSways && btnSways {
                    stop.pointee = ObjCBool.init(true)
                }
            }
            
            self.somekbModModifiesButtonOnSomeDevice = kbModSways
            self.someButtonModifiesButtonOnSomeDevice = btnSways
            
            var defaultSways = false
            
            let empty = NSDictionary()
            if let defaultModification = remaps.object(forKey: empty) as? NSDictionary {
                defaultSways = self.modificationModifiesButtons(modification: defaultModification, maxButton: self.maxNOfButtons)
            }
            
            self.defaultModifiesButtonOnSomeDevice = defaultSways
        }
        
        ///
        /// Scroll Config
        ///
        
        scrollConfigSignal.startWithValues { scrollConfig in
            
            self.defaultModifiesScroll = !scrollConfig.killSwitch &&
            (scrollConfig.u_smoothEnabled || scrollConfig.u_speed != "system" || scrollConfig.u_invertDirection == kMFScrollInversionInverted)
            
        }
        
        ///
        /// Remaps & Modifiers
        ///
        /// These are called whenever the modifiers change so they need to be fast!
        
        let modificationsSignal = remapsSignal.combineLatest(with: modifiersSignal).map { (remaps, modifiers) in Remap.modifications(withModifiers: modifiers) }
        
        modificationsSignal.startWithValues { modification in
            
            self.modificationModifiesScroll = self.modificationModifiesScroll(modification)
            self.modificationModifiesPointer = self.modificationModfiesPointer(modification)
        }
        
        ///
        /// Remaps & Modifiers & Attached Devices
        ///
        modificationsSignal.combineLatest(with: attachedDevicesSignal).startWithValues { (modifiers, attachedDevices) in
            
            /// This is called whenever the modifiers change so this should be fast!
            var modification: NSDictionary? = nil
            if let modifiers = modifiers {
                modification = Remap.modifications(withModifiers: modifiers)
            }
            self.modificationModifiesButtonOnSomeDevice = self.modificationModifiesButtons(modification: modification, maxButton: self.maxNOfButtons)
        }
        
        ///
        ///
        /// Toggling callbacks
        ///
        ///
        
        attachedDevicesSignal.startWithValues { _ in
            
            self.toggleKbModTap()
            self.toggleBtnModProcessing()
            
            self.toggleScrollTap()
            self.toggleButtonTap()
            self.togglePointerTap()
        }
        remapsSignal.startWithValues { _ in
            
            self.toggleKbModTap()
            self.toggleBtnModProcessing()
            
            self.toggleScrollTap()
            self.toggleButtonTap()
            self.togglePointerTap()
        }
        scrollConfigSignal.startWithValues { _ in
            
            self.toggleKbModTap()
            self.toggleBtnModProcessing()
            
            self.toggleScrollTap()
        }

        modifiersSignal.startWithValues { _ in
            
            self.toggleScrollTap()
            self.toggleButtonTap()
            self.togglePointerTap()
        }
    }
    
    ///
    /// State update helper
    ///
    
    func modificationModifiesButtons(modification: NSDictionary?, maxButton: Int32) -> Bool {
        
        /// Return true if the modification modifies any button `<=` maxButton
        // TODO: Move this into RemapsAnalyzer.
        ////    In RemapsAnalyzer, create methods:
        /// - 1. modifesScroll(modifiers: )
        /// - 2. modifesDrag(modifiers: )
        /// - 3. minimumModifiedButton(modifiers: )
        /// Then cache access for super super fast Master
        
        if let modification = modification {
            
            for element in modification {
                
                guard let btn = element.key as? NSNumber else { continue }
                
                let doesModify = btn.int32Value <= maxButton
                if doesModify { return true }
            }
        }
        
        return false
    }
    
    fileprivate func modificationModifiesScroll(_ modification: NSDictionary?) -> Bool {
        return modification?.object(forKey: kMFTriggerScroll) != nil
    }
    
    fileprivate func modificationModfiesPointer(_ modification: NSDictionary?) -> Bool {
        return modification?.object(forKey: kMFTriggerDrag) != nil
    }
    
    ///
    /// Togglers
    ///
    
    private func toggleKbModTap() {
        
        let someKbModsToggleScroll = (defaultModifiesScroll != somekbModModifiesScroll)
        let someKbModsToggleButtons = (defaultModifiesButtonOnSomeDevice != somekbModModifiesButtonOnSomeDevice)
        let someKbModsTogglePointing = (defaultModifiesPointer != somekbModModifiesPointer)
        
       if  (someDeviceHasScroll && someKbModsToggleScroll)
            || (someDeviceHasUsableButtons && someKbModsToggleButtons)
            || (someDeviceHasPointer && someKbModsTogglePointing) {
           
           /// Toggle on
       } else {
           /// Toggle off
       }
    }
    
    private func toggleBtnModProcessing() {
        
        let someBtnModsToggleScroll = (defaultModifiesScroll != someButtonModifiesScroll)
        let someBtnModsToggleButtons = (defaultModifiesButtonOnSomeDevice != someButtonModifiesButtonOnSomeDevice)
        let someBtnModsTogglePointing = (defaultModifiesPointer != someButtonModifiesPointer)
        
        if  (someDeviceHasScroll && someBtnModsToggleScroll)
             || (someDeviceHasUsableButtons && someBtnModsToggleButtons)
             || (someDeviceHasPointer && someBtnModsTogglePointing) {
            
            /// Toggle on
        } else {
            /// Toggle off
        }
    }
    
    private func toggleScrollTap() {
        
        if someDeviceHasScroll && (defaultModifiesScroll || modificationModifiesScroll) {
            /// Toggle on
        } else {
            /// Toggle off
        }
        
    }
    
    private func toggleButtonTap() {
    
        if someDeviceHasUsableButtons && modificationModifiesButtonOnSomeDevice {
            /// Toggle on
        } else {
            /// Toggle off
        }
    }
    
    private func togglePointerTap() {
        
        if someDeviceHasPointer && modificationModifiesPointer { /// I don't think there will ever be devices without pointing
            /// Toggle on
        } else {
            /// toggle off
        }
    }
    
    ///
    /// v Design notes - delete these
    /// ---
    
    /// Base sginals
    
    /// attachedDevices x
    ///     Replace this with activeDevice signal
    /// activeModifers x
    /// remaps x
    /// scrollConfig x
    ///     (to check if default / modified scrollConfig transforms input)
    
    /// ---
    
    /// Combine signals
    
    ///
    /// Decide kbModTap enable
    ///
    
    /**
     ```
     ///
     /// Decide kbModTap enable
     ///
     
     let someKbModsToggleScroll = (defaultTransformsScroll != somekbModsTransformScroll)
     let someKbModsToggleButtons = (defaultTransformsButtonOnDevice != somekbModsTransformButtonOnDevice)
     let someKbModsTogglePointing = (defaultTransformsPointing != somekbModsTransformPointing)
     
     (deviceHasScrolling && someKbModsToggleScroll)
     || (deviceHasUsableButtons && someKbModsToggleButtons)
     || (deviceHasPointing && someKbModsTogglePointing)
     
     ///
     /// Decide scrollTap enable
     ///
     
     deviceHasScrolling && (defaultTransformsScroll || modificationTransformsScroll)
     
     ///
     /// Decide buttonTap enable
     ///
     
     deviceHasUsableButtons && modificationTransformsButtonOnDevice
     
     ///
     /// Decide dragTap enable
     ///
     
     deviceHasPointing && modificationTransformsDrag // I don't think there will ever be devices without pointing
     
     ```
     */
    
    
}
