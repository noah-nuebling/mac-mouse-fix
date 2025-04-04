//
// --------------------------------------------------------------------------
// SwitchMaster.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
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
///
/// On Optimization
/// - [ ] When buttons are not used as trigger and are only used as modifier in combination with kbMod, we could switch off buttonTap until kbMods are pressed.
///     - -> Implementation ideas: only toggle buttonTap if button is used as "solo" modifier (without kbMod requirement) or if the kbMod it could "complete" a modification precondition together with the currently active keyboard modifiers.
///     - This might be easier impelement / more performant if we encode this kbMods -> btnMods -> modifications hierarchy into the remaps dataStructure, currently it has a form (kbMods, btnMods) -> modifications. Or if we bring back the original "modifiying actions" architecture. But that probably requires large architectural changes and would create other problems.
/// - [x] We should move the remapsAnalysis methods into RemapsAnalyzer and cache the ones that are used when the modifier state changes.
///     - -> Moved the performance-critical stuff to RemapsAnalyzer. Tried caching but it didn't speed things up (at least the way I did it - maybe if we cache bigger chunks of data we could get a speedup)
/// - [x] Using simple function calls instead of reactiveSwift should improve performance a decent bit. Should consider that,at least for the buttonModifier input
///     - Improved performance a good bit. See commit 1a15623bd254d548b553d0073df1bf72887f1ac1.
///
/// Issues:
/// - When you detach mouse during modifiedDrag, modifiedDrag will immediately re-enable when you re-attach the mouse. I think this is because the modifier state doesn't reset properly when the mouse is detached.
///
/// Testing: [ ]
/// - [ ] Keyboard Modifiers have 0% CPU usage when not toggling another tap
/// - [ ] Scrolling has 0% CPU usage when umodified
/// - [ ] Buttons have 0% CPU usage when not (modified or toggling another tap)
/// - [ ] Buttons work as modifiers even if no buttons are modified
/// - [ ] Pointing has 0% CPU usage when unmodified
/// - AddMode works even when all input taps are turned off for (and the assigned action also works)
///  - [ ] Click, Hold, Double Click, Button Modifier + Click, Keyboard Modifier + Click
///  - [ ] Click and Drag, Double Click and Drag, Keyboard Modifier + Click and Drag
///  - [ ] Click and Scroll, Double Click and Scroll, Keyboard Modifier + Click and Scroll
/// - Kill switch testing
///  - [ ] 0% CPU when using either of the killSwitces
///  - [ ] When kbMods toggle scrollTap (and nothing else), scrollKillSwitch also disables kbModTap
///  - [ ] addMode still works with the killSwitches are enabled
/// - [x] Test if lockDown works
///
// TODO: ...
/// - [x] Implement killSwitch signals
/// - [x] Implement trial expired lockdown
/// - [x] Deactivate killSwitches when the intercept they control is disabled anyways -> Didn't like this

