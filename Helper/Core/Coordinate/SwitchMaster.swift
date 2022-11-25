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
//   EDIT: We did end up using fancy reactive stuff.
///
/// On Optimization
/// - We should move the remapsAnalysis methods into RemapsAnalyzer and cache the ones that are used when the modifier state changes.
///
// TODO: Implement killSwitch signals

import Cocoa
import CocoaLumberjackSwift

@objc class SwitchMaster: NSObject {
    
    //
    // MARK: Storage
    //
    
    ///
    /// Singleton
    ///
    
    @objc static let shared = SwitchMaster()
    
    ///
    /// State
    ///
    
    /// NOTE: Some (most?, all?) of these are sort of unnecessary to store here separately. E.g. `someDeviceHasScroll` can just be read from the DeviceManager.
    
    /// Derived from: Attached Devices
    
    var someDeviceHasScroll = false
    var someDeviceHasPointing = false
    var someDeviceHasUsableButtons = false
    var maxButtonNumberAmongDevices: Int32 = 0
    
    /// Derived from: Various
    
    var defaultModifiesScroll = false /// Derives from: Scroll Config
    let defaultModifiesPointing = false /// Always false
    var defaultModifiesButtonOnSomeDevice = false /// Derives from: Remaps & Attached Devices
    
    /// Derived from: Remaps
    
    var somekbModModifiesScroll = false
    var somekbModModifiesPointing = false
    var somekbModModifiesButtonOnSomeDevice = false /// & derives from: Attached Devices
    
    var someButtonModifiesScroll = false
    var someButtonModifiesPointing = false
    var someButtonModifiesButtonOnSomeDevice = false /// & derives from: Attached Devices
    
    /// Derived from: Modifiers & Remaps
    
    var currentModificationModifiesScroll = false
    var currentModificationModifiesPointing = false
    var currentModificationModifiesButtonOnSomeDevice = false /// & derives from: Attached Devices
    
    @objc func load_Manual() {
        
        /// Get signals
        
        let attachedDevicesSignal = ReactiveDeviceManager.shared.attachedDevices
        let remapsSignal = ReactiveRemaps.shared.remaps
        let scrollConfigSignal = ReactiveScrollConfig.shared.scrollConfig
        let modifiersSignal = ReactiveModifiers.shared.modifiers
        
        // MARK: Update state
        
        /// Attached Devices Signal
        
        attachedDevicesSignal.startWithValues { devices in
            
            self.someDeviceHasScroll = DeviceManager.someDeviceHasScrollWheel()
            self.someDeviceHasPointing = DeviceManager.someDeviceHasPointing()
            self.someDeviceHasUsableButtons = DeviceManager.someDeviceHasUsableButtons()
            self.maxButtonNumberAmongDevices = DeviceManager.maxButtonNumberAmongDevices()
        }
        
        /// Remaps Signal
        
        remapsSignal.startWithValues { remaps in
            
            (self.somekbModModifiesPointing,
             self.somekbModModifiesScroll,
             self.someButtonModifiesPointing,
             self.someButtonModifiesScroll) = self.modifierUsage_Point_Scroll(remaps)
        }
        
        /// Remaps & Attached Devices Signal
        
        remapsSignal.combineLatest(with: attachedDevicesSignal).startWithValues { (remaps, attachedDevices) in
            
            (self.somekbModModifiesButtonOnSomeDevice, self.someButtonModifiesButtonOnSomeDevice) = self.modifierUsage_Buttons(remaps)
            self.defaultModifiesButtonOnSomeDevice = self.defaultModifiesButtonOnSomeDevice(remaps)
        }
        
        /// Scroll Config Signal
        
        scrollConfigSignal.startWithValues { scrollConfig in
            
            self.defaultModifiesScroll = !scrollConfig.killSwitch &&
            (scrollConfig.u_smoothEnabled || scrollConfig.u_speed != "system" || scrollConfig.u_invertDirection == kMFScrollInversionInverted)
            
        }
        
        /// Remaps & Modifiers Signal
        ///  NOTE: The callbacks are called whenever the modifiers change so they need to be fast!
        
        let modificationsSignal = remapsSignal.combineLatest(with: modifiersSignal).map { (remaps, modifiers) in Remap.modifications(withModifiers: modifiers) }
        
        
        modificationsSignal.startWithValues { modifications in
            self.currentModificationModifiesScroll = self.modificationModifiesScroll(modifications)
            self.currentModificationModifiesPointing = self.modificationModfiesPointing(modifications)
        }
        
        /// Remaps & Modifiers & Attached Devices Signal
        
        modificationsSignal.combineLatest(with: attachedDevicesSignal).startWithValues { (modifications, attachedDevices) in
            self.currentModificationModifiesButtonOnSomeDevice = self.modificationModifiesButtons(modification: modifications, maxButton: DeviceManager.maxButtonNumberAmongDevices())
        }
        
        // MARK: Call tap togglers
        
        attachedDevicesSignal.startWithValues { _ in
            
            self.toggleKbModTap()
            self.toggleBtnModProcessing()
            
            self.toggleScrollTap()
            self.toggleButtonTap()
            self.togglePointingTap()
        }
        remapsSignal.startWithValues { _ in
            
            self.toggleKbModTap()
            self.toggleBtnModProcessing()
            
            self.toggleScrollTap()
            self.toggleButtonTap()
            self.togglePointingTap()
        }
        scrollConfigSignal.startWithValues { _ in
            
            self.toggleKbModTap()
            self.toggleBtnModProcessing()
            
            self.toggleScrollTap()
        }

        modifiersSignal.startWithValues { _ in
            
            self.toggleScrollTap()
            self.toggleButtonTap()
            self.togglePointingTap()
        }
    }
    