import Cocoa
import CocoaLumberjackSwift
import ReactiveSwift

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
    
    /// UPDATE: If I still understand correctly, this is all the state that is used inside the tapTogglers, to decide if an eventTap should be enabled or not.
    /// NOTE: Some (most?, all?) of these are somwhat of unnecessary to store here separately. E.g. `someDeviceHasScroll` can just be read from the DeviceManager. However it helps me think about the complicated logic, to gather all the relevant state here.
    
    /// Derived from: Attached Devices
    
    var someDeviceHasScroll                 = false
    var someDeviceHasPointing               = false
    var someDeviceHasUsableButtons          = false
    var maxButtonNumberAmongDevices: Int32  = 0
    
    /// Derived from: Various
    
    var defaultModifiesScroll               = false /// Derives from: Scroll Config
    let defaultModifiesPointing             = false /// Always false
    var defaultModifiesButtonOnSomeDevice   = false /// Derives from: Remaps & Attached Devices
    
    /// Derived from: Remaps
    
    var somekbModModifiesScroll             = false
    var somekbModModifiesPointing           = false
    var somekbModModifiesButtonOnSomeDevice = false /// & derives from: Attached Devices
    
    var someButtonModifiesScroll                = false
    var someButtonModifiesPointing              = false
    var someButtonModifiesButtonOnSomeDevice    = false /// & derives from: Attached Devices
    
    /// Derived from: Modifiers & Remaps
    
    var currentModificationModifiesScroll               = false
    var currentModificationModifiesPointing             = false
    var currentModificationModifiesButtonOnSomeDevice   = false /// & derives from: Attached Devices
    
    /// Derived from: Lockdown
    var isLockedDown = false
    
    /// Derived from: HelperState
    var userIsActive = false
    
    /// Derived from: General Config
    private var buttonKillSwitch = false
    private var scrollKillSwitch = false
    
    //
    // MARK: Debug
    //
    
    @inline(__always) private func logWithState(_ message: @autoclosure () -> String) {
        
        /// Note: [Mar 2025] This only has to be so complicated because our threading architecture is really bad. Once we move all input and SwitchMaster to GlobalEventTapThread.m, this won't be necessary.
        if (runningPreRelease()) {
            let invocationId = Int.random(in: 0...99999);
            DDLogDebug("[\(invocationId)] SwitchMaster: \(message())")
            ModifiedDrag.activationState { modifiedDragActivation in /// Note: [Mar 2025] This won't be necessary once we use GlobalEventTapThread.m
                DDLogDebug("[\(invocationId)] SwitchMaster: EventTap state - kbMod: \(Modifiers.kbModPriority().rawValue), btnMod: \(Modifiers.btnModPriority().rawValue), button: \(ButtonInputReceiver.isRunning() ? 1 : 0), scroll: \(Scroll.isReceiving() ? 1 : 0), pointing: \(modifiedDragActivation.rawValue)")
                DDLogDebug("[\(invocationId)] SwitchMaster: MenuItem state - buttonMenu: \(MenuBarItem.buttonsItemIsEnabled() ? 1 : 0), scrollMenu: \(MenuBarItem.scrollItemIsEnabled() ? 1 : 0)")
                DDLogDebug("[\(invocationId)] SwitchMaster: Internal state -\n\(SharedUtilitySwift.dumpSwiftIvars(self))");
            }
        }
    }
    
    //
    // MARK: Init
    //
    
    @objc func load_Manual() {
        
        /// Notes:
        /// - [Mar 2025] During app startup SwitchMaster seems to called a bazillion times before being initialized. That's inefficent (and might even lead to corrupted state?)
        ///     - Solution idea 1: Make `.shared` optional and create the singleton instance inside `load_Manual`
        ///         ... However that might cause SwitchMaster to miss important state-updates during startup. We'd have to manually fill in all the initial state inside `load_Manual`. A proper reactive system would be able to do this automatically, but with our system it'd be difficult to maintain. (Sidenote: IIRC, we initially implemented this in ReactiveSwift but moved to manual function calls because it was too slow.)
        ///     - Solution idea 2: Alternatively we could simply remove `load_Manual` and have the place that previously called it init HelperState instead.
        ///         -> This should ensure correct behavior more easily than if we only start recording any state after `load_Manual`. While SwitchMaster might be called a few times during startup before it starts turning on any taps, it's pretty optimized and made to be called all the time, so actually shouldn't be a problem.
        
        /// Force HelperState to init so that it updates `userIsActive`
        ///     Might be better to just directly assign `userIsActive` here instead of this indirect stuff.
        _ = HelperState.shared
        
        /// Not sure this is necessary or useful
        ///     Update [Mar 2025] Still not totally sure. But I don't think it's necessary. The managers of all the state we're setting here should give SwitchMaster a callback when the state is initialized or when it changes. If the managers do that, then this shouldn't be necessary.
        latestDevices = DeviceManager.attachedDevices
        latestRemaps = Remap.remaps
        latestScrollConfig = ScrollConfig.shared
        latestModifiers = Modifiers.modifiers(with: nil)
        
        /// Debug
        logWithState("Initialized.")
    }
    
    //
    // MARK: Lockdown
    //
    

    @objc func lockDown() {
        
        /// Update state
        isLockedDown = true
        
        /// Call togglers
        /// Notes:
        /// - Calling`toggleBtnModProcessing()` is unnecessary since we already turn off all button inputs in  `toggleButtonTap()`
        /// - Not sure if we need to call `togglePointingTap(modifications:)`
        
        toggleKbModTap()
        if false { toggleBtnModProcessing() } /// [Mar 2025] Why aren't we calling this?
        
        toggleScrollTap()
        toggleButtonTap()
        togglePointingTap(modifications: nil)
        
        toggleKillSwitchMenuItems()
        
        /// Debug
        logWithState("Toggled due to lockdown.")
    }
    
    //
    // MARK: Fast user switching
    //
    
    @objc func helperStateChanged() {
        
        /// NOTES:
        /// - On listening to activeDevice
        ///     - This would let us turn off buttonTap / scrollTap for mice that don't support buttons / don't support scrolling. However then we couldn't update the active device when another mouse sends scroll or button input because we wouldn't be listening to that input. So it's better to just listen to all attachedDevices.
        
        let userIsActiveNew = HelperState.shared.userIsActive
        
        if userIsActiveNew != userIsActive {
            
            /// Update State
            userIsActive = userIsActiveNew
            
            /// Call togglers
            
            toggleKbModTap()
            if false { toggleBtnModProcessing() }
            /// ^ [Mar 2025] Why aren't we calling this?
            /// Note: [Mar 2025] After adding a `if isLockedDown || !userIsActive` guard inside toggleBtnModProcessing(), Click and Drag doesn't work right after enabling MMF.
            ///     This can be fixed by calling toggleBtnModProcessing() here.
            ///     This strongly vindicates the idea that toggleBtnModProcessing() is correct to call here, and that it's only working now due to luck.
            ///     TODO: call toggleBtnModProcessing() here and in all the other places where we're missing it.
            
            toggleScrollTap()
            toggleButtonTap()
            togglePointingTap(modifications: nil)
            
            /// Debug
            logWithState("""
                Toggled due to helperState change.
                New state - userIsActive: \(userIsActiveNew)
                """)
        }
    }
    
    //
    // MARK: Kill switches
    //
    
    @objc func generalConfigChanged(generalConfig: NSDictionary) {
        
        /// Get raw
        let btn = generalConfig.object(forKey: "buttonKillSwitch") as! Bool
        let scrl = generalConfig.object(forKey: "scrollKillSwitch") as! Bool
        
        /// Update state & set didChange
        
        var didChange = false
        
        if btn != buttonKillSwitch {
            buttonKillSwitch = btn
            didChange = true
        }
        if scrl != scrollKillSwitch {
            scrollKillSwitch = scrl
            didChange = true
        }
        
        if didChange {
            
            /// Call togglers
            
            toggleKbModTap()
            if false { toggleBtnModProcessing() } /// [Mar 2025] Why aren't we calling this?
            
            toggleScrollTap()
            toggleButtonTap()
            togglePointingTap(modifications: nil)
            
            /// Debug
            logWithState("""
                Toggled due to killSwitch change.
                New state - btn: \(btn), scrl: \(scrl)
                """)
        }
    }
    
    //
    // MARK: Base callbacks
    //
    
    private var latestDevices = NSArray()
    @objc func attachedDevicesChanged(devices: NSArray) {
        
        /// Update state
        self.someDeviceHasScroll = DeviceManager.someDeviceHasScrollWheel()
        self.someDeviceHasPointing = DeviceManager.someDeviceHasPointing()
        self.someDeviceHasUsableButtons = DeviceManager.someDeviceHasUsableButtons()
        self.maxButtonNumberAmongDevices = DeviceManager.maxButtonNumberAmongDevices()
        
        /// Call combined state updaters
        remapsOrAttachedDevicesChanged(remaps: latestRemaps, devices: devices)
        remapsOrModifiersOrAttachedDevicesChanged(remaps: latestRemaps, modifiers: latestModifiers, attachedDevices: devices)
        
        /// Store latest
        latestDevices = devices
        
        /// Call togglers
        
        self.toggleKbModTap()
        self.toggleBtnModProcessing()
        
        self.toggleScrollTap()
        self.toggleButtonTap()
        self.togglePointingTap(modifications: nil)
        
        toggleKillSwitchMenuItems()
        
        /// Debug
        logWithState("""
            Toggled due to attachedDevices change.
            New devices: \(devices)
            """)
        
    }
    
    private var latestRemaps = NSDictionary()
    @objc func remapsChanged(remaps: NSDictionary) {
        
        /// Update state
        let result = self.modifierUsage_Point_Scroll(remaps)
        self.somekbModModifiesPointing = result.someKbModModifiesPointing
        self.somekbModModifiesScroll = result.someKbModModifiesScroll
        self.someButtonModifiesPointing = result.someButtonModifiesPointing
        self.someButtonModifiesScroll = result.someButtonModifiesScroll
        
        /// Call combined state updaters
        remapsOrAttachedDevicesChanged(remaps: remaps, devices: latestDevices)
        remapsOrModifiersChanged(remaps: remaps, modifiers: latestModifiers)
        remapsOrModifiersOrAttachedDevicesChanged(remaps: remaps, modifiers: latestModifiers, attachedDevices: latestDevices)
        
        /// Store latest
        latestRemaps = remaps
        
        /// Call togglers
        /// Notes:
        /// - On not calling togglePointingTap():
        ///     - Would be a hack
        ///     - We want to do this because it prevents an issue where after recording a click and drag in the addField it immediately activates.
        ///     - I'm not totally sure this won't lead to other issues in edge cases though, so we'll find another solution:
        ///         - sol1: Only conclude addMode drag when the user lets go of the button - Works but makes things less responsive
        ///         - sol2:Make modifiedDrag ignore reinitialization while addModeDrag is active
        ///     - Update: [2025] IIRC we fixed this problem another way. Should update these comments.
        /// - On passing in self.latestModifications into togglePointingTap():
        ///     -  I'm not 100% sure self.latestModifications is always up-to-date here (what if the new remaps should enable modifier tracking but those modifiers aren't in self.latestModifications, yet?). Since this is not performance-critical it's better to just pass in nil, so that `togglePointingTap()` gets the values fresh.
        
        self.toggleKbModTap()
        self.toggleBtnModProcessing()
        
        self.toggleScrollTap()
        self.toggleButtonTap()
        self.togglePointingTap(modifications: nil /*self.latestModifications*/)
        
        toggleKillSwitchMenuItems()
        
        /// Debug
        logWithState("""
            Toggled due to remaps change.
            New remaps: \(remaps)
            """)
    }
    
    private var latestScrollConfig = ScrollConfig.shared /// Not sure if this is a good initialization value
    @objc func scrollConfigChanged(scrollConfig: ScrollConfig) {
        
        /// Update state
        if Remap.addModeIsEnabled {
            /// This doesn't work because scrollConfig doesn't change for addMode, so we don't get a callback. We instead solved this in `concludeAddModeWithPayload:`
            self.defaultModifiesScroll = false
        } else {
            self.defaultModifiesScroll = /*!scrollKillSwitch && */
                (scrollConfig.smoothEnabled || scrollConfig.u_speed != kMFScrollSpeedSystem || scrollConfig.u_invertDirection == kMFScrollInversionInverted)
        }
        
        /// Store latest
        latestScrollConfig = scrollConfig
        
        /// Call togglers
        ///     Note: [Mar 2025] Problem(?): Shouldn't we call toggleButtonTap() here, since we call toggleBtnModProcessing()
        ///         TODO: Call toggleButtonTap() here and in all other places we call toggleBtnModProcessing()
        
        self.toggleKbModTap()
        self.toggleBtnModProcessing()
        
        self.toggleScrollTap()
        
        toggleKillSwitchMenuItems()
        
        /// Debug
        logWithState("""
            Toggled due to scrollConfig change.
            New scrollConfig: \(scrollConfig)
            """)
    }
    
    private var latestModifiers = NSDictionary()
    @objc func modifiersChanged(modifiers: NSDictionary) {
        
        /// Call combined state updaters
        remapsOrModifiersChanged(remaps: latestRemaps, modifiers: modifiers)
        remapsOrModifiersOrAttachedDevicesChanged(remaps: latestRemaps, modifiers: modifiers, attachedDevices: latestDevices)
        
        /// Store latest
        latestModifiers = modifiers
        
        /// Call togglers
        ///     Note: [Mar 2025] Why we aren't toggling btn/kbd mods here? -> I think because if we listened to mods conditionally based on presence of other mods, then only a specific order of activating the mods would work.
        
        self.toggleScrollTap()
        self.toggleButtonTap()
        self.togglePointingTap(modifications: self.latestModifications)
        
        /// Debug
        logWithState("""
            Toggled due to modifier change.
            New modifiers: \(modifiers)
            """)
    }
    
    //
    // MARK: Combined state updaters
    //
    
    private func remapsOrAttachedDevicesChanged(remaps: NSDictionary, devices: NSArray) {
        
        /// Note: [Mar 2025] Why not use `self.maxButtonNumberAmongDevices` here instead of calling `DeviceManager.maxButtonNumberAmongDevices()`? Pretty sure that's would be correct.
        ///     TODO: use self.maxButtonNumberAmongDevices here and in all other places where `DeviceManager.maxButtonNumberAmongDevices()` is used (Maybe think it through again before.)
        let maxButton = DeviceManager.maxButtonNumberAmongDevices()
        let result = self.modifierUsage_Buttons(remaps, maxButton: maxButton)
        self.somekbModModifiesButtonOnSomeDevice = result.somekbModModifiesButtonOnSomeDevice
        self.someButtonModifiesButtonOnSomeDevice = result.someButtonModifiesButtonOnSomeDevice
        
        self.defaultModifiesButtonOnSomeDevice = self.defaultModifiesButtonOnSomeDevice(remaps, maxButton: maxButton)
    }
    
    private var latestModifications: NSDictionary? = nil
    private func remapsOrModifiersChanged(remaps: NSDictionary, modifiers: NSDictionary) {
        
        /// Derive modifications
        let modifications = Remap.modifications(withModifiers: modifiers)
        
        /// Update state
        if let m = modifications {
            self.currentModificationModifiesScroll = RemapsAnalyzer.modificationsModifyScroll(m)
            self.currentModificationModifiesPointing = RemapsAnalyzer.modificationsModifyPointing(m)
        } else {
            self.currentModificationModifiesScroll = false
            self.currentModificationModifiesPointing = false
        }
        
        /// Store latest
        latestModifications = modifications
    }
    
    private func remapsOrModifiersOrAttachedDevicesChanged(remaps: NSDictionary, modifiers: NSDictionary, attachedDevices: NSArray) {
        
        /// NOTE: Not totally sure using `latestModifications` always works here. Make sure you call `remapsOrModifiersChanged` before this so `latestModifications` is updated first
        ///     Update: [Mar 2025] Current understanding: When attached devices change, this is called without first calling remapsOrModifiersChanged() (and therefore, without updating latestModifications). But I think that's ok since attached devices really don't affect latestModifications. (This would no longer be true if we introduce device-specific settings.)
        
        /// Update state
        if let m = latestModifications {
            self.currentModificationModifiesButtonOnSomeDevice = RemapsAnalyzer.modificationsModifyButtons(m, maxButton: DeviceManager.maxButtonNumberAmongDevices())
        } else {
            self.currentModificationModifiesButtonOnSomeDevice = false
        }

    }
    
    //
    // MARK: Tap togglers
    //
    
    private func toggleKbModTap() {
        
        if isLockedDown || !userIsActive {
            Modifiers.setKeyboardModifierPriority(kMFModifierPriorityUnused)
            return
        }
        
        var priority = kMFModifierPriorityUnused
        
        let someKbModReallyModifiesScroll   = somekbModModifiesScroll             && someDeviceHasScroll          && !scrollKillSwitch
        let someKbModReallyModifiesPointing = somekbModModifiesPointing           && someDeviceHasPointing        && true
        let someKbModReallyModifiesButtons  = somekbModModifiesButtonOnSomeDevice && someDeviceHasUsableButtons   && !buttonKillSwitch
        
        if someKbModReallyModifiesScroll || someKbModReallyModifiesPointing || someKbModReallyModifiesButtons {
            
            let someKbModsToggleScroll      = someKbModReallyModifiesScroll     && !defaultModifiesScroll               ;
            let someKbModsTogglePointing    = someKbModReallyModifiesPointing   && !defaultModifiesPointing             ;
            let someKbModsToggleButtons     = someKbModReallyModifiesButtons    && !defaultModifiesButtonOnSomeDevice   ;
            
            if someKbModsToggleScroll || someKbModsTogglePointing || someKbModsToggleButtons {
                priority = kMFModifierPriorityActiveListen
            } else {
                priority = kMFModifierPriorityPassiveUse
            }
        }
        
        Modifiers.setKeyboardModifierPriority(priority)
    }
    
    private func toggleBtnModProcessing() {
        
        /// TODO [Mar 2025]:
        ///     Add a `if isLockedDown || !userIsActive` guard here like for all the other togglers
        
        var priority = kMFModifierPriorityUnused
        
        let someBtnReallyModifiesScroll      = someButtonModifiesScroll             && someDeviceHasScroll        && !scrollKillSwitch      ;
        let someBtnReallyModifiesPointing    = someButtonModifiesPointing           && someDeviceHasPointing      && true                   ;
        let someBtnReallyModifiesButtons     = someButtonModifiesButtonOnSomeDevice && someDeviceHasUsableButtons && !buttonKillSwitch      ; /// `!buttonKillSwitch` is redundant here ([Mar 2025]: Why?), but makes it more readable? || [Mar 2025]: someDeviceHasUsableButtons might also be redundant, because someButtonModifiesButtonOnSomeDevice might already capture that.
        
        if someBtnReallyModifiesScroll || someBtnReallyModifiesPointing || someBtnReallyModifiesButtons {
            
            let someBtnModsToggleScroll     = someBtnReallyModifiesScroll   && !defaultModifiesScroll            ;
            let someBtnModsTogglePointing   = someBtnReallyModifiesPointing && !defaultModifiesPointing          ;
            let someBtnModsToggleButtons    = someBtnReallyModifiesButtons  && !defaultModifiesButtonOnSomeDevice;
            
            if someBtnModsToggleScroll || someBtnModsTogglePointing || someBtnModsToggleButtons {
                priority = kMFModifierPriorityActiveListen
            } else {
                priority = kMFModifierPriorityPassiveUse
            }
        }
        
        Modifiers.setButtonModifierPriority(priority)
    }
    
    private func toggleScrollTap() {
        
        if isLockedDown || !userIsActive || scrollKillSwitch {
            Scroll.stopReceiving()
            return
        }
        
        if someDeviceHasScroll && (defaultModifiesScroll || currentModificationModifiesScroll) {
            Scroll.startReceiving()
        } else {
            Scroll.stopReceiving()
        }
    }
    
    private func toggleButtonTap() {
    
        if isLockedDown || !userIsActive || buttonKillSwitch {
            ButtonInputReceiver.stop()
            return
        }
        
        /// Notes:
        ///     - [Mar 2025] We should perhaps reuse the 'areButtonsModifiers?' logic from toggleBtnModProcessing(), instead of this duplicate (and outdated - we're missing `!scrollKillSwitch`) logic.
        ///         -> TODO: Reuse updated logic from toggleBtnModProcessing()
        ///     - [Mar 2025] We should probably always call toggleButtonTap() after toggleBtnModProcessing() - so the tap is actually toggled in case this switches buttonModProcessing to/away from kMFModifierPriorityActiveListen
        let buttonsAreUsedAsModifiers =
            (someDeviceHasScroll        && someButtonModifiesScroll)                ||
            (someDeviceHasPointing      && someButtonModifiesPointing)              ||
            (someDeviceHasUsableButtons && someButtonModifiesButtonOnSomeDevice)
        
        if someDeviceHasUsableButtons && (currentModificationModifiesButtonOnSomeDevice || buttonsAreUsedAsModifiers) {
            
            ButtonInputReceiver.start()
        } else {
            ButtonInputReceiver.stop()
        }
    }
    
    private func togglePointingTap(modifications modificationsArg: NSDictionary?) {
        
        if isLockedDown || !userIsActive { /// Not sure if necessary
            ModifiedDrag.deactivate()
            return
        }
        
        /// Determine enable
        let enable = someDeviceHasPointing && currentModificationModifiesPointing
        
        if enable {
            
            /// Get modifications
            /// - Maybe we should store the "latestModifications" as an instance var for optimzation && to keep things clean? Aside from this we're only using instance vars in the tapTogglers, I feel like maybe there's is some architectural idea for why we only need to use instance vars.
            /// - Update: [Mar 2025] We do store the 'latestModifications' as an instance var now. Should we use it here? 
            let modifications: NSDictionary?
            
            if modificationsArg != nil {
                modifications = modificationsArg
            } else {
                modifications = Remap.modifications(withModifiers: Modifiers.modifiers(with: nil))
            }
            
            /// Initialize ModifiedDrag
            if let dragEffect = modifications?.object(forKey: kMFTriggerDrag) as! NSDictionary? {
                ModifiedDrag.initializeDrag(withDict: dragEffect)
            } else {
                /// I've seen this happening. I'll just ignore it. Should be fine. Could maybe prevent this is we store a local copy of the `latestModifications` so the "Update State" code and the "Tap toggling" code work with the exact same data and there can't be race conditions that cause situations like this.
//                assert(false)
            }
        } else {
            ModifiedDrag.deactivate()
        }
    }
    
    private func toggleKillSwitchMenuItems() {
        
        /// Disabling this, because I think it's not really clear to users what graying out the items means or when it happens.
        
        /// Note: [Mar 2025] We're never disabling the items (I think) – so why enable them here instead of just returning?
        /// Note: [Mar 2025] If we ever enable this code again, we should perhaps add a `if isLockedDown || !userIsActive` guard here like for all the other togglers.
        
        MenuBarItem.enableScrollItem(true)
        MenuBarItem.enableButtonsItem(true)
        
        if ((false)) {
            
            let scrollCanBeToggled =
            !isLockedDown && someDeviceHasScroll &&
            (defaultModifiesScroll || somekbModModifiesScroll || someButtonModifiesScroll)
            
            let buttonsCanBeToggled =
            !isLockedDown &&
            (defaultModifiesButtonOnSomeDevice || somekbModModifiesButtonOnSomeDevice || someButtonModifiesButtonOnSomeDevice)
            
            MenuBarItem.enableScrollItem(scrollCanBeToggled)
            MenuBarItem.enableButtonsItem(buttonsCanBeToggled)
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
    ///  EDIT: I moved the modifications analysis into RemapsAnalyzer. ObjC did speed things up a bit. Caching did not speed things up in my testing.
    
    /// Modifications analysis
    
//    func modificationModifiesButtons(modification: NSDictionary?, maxButton: Int32) -> Bool {
//        
//        /// Return true if the modification modifies any button `<=` maxButton
//        
//        if let modification = modification {
//            
//            for element in modification {
//                
//                guard let btn = element.key as? NSNumber else { continue }
//                
//                let doesModify = btn.int32Value <= maxButton
//                if doesModify { return true }
//            }
//        }
//        
//        return false
//    }
    
//    fileprivate func modificationModifiesScroll(_ modification: NSDictionary?) -> Bool {
//        return modification?.object(forKey: kMFTriggerScroll) != nil
//    }
//    
//    fileprivate func modificationModifiesPointing(_ modification: NSDictionary?) -> Bool {
//        return modification?.object(forKey: kMFTriggerDrag) != nil
//    }
    
    
    /// Remaps analysis
    
    fileprivate func modifierUsage_Buttons(_ remaps: NSDictionary?, maxButton: Int32) -> (somekbModModifiesButtonOnSomeDevice: Bool,
                                                                                          someButtonModifiesButtonOnSomeDevice: Bool) {
        
        var kbModSways = false
        var btnSways = false
        
        if Remap.addModeIsEnabled {
            kbModSways = true
            btnSways = true
        } else {
            
            remaps?.enumerateKeysAndObjects(options: [/*.concurrent*/]) { modifiers, modifications, stop in
                
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
                        var doesModify = false
                        if let m = modifications as? NSDictionary {
                            doesModify = RemapsAnalyzer.modificationsModifyButtons(m, maxButton: maxButton)
                        }
                        if doesModify {
                            if !kbModSways { kbModSways = keyboard }
                            if !btnSways { btnSways = button }
                        }
                    }
                }
                
                if kbModSways && btnSways {
                    stop.pointee = ObjCBool.init(true)
                }
            }
        }
        
        return (somekbModModifiesButtonOnSomeDevice: kbModSways, someButtonModifiesButtonOnSomeDevice: btnSways)
    }
    
    fileprivate func defaultModifiesButtonOnSomeDevice(_ remaps: NSDictionary, maxButton: Int32) -> Bool {
        
        var defaultSways = false
        
        let empty = NSDictionary()
        if let defaultModification = remaps.object(forKey: empty) as? NSDictionary {
            defaultSways = RemapsAnalyzer.modificationsModifyButtons(defaultModification, maxButton: maxButton)
        }
        
        return defaultSways
    }
    
    fileprivate func modifierUsage_Point_Scroll(_ remaps: NSDictionary) -> (someKbModModifiesPointing: Bool, someKbModModifiesScroll: Bool, someButtonModifiesPointing: Bool, someButtonModifiesScroll: Bool) {
        
        var kbSwayPoint = false
        var kbSwayScroll = false
        var btnSwayPoint = false
        var btnSwayScroll = false
        
        if Remap.addModeIsEnabled {
            
            /// On setting `kbSwayPoint` and `kbSwayScroll` to false:
            /// Setting kbMod stuff to false because we don't allow recording scroll and drag triggers  in addMode without a button as a modifier.
            ///     Just setting this stuff to false should prevent this but it's not semantic because `someKbModModifiesPointing` and `someKbModModifiesScroll` (which we're setting false here) are technically true. Probably a better way to implement the "there needs to be a button" restriction in `concludeAddModeWithPayload:`.
            ///     Edit: Implemented the stuff in `concludeAddModeWithPayload:` so this should be unnecessary, but it also shouldn't hurt.
            
            kbSwayPoint = false
            kbSwayScroll = false
            btnSwayPoint = true
            btnSwayScroll = true
            
        } else {
            
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
                        var point = false
                        if let m = modification as? NSDictionary {
                            point = RemapsAnalyzer.modificationsModifyPointing(m)
                        }
                        if !btnSwayPoint { btnSwayPoint = button && point }
                        if !kbSwayPoint { kbSwayPoint = keyboard && point }
                    }
                    if (!kbSwayScroll && keyboard) || (!btnSwayScroll && button) {
                        var scroll = false
                        if let m = modification as? NSDictionary {
                            scroll = RemapsAnalyzer.modificationsModifyScroll(m)
                        }
                        if !btnSwayScroll { btnSwayScroll = button && scroll }
                        if !kbSwayScroll { kbSwayScroll = keyboard && scroll }
                    }
                }
                
                if kbSwayScroll && kbSwayPoint && btnSwayScroll && btnSwayPoint {
                    stop.pointee = ObjCBool.init(true)
                }
            }
        }
        
        return (someKbModModifiesPointing: kbSwayPoint, someKbModModifiesScroll: kbSwayScroll, someButtonModifiesPointing: btnSwayPoint, someButtonModifiesScroll: btnSwayScroll)
    }
}

// MARK: - Old Reactive Swift Stuff
/// We moved away from ReactiveSwift because it was too slow

//@objc func load_Manual() {
    
    /// Get signals
    
//        let attachedDevicesSignal = ReactiveDeviceManager.shared.attachedDevices
//        let remapsSignal = ReactiveRemaps.shared.remaps
//        let scrollConfigSignal = ReactiveScrollConfig.shared.scrollConfig
//        let modifiersSignal = ReactiveModifiers.shared.modifiers
    
    // MARK: Update state
    
    /// Attached Devices Signal
    
//        attachedDevicesSignal.startWithValues { devices in
//            self.someDeviceHasScroll = DeviceManager.someDeviceHasScrollWheel()
//            self.someDeviceHasPointing = DeviceManager.someDeviceHasPointing()
//            self.someDeviceHasUsableButtons = DeviceManager.someDeviceHasUsableButtons()
//            self.maxButtonNumberAmongDevices = DeviceManager.maxButtonNumberAmongDevices()
//        }
    
    /// Remaps Signal
    
//        remapsSignal.startWithValues { remaps in
//
//            let result = self.modifierUsage_Point_Scroll(remaps)
//
//            self.somekbModModifiesPointing = result.someKbModModifiesPointing
//            self.somekbModModifiesScroll = result.someKbModModifiesScroll
//            self.someButtonModifiesPointing = result.someButtonModifiesPointing
//            self.someButtonModifiesScroll = result.someButtonModifiesScroll
//        }
    
    /// Remaps & Attached Devices Signal
    