    //
    // MARK: Tap togglers
    //
    
    private func toggleKbModTap() {
        
        var priority = kMFModifierPriorityUnused
        
        let kbModsAreUsed =
        (someDeviceHasScroll && somekbModModifiesScroll)
        || (someDeviceHasPointing && somekbModModifiesPointing)
        || (someDeviceHasUsableButtons && somekbModModifiesButtonOnSomeDevice)
        
        if kbModsAreUsed {
            
            let someKbModsToggleScroll = !defaultModifiesScroll && somekbModModifiesScroll
            let someKbModsTogglePointing = !defaultModifiesPointing && somekbModModifiesPointing
            let someKbModsToggleButtons = !defaultModifiesButtonOnSomeDevice && somekbModModifiesButtonOnSomeDevice
            
            if  (someDeviceHasScroll && someKbModsToggleScroll)
                    || (someDeviceHasPointing && someKbModsTogglePointing)
                    || (someDeviceHasUsableButtons && someKbModsToggleButtons) {
                
                priority = kMFModifierPriorityActiveListen
            } else {
                priority = kMFModifierPriorityPassiveUse
            }
        }
        
        Modifiers.setKeyboardModifierPriority(priority)
    }
    
    private func toggleBtnModProcessing() {
        
        var priority = kMFModifierPriorityUnused
        
        let buttonsAreUsedAsModifiers =
        (someDeviceHasScroll && someButtonModifiesScroll)
        || (someDeviceHasPointing && someButtonModifiesPointing)
        || (someDeviceHasUsableButtons && someButtonModifiesButtonOnSomeDevice)
        
        if  buttonsAreUsedAsModifiers {
            
            let someBtnModsToggleScroll = !defaultModifiesScroll && someButtonModifiesScroll
            let someBtnModsTogglePointing = !defaultModifiesPointing && someButtonModifiesPointing
            let someBtnModsToggleButtons = !defaultModifiesButtonOnSomeDevice && someButtonModifiesButtonOnSomeDevice
            
            let buttonModifiersToggleTaps =
            (someDeviceHasScroll && someBtnModsToggleScroll)
            || (someDeviceHasPointing && someBtnModsTogglePointing)
            || (someDeviceHasUsableButtons && someBtnModsToggleButtons)
            
            if buttonModifiersToggleTaps {
                priority = kMFModifierPriorityActiveListen
            } else {
                priority = kMFModifierPriorityPassiveUse
            }
        }
        
        Modifiers.setButtonModifierPriority(priority)
    }
    
    private func toggleScrollTap() {
        
        if someDeviceHasScroll && (defaultModifiesScroll || currentModificationModifiesScroll) {
            Scroll.start()
        } else {
            Scroll.stop()
        }
    }
    