//        remapsSignal.combineLatest(with: attachedDevicesSignal).startWithValues { (remaps, attachedDevices) in
//
//            let maxButton = DeviceManager.maxButtonNumberAmongDevices()
//            let result = self.modifierUsage_Buttons(remaps, maxButton: maxButton)
//            self.somekbModModifiesButtonOnSomeDevice = result.somekbModModifiesButtonOnSomeDevice
//            self.someButtonModifiesButtonOnSomeDevice = result.someButtonModifiesButtonOnSomeDevice
//
//            self.defaultModifiesButtonOnSomeDevice = self.defaultModifiesButtonOnSomeDevice(remaps, maxButton: maxButton)
//        }
    
    /// Scroll Config Signal
    
//        scrollConfigSignal.startWithValues { scrollConfig in
//
//            if Remap.addModeIsEnabled {
//                /// This doesn't work because scrollConfig doesn't change for addMode, so we don't get a callback. We instead solved this in `concludeAddModeWithPayload:`
//                self.defaultModifiesScroll = false
//            } else {
//                self.defaultModifiesScroll = !scrollConfig.killSwitch &&
//                (scrollConfig.u_smoothEnabled || scrollConfig.u_speed != "system" || scrollConfig.u_invertDirection == kMFScrollInversionInverted)
//            }
//
//        }
    
    /// Remaps & Modifiers Signal
    ///  NOTE: The callbacks are called whenever the modifiers change so they need to be fast!
    
//        let modificationsSignal = remapsSignal.combineLatest(with: modifiersSignal).map { (remaps, modifiers) in
//            let modifications = Remap.modifications(withModifiers: modifiers)
//            self.latestModifications = modifications
//            return modifications
//        }
    
//        modificationsSignal.startWithValues { modifications in
//            self.currentModificationModifiesScroll = self.modificationModifiesScroll(modifications)
//            self.currentModificationModifiesPointing = self.modificationModifiesPointing(modifications)
//        }
    
    /// Remaps & Modifiers & Attached Devices Signal
    
//        modificationsSignal.combineLatest(with: attachedDevicesSignal).startWithValues { (modifications, attachedDevices) in
//            self.currentModificationModifiesButtonOnSomeDevice = self.modificationModifiesButtons(modification: modifications, maxButton: DeviceManager.maxButtonNumberAmongDevices())
//        }
    
    // MARK: Call tap togglers
    
//        attachedDevicesSignal.startWithValues { _ in
//
//            DDLogDebug("SwitchMaster toggling due to attachedDevices change")
//
//            self.toggleKbModTap()
//            self.toggleBtnModProcessing()
//
//            self.toggleScrollTap()
//            self.toggleButtonTap()
//            self.togglePointingTap(modifications: nil)
//        }
//        remapsSignal.startWithValues { _ in
//
//            DDLogDebug("SwitchMaster toggling due to remaps change")
//
//            self.toggleKbModTap()
//            self.toggleBtnModProcessing()
//
//            self.toggleScrollTap()
//            self.toggleButtonTap()
//
//            /// On not toggling pointing tap
//            /// - Would be a hack
//            /// - We want to do this because it prevents an issue where after recording a click and drag in the addField it immediately activates.
//            /// - I'm not totally sure this won't lead to other issues in edge cases though, so we'll find another solution:
//            ///     - sol1: Only conclude addMode drag when the user lets go of the button - Works but makes things less responsive
//            ///     - sol2:Make modifiedDrag ignore reinitialization while addModeDrag is active
//            /// - On passing in self.latestModifications:
//            ///  -  I'm not 100% sure self.latestModifications is always up-to-date here (what if the new remaps should enable modifier tracking but those modifiers aren't in self.latestModifications, yet?). Since this is not performance-critical it's better to just pass in nil, so that `togglePointingTap()` gets the values fresh.
//            self.togglePointingTap(modifications: nil /*self.latestModifications*/)
//        }
//        scrollConfigSignal.startWithValues { _ in
//
//            DDLogDebug("SwitchMaster toggling due to scroll config change")
//
//            self.toggleKbModTap()
//            self.toggleBtnModProcessing()
//
//            self.toggleScrollTap()
//        }

//        modifiersSignal.startWithValues { _ in
//
//            DDLogDebug("SwitchMaster toggling due to modifier change")
//
//            self.toggleScrollTap()
//            self.toggleButtonTap()
//            self.togglePointingTap(modifications: self.latestModifications)
//        }
    
//        if runningPreRelease() {
//            SignalProducer<Any, Never>.merge(attachedDevicesSignal.map { $0 as Any }, remapsSignal.map { $0 as Any }, scrollConfigSignal.map { $0 as Any }, modifiersSignal.map { $0 as Any }).startWithValues { _ in
//
//                ModifiedDrag.activationState { modifiedDragActivation in
//
//                    DDLogDebug("SwitchMaster switched to - kbMod: \(Modifiers.kbModPriority().rawValue), btnMod: \(Modifiers.btnModPriority().rawValue), button: \(ButtonInputReceiver.isRunning() ? 1 : 0), scroll: \(Scroll.isRunning() ? 1 : 0), pointing: \(modifiedDragActivation.rawValue)")
//                }
//            }
//        }
//}