    private func toggleButtonTap() {
    
        let buttonsAreUsedAsModifiers =
        (someDeviceHasScroll && someButtonModifiesScroll)
        || (someDeviceHasPointing && someButtonModifiesPointing)
        || (someDeviceHasUsableButtons && someButtonModifiesButtonOnSomeDevice)
        
        if someDeviceHasUsableButtons && (currentModificationModifiesButtonOnSomeDevice || buttonsAreUsedAsModifiers) {
            
            ButtonInputReceiver.start()
        } else {
            ButtonInputReceiver.stop()
        }
    }
    
    private func togglePointingTap() {
        
        /// Determine enable
        let enable = someDeviceHasPointing && currentModificationModifiesPointing
        
        if enable {
            
            /// Get modifications
            /// - Maybe we should store the "latestModifications" as an instance var for optimzation && to keep things clean? Aside from this we're only using instance vars in the tapTogglers, I feel like maybe there's is some architectural idea for why we only need to use instance vars.
            let modifications = Remap.modifications(withModifiers: Modifiers.modifiers(with: nil))
            
            /// Initialize ModifiedDrag
            if let dragEffect = modifications?.object(forKey: kMFTriggerDrag) as! NSDictionary? {
                ModifiedDrag.initializeDrag(withDict: dragEffect)
            } else {
                assert(false)
            }
        } else {
            ModifiedDrag.deactivate()
        }
    }
    
    //
    // MARK: Remaps analysis
    //
    
    // TODO: Put this into remapsAnalyzer
    ////   In RemapsAnalyzer, create methods:
    /// - 1. modifesScroll(modifiers: )
    /// - 2. modifesDrag(modifiers: )
    /// - 3. minimumModifiedButton(modifiers: )
    /// - 4. etc...
    /// Then cache access for super super fast SwitchMaster
    
    /// Modification analysis
    
    func modificationModifiesButtons(modification: NSDictionary?, maxButton: Int32) -> Bool {
        
        /// Return true if the modification modifies any button `<=` maxButton
        
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
    
    fileprivate func modificationModfiesPointing(_ modification: NSDictionary?) -> Bool {
        return modification?.object(forKey: kMFTriggerDrag) != nil
    }
    
    
    /// Remaps analysis
    
    fileprivate func modifierUsage_Buttons(_ remaps: NSDictionary?) -> (somekbModModifiesButtonOnSomeDevice: Bool,
                                                                       someButtonModifiesButtonOnSomeDevice: Bool) {
        
        var kbModSways = false
        var btnSways = false
        
        remaps?.enumerateKeysAndObjects(options: [/*.concurrent*/]) { modifiers, modification, stop in
            
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
                    let doesModify = self.modificationModifiesButtons(modification: (modification as! NSDictionary), maxButton: DeviceManager.maxButtonNumberAmongDevices())
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
        
        return (somekbModModifiesButtonOnSomeDevice: kbModSways, someButtonModifiesButtonOnSomeDevice: btnSways)
    }
    
    fileprivate func defaultModifiesButtonOnSomeDevice(_ remaps: NSDictionary) -> Bool {
        
        var defaultSways = false
        
        let empty = NSDictionary()
        if let defaultModification = remaps.object(forKey: empty) as? NSDictionary {
            defaultSways = self.modificationModifiesButtons(modification: defaultModification, maxButton: DeviceManager.maxButtonNumberAmongDevices())
        }
        
        return defaultSways
    }
    
    fileprivate func modifierUsage_Point_Scroll(_ remaps: NSDictionary) -> (someKbModModifiesPointing: Bool, someKbModModifiesScroll: Bool, someButtonModifiesPointing: Bool, someButtonModifiesScroll: Bool) {
        
        var kbSwayPoint = false
        var kbSwayScroll = false
        var btnSwayPoint = false
        var btnSwayScroll = false
        
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
                    let point = self.modificationModfiesPointing(modification as? NSDictionary)
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
        
        return (someKbModModifiesPointing: kbSwayPoint, someKbModModifiesScroll: kbSwayScroll, someButtonModifiesPointing: btnSwayPoint, someButtonModifiesScroll: btnSwayScroll)
    }
}
