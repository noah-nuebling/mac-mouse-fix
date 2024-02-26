//
// --------------------------------------------------------------------------
// HelperState.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/**
 
 This class can track / retrieve `ExternalState`, such as the app under the mouse pointer, or the currently used device. It will also be able to _actively_ track some State, if the SwitchMaster decides that it needs to.
 A subset of these `ExternalState` variables will be used to apply overrides to the config. These are called the `ConfigOverrideConditions` (Or sometimes just `Conditions`)
 
 This class will provide interfaces to update and retrieve the current `ExternalState`.
 It will also provide an interface to retrieve all of the `ConfigOverrideConditions` in a dictionary. (So that the conditions can be used as a cache key in the config overriding code and stuff.)
    
 TODO: Notify SwitchMaster whenever the state changes.
        - We're already calling SwitchMaster.shared.helperStateChanged() in some places but it's inconsistent and not thought-through at the moment
 TODO?: Maybe rename this class to 'ExternalState' or sth else instead of 'HelperState' (Don't forget to update all the references in comments and stuff.)
 
 __Broader context__
 
 We plan to build a system to apply __settings-overrides when specific conditions are true__. `Conditions` could be such things as using a specific app, or a specific device or a monitor, or a custom "profile".
 I think this settings-overrides system will be somehow 'homomorphic' (is that the right term?) to the remapping system. I think the `ConfigOverrideConditions` dictionary in the settings-override system will be the analog of the modifier dictionary retrieved from the `Modifier` class in the Remap system.
 
 The Remap system and the ConfigOverride system are __similar__ because in both we plan to:
 
 - Have a dictionary that defines how the system should behave (config dict vs remaps dict)
 - Track conditions (/modifiers)
 - The conditions/modifiers map to overrides for the config/remaps dictionary. These overrides are smartly compiled together based on how well the conditions/modifiers match the current state (maybe we could call this 'specificity'?) as well as based on the 'priority' of each condition/modifier. (Maybe other factors? Idk but it's really smart and the idea for the algorithm is the same for both the Remap system and the ConfigOverride system)
 - Every time we retrieve the config/remaps, we need to pass in the conditions/modifiers so that the config/remaps can be compiled appropriately. We plan to store the conditions/modifiers in a dict and use that as a cache key to speed this up.
 - Some conditions/modifiers need to be actively listened to in certain situations, in order to dynamically decide when to actively listen to other signals (e.g. mouse-moved events). This is for optimization. In order to implement this, we introduce the concept of `MFStatePriority`/`MFModifierPriority`. This priority is set by the `SwitchMaster`.
 
 Now let's explore the __fundamental differences__ that I can see right now between the two systems: ('right now' is before actually building the ConfigOverride system)
 
 - The `Modifiers` are physical buttons on input devices that the user holds down. While the `Conditions` are more like the state of the computer.
        (Conditions are e.g. which app is under the mouse pointer, which device currently is being used, or if the user has activated a 'gaming profile or something.)
 -  Because of this, the UI to define overrides for `Modifiers` vs the UI to define overrides for `Conditions` has to be different. For the `Modifiers`, the user can just hold down a modifier to specifiy that they want something to happen when that modfier is held. But to specify that they want something to happen when certain `Conditions` are true is not that simple. To implement that, we plan to make it so that the user can specify the conditions beforehand, and then we change the whole state of the UI to be editing the settings for the case that those specific conditions are true.
 - Because of this plan for the UI of the `Conditions`-based overrides, it seems appropriate, that (almost) ALL settings can be customized based on `Conditions`. But that only certain settings can be customized based on modifiers. (Those settings with specialized UI elements that show the modifiers directly).
 - So these differences between `Conditions` and the `Modifiers` when it comes to the UI and to which settings/behaviours can be affected, make it so the implementation also should be separate in many places. For example they should be separate in the structure of the config file, since the config file is a pretty direct representation of the UI. Another thing I can think of is any code in the helper which wants to retrieve some settings from the Config aside from the `Remaps` (so I mean those settings that can only be affected by `Conditions` and not by `Modifiers`) shouldn't be forced to pass in modifiers to retrieve the settings. It would potentially be inefficient not to leverage our knowledge about which settings can be affected by modifiers, and which can only be affected by conditions. So I think we should probably keep the implementations for the `Remaps` and the `Conditions` stuff largely separate. But we should keep an eye out for places where we can share some ideas or share some code. Disclaimer: I haven't really started to implement the `Conditions` stuff, yet, but this is so far my best idea of how things will work out.
 
 
 */

import Foundation
import CoreGraphics
import CocoaLumberjackSwift

@objc class HelperState: NSObject {
    
    // MARK: Datastructure
    
    enum MFStatePriority {
        
        /// This is the analog of the `MFModifierPriority` enum
        case unused
        case passiveUse
        case activeListen
    }
    
    // MARK: Singleton & init
    @objc static let shared = HelperState()
    override init() {
        super.init()
        initUserIsActive()
        DispatchQueue.main.async { /// Need to do this to avoid strange Swift crashes when this is triggered from `SwitchMaster.load_Manual()`
            SwitchMaster.shared.helperStateChanged()
        }
    }
    
    // MARK: Base values
    
    /// Notes:
    /// - The base values are the information provided to HelperState from the outside.
    /// - Most of the information which HelperState provides *to* the outside is  lazily _derived_ from these base values.
    
    private var latestSenderID: UInt64? = nil
    private var latestFrontmostAppPID: pid_t? = nil
    private var latestPointerLocation: CGPoint? = nil
    
    @objc func updateBaseValue_SenderID(_ senderID: UInt64) {
        latestSenderID = senderID
    }
    
    @objc func updateBaseValues(event: CGEvent) {
        
        /// Update senderID
        let newSenderID = CGEventGetSenderID(event)
        latestSenderID = newSenderID
        
        /// Update pointerLocation
        let newPointerLocation = getPointerLocationWithEvent(event)
        latestPointerLocation = newPointerLocation
        
        /// Update frontmostAppPID
        ///     Notes:
        ///     - `.eventTargetUnixProcessID` seems to be how linearMouse gets the frontmost app. I'm not 100% sure this works reliably to get the frontmost app
        ///     - We used to check that `frontmostAppPriority == .passiveUse` here before assigning the new value, but I don't think that makes sense.
        ///         - First off: I'm certain this is incredibly fast and we don't really need to optimize at all. An if statement is probably about as heavy as assigning the value. Still, it's definitely unnecessary to set the value if `frontmostAppPriority != .activeListen`.
        ///         - Secondly: Even if `frontmostAppPriority == .unused`, the `latestFrontmostAppPID` is still used to optimize derivation of the appUnderMousePointer. If the appUnderMousePointer is *also* unused, then it would make sense to not store the `latestFrontmostAppPID` here. But we're not currently tracking if the appUnderMousePointer is used, and either way - this is totally not worth optimizing.
        
        if frontmostAppPriority != .activeListen {
            let newFrontmostAppPID = pid_t(event.getIntegerValueField(.eventTargetUnixProcessID))
            latestFrontmostAppPID = newFrontmostAppPID
        }
    }
           
    // MARK: State - ConfigOverrideConditions
    
    var _configOverrideConditions: NSMutableDictionary = [:]
    @objc public var configOverrideConditions: NSDictionary {
        
        /// Update/retrieve the relevant state
            
        /// Notes:
        /// - On serialization:
        ///     - Explanation:
        ///         - The state that HelperState provides which we would like to use as `_configOverrideConditions` has serialized representations.
        ///         - We store serialized representation of the state inside the `_configOverrideConfitions` dict.
        ///         - The serialized state lets us identify mice, monitors, apps, and more across restarts of the computer. This serialized format is the same as what will be stored in the config.plist as configOverrideConditions.
        ///     - Todo:
        ///         - Consider speed: At time of writing, we're always serializing the derived state and storing that inside `_configOverrideConditions` whenever the derived state changes. Maybe we should serialize lazily & with caching to speed things up? Also we're currently serializing displays even though we don't plan to support display-specific settings soon. We should probably turn that off.
        ///             - Update: No I've considered this and these things have completely negligible performance impact. Everythings already so lazy that the serializations aren't often recalculated and and also serialization is super fast.
        /// - On activeProfile:
        ///     -  activeProfile is logically part of the configOverrideConditions, but the current plan is that it would just be a string value we read straight from the config. So I'm not totally sure it makes sense to include here, since when we calculate the configOverrides inside the Config class we might have more efficient and direct ways to read the activeProfile from the configDict. Also, we probably won't support profiles in the UI in the near future.
        
        /// Update values
        deriveActiveDevice()
        deriveFrontmostApp()
        deriveAppUnderMousePointer()
        deriveDisplayUnderMousePointer()
        deriveActiveProfile()
        
        /// Return
        return _configOverrideConditions
        
    }
    
    // MARK: State - Display under mouse pointer
    
    @objc var displayUnderMousePointer: CGDirectDisplayID {
        get {
            deriveDisplayUnderMousePointer()
            return _displayUnderMousePointer
        }
    }
    
    /// Base value cache
    private var latestPointerLocation_CacheForDisplayUnderMousePointer: CGPoint? = nil
    
    /// Derived value
    private var _displayUnderMousePointer: CGDirectDisplayID = kCGNullDirectDisplay
    
    private func deriveDisplayUnderMousePointer() {
        
        /// This method looks at  baseValues (e.g. latestPointerLocation) and derives the the displayUnderMousePointer from that. It tries to to as little work as possible.
        /// Notes:
        /// - Maybe build logic to update even if the base values haven't changed - if there was a display reconfiguration/if the displayID is invalid or sth. Could use CGDisplayIsActive() or CGDisplayIsOnline()
        
        /// Guard base value changed
        guard !pointerLocsAreEqual(latestPointerLocation, latestPointerLocation_CacheForDisplayUnderMousePointer) else { return }
        
        /// Update base value cache
        latestPointerLocation_CacheForDisplayUnderMousePointer = latestPointerLocation
        
        /// Unwrap
        guard let loc = latestPointerLocation else { return }
        
        /// Get display
        let newDisplay = getDisplayUnderMousePointer(withPoint: loc)
        
        /// Check displayIsValid
        guard newDisplay != kCGNullDirectDisplay && Bool(CGDisplayIsActive(newDisplay)) /* && Bool(CGDisplayIsOnline(newDisplay)) */ else { return }
        
        /// NOTE: Should we have a fallback here?
        
        /// Check change
        guard newDisplay != _displayUnderMousePointer else { return }
        
        /// Update derived value
        _displayUnderMousePointer = newDisplay
        
        /// Update the serializable representation
        ///     Notes:
        ///     - To get a unique id for a physical monitor, we're combining the vendorID, modelID and serialNumber. Using the serialNumber might be overkill. But maybe if ppl have the same monitor model at work or at home, this could be nice for monitor-specific settings.
        ///     - At the time of writing, we're not using this serialization since we don't have monitor-specific settings. But the performance impact of this is completely negligible. So it doesn't matter.
        let serialization = NSString(format: "%u-%u-%u", CGDisplayVendorNumber(_displayUnderMousePointer), CGDisplayModelNumber(_displayUnderMousePointer), CGDisplaySerialNumber(_displayUnderMousePointer))
        _configOverrideConditions[kConfigOverrideConditionKeyDisplayUnderMousePointer] = serialization
    }
    
    private func getDisplayUnderMousePointer(withPoint point: CGPoint) -> CGDirectDisplayID {
        
        /// Get display
        var newDisplaysUnderMousePointer = [CGDirectDisplayID](repeating: 0, count: 1)
        var matchingDisplayCount: UInt32 = 0
        let maxDisplays: UInt32 = 1
        let cgError = CGGetDisplaysWithPoint(point, maxDisplays, &newDisplaysUnderMousePointer, &matchingDisplayCount)
        
        if matchingDisplayCount == 1 {
            
            /// Get the master display in case newDisplaysUnderMousePointer[0] is part of a mirror set
            let displayID = CGDisplayPrimaryDisplay(newDisplaysUnderMousePointer[0])
            
            if (cgError != CGError.success) {
                DDLogInfo("Found display under mouse pointer with id \(displayID), despite CGGetDisplaysWithPoint returning error \(cgError)")
            }
            
            /// Success output
            return displayID
            
        } else if matchingDisplayCount == 0 {
            
            /// Failure output
        
            DDLogWarn("There are 0 displays under the mouse pointer. CGError: \(cgError)")
            return kCGNullDirectDisplay
            
        } else {
            /// This should never ever happen
            assert(false)
            return kCGNullDirectDisplay
        }
    }
    
    // MARK: State - App under mouse pointer
    
    @objc var appUnderMousePointer: NSRunningApplication? {
        get {
            deriveAppUnderMousePointer()
            return _appUnderMousePointer
        }
    }
    
    /// Base value caches
    private var latestPointerLocation_CacheForAppUnderMousePointer: CGPoint? = nil
    private var latestFrontmostAppPID_CacheForAppUnderMousePointer: pid_t? = nil
    
    /// Derived values
    private var pidUnderMousePointer: pid_t? = nil
    private var _appUnderMousePointer: NSRunningApplication? = nil
    
    private func deriveAppUnderMousePointer() {
        
        /// Notes:
        /// - Optimization
        ///     - So far, of all the info that the HelperState class provides, this seems to be by far the slowest to calculate. I tried everything I could think of to optimize it.
        ///     - Thoughts on optimization before we implemented it:
        ///         - We can skip updates if the pointer hasn't moved and the frontmost window hasn't changed.
        ///             - To check frontMost window, we could could use CGWindowList with `kCGWindowListOptionOnScreenAboveWindow`. We could also use accessibility api or use ScriptingBridge to communicate with the SystemEvents service to get this info.
        ///             - As a substitute/approximation for the frontMost window changes, we could also just check for frontMost app changes. That should also be good enough.
        ///             - I'm not sure how we can best retrieve and store and track this info. frontMost app is probably the fastest and easiest since the incoming cgEvents seem to contain that.
        ///                 - > Ended up just using the frontMost app. This should work perfectly in all scenarios I can think of except in some edge cases when using a windowSwitcher app that doesn't require you to move your mouse to switch between windows of a single app (e.g. alt-tab) but it's good enough for now.
        ///         - We also thought about having a cacheMin and cacheMax time which we use to determine if the cache should be reused or is outdated and should be recalculated, but I think that's quite ugly and probably not necessary. Update: Implemented things now and this wouldn't really speed things up in practical scenarios I can think of.
        
        ///
        /// Debug
        ///
        
//        let invocationTS = CACurrentMediaTime()
//        
//        if runningPreRelease() {
//            DDLogDebug("HelperState - deriving appUnderMousePointer - timeSince last derivation: \(invocationTS - latestDerivationTimeStamp_ForAppUnderMousePointer)")
//            DDLogDebug("HelperState - deriving appUnderMousePointer with frontmostApp: \(String(describing: latestFrontmostAppPID)), pointerLoc: \(String(describing: latestPointerLocation))")
//        }
//        defer {
//            if runningPreRelease() {
//                DDLogDebug("HelperState - derived new appUnderMousePointer: \(String(describing: _appUnderMousePointer)) in \((CACurrentMediaTime() - invocationTS)*1000)ms")
//            }
//        }
        
        /// Guard base values changed:
        /// - Do nothing if frontmostApp and pointerLocation are the same
        /// - Note: Can this lead to subtle issues if the frontmostAppPID isn't updated properly? At the time of writing, the frontmostAppPID and the pointerLocation are always updated together since they come from the CGEvents that are provided to this class as inputs. So far, it seems to be working well.
        guard
            latestFrontmostAppPID != latestFrontmostAppPID_CacheForAppUnderMousePointer
                || !pointerLocsAreEqual(latestPointerLocation, latestPointerLocation_CacheForAppUnderMousePointer)
        else {
            return
        }
        
        /// Update base value caches
        latestPointerLocation_CacheForAppUnderMousePointer = latestPointerLocation
        latestFrontmostAppPID_CacheForAppUnderMousePointer = latestFrontmostAppPID
        
        /// Unwrap
        guard let loc = latestPointerLocation else { return }
        
        /// Get pid
        guard let pid = getPIDUnderMousePointer(loc: loc) else { return }
        
        /// Get pid using C implementation (seems slower)
//        let pid = getPIDUnderMousePointerObjC(loc)
//        guard pid != kMFInvalidPID else { return }
        
        /// Check pid change
        guard pid != pidUnderMousePointer else { return }
        
        /// Update derived value
        pidUnderMousePointer = pid
        
        /// Get app
        guard let app = AppUtility.shared.getRunningAppFast(withPID: pid) else { return }
        
        /// NOTE: Should we have a fallback here?
        ///         We have a fallback for frontmost app - can we rely on that? Should HelperState provide fallbacks at all? Maybe the client code should get the fallbacks if it really needs them? Idk.
        
        /// Check change
        ///     Update: I thought this is unnecessary since we're already checking for changes in the pid - which is a unique identifier of the app - but performance seems to be worse?
        guard app != _appUnderMousePointer else { return }
        
        /// Update derived value
        _appUnderMousePointer = app
        
        /// Update serialized representation of derived value
        _configOverrideConditions[kConfigOverrideConditionKeyAppUnderMousePointer] = HelperStateObjC.serializeApp(app)
        
    }
    
    
    private func getPIDUnderMousePointer(loc pointerLocCG: CGPoint) -> pid_t? {
        
        ///
        /// Calculate appUnderMousePointer fresh
        ///
        
        /// Notes:
        /// - Before the `NSWindow` approach, we used the AXUI API. Inspired by MOS' approach. However, `AXUIElementCopyElementAtPosition()` was incredibly slow sometimes. At one time I saw it taking a second to return when scrolling on new Reddit in Safari on M1 Ventura Beta. On other windows and websites it's not noticably slow but still very slow in code terms. This approach seems to be much faster, although I haven't benchmarked it.
        /// - Should this be part of `AppUtility`? So far we're not using this outside of HelperState.
        
        
        var result: pid_t? = nil
        
        let pointerLoc: NSPoint = SharedUtility.quartz(toCocoaScreenSpace_Point: pointerLocCG)
        
        let windowNumber = CGWindowID(NSWindow.windowNumber(at: pointerLoc, belowWindowWithWindowNumber: 0))
        let windowInfo = CGWindowListCopyWindowInfo([.optionIncludingWindow], windowNumber) as NSArray? /// We tried CGWindowListCreateDescriptionFromArray but can't get that to work in swift
        if let i = windowInfo, i.count > 0, let j = i[0] as? NSDictionary, let pid = j[kCGWindowOwnerPID] as? pid_t {
            result = pid
        }
        
        return result
    }
    
    // MARK: State - Frontmost app
    
    @objc var frontmostApp: NSRunningApplication? {
        get {
            deriveFrontmostApp()
            return _frontmostApp!
        }
    }
    
    /// Base value cache
    private var latestFrontmostAppPID_CacheForFrontmostApp: pid_t? = nil
    
    /// Derived value
    private var _frontmostApp: NSRunningApplication? = nil
    
    private func deriveFrontmostApp() {
        
        /// Guard base value changed
        guard latestFrontmostAppPID != latestFrontmostAppPID_CacheForFrontmostApp else { return }
        
        /// Update base value cache
        latestFrontmostAppPID_CacheForFrontmostApp = latestFrontmostAppPID
        
        /// Optimize
        switch frontmostAppPriority {
        case .unused:
            return
        case .passiveUse:
            break
        case .activeListen:
            return
        }
        
        /// Unwrap
        guard let pid = latestFrontmostAppPID else { return }
        
        /// Get app
        var newApp = AppUtility.shared.getRunningAppFast(withPID: pid)
        
        if newApp == nil {
            
            /// Fallback
            newApp = NSWorkspace.shared.frontmostApplication
            
            /// Debug
            DDLogDebug("HelperState - Falling back to NSWorkspace.shared.frontmostApplication \(String(describing: newApp)) while deriving frontmost app from PID: \(pid)")
        }
        
        /// Unwrap app
        guard let newApp = newApp else { return }
        
        /// Check change
        ///     Update: I thought this is unnecessary since we're already checking if the pid changed - which is a unique identifier of the app - but performance seems to be worse?
        guard newApp != _frontmostApp else { return }
        
        /// Store main derived value
        _frontmostApp = newApp
        
        /// Store the serializable representation
        _configOverrideConditions[kConfigOverrideConditionKeyFrontmostApp] = HelperStateObjC.serializeApp(newApp)
    }
    
    /// FrontmostApp priority & activeObserver
    
    private var frontmostAppObserver: NSObjectProtocol? = nil
    private var _frontmostAppPriority: MFStatePriority = .passiveUse // .unused
    var frontmostAppPriority: MFStatePriority {
        
        get {
            return _frontmostAppPriority
        }
        set {
            /// Store priority
            _frontmostAppPriority = newValue
            
            if _frontmostAppPriority == .activeListen {
                
                /// Start observing
                ///
                /// Notes:
                /// - Should we also listen to other notifications except `didActivateApplicationNotification`? E.g. the deactivate notification?
                /// - Not totally sure if `[weak self]` is appropriate/necessary here
                
                frontmostAppObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: nil) {[weak self] notification in
                    
                    /// Unwrap
                    let newFrontmostApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                    if let app = newFrontmostApp, let s = self {
                        
                        /// Store new frontmost app
                        s._frontmostApp = app
                        
                        /// Get PID
                        let newPID = app.processIdentifier
                        
                        /// Update base value for derivation methods
                        s.latestFrontmostAppPID = newPID
                        
                        /// Update cache for frontmostApp derivation method - so it knows the `_frontmostApp` is already up to date and doesn't need to be derived again.
                        s.latestFrontmostAppPID_CacheForFrontmostApp = newPID
                        
                    } else {
                        assert(false)
                    }
                }
            } else {
                /// Stop observing
                if let observer = frontmostAppObserver {
                    NSWorkspace.shared.notificationCenter.removeObserver(observer)
                    frontmostAppObserver = nil
                }
            }
        }
        
    }
    
    // MARK: State - Active device
    
    @objc var activeDevice: Device? {
        get {
            deriveActiveDevice()
            return _activeDevice
        }
    }
    
    /// Base value cache
    private var latestSenderID_CacheForActiveDevice: uint64? = nil
    
    /// Derived value
    private var _activeDevice: Device? = nil
    
    private func deriveActiveDevice() {
        
        /// Guard base value changed
        guard latestSenderID != latestSenderID_CacheForActiveDevice else { return }
        
        /// Update base value cache
        latestSenderID_CacheForActiveDevice = latestSenderID
        
        /// Unwrap senderID
        guard let senderID = latestSenderID else { return }
        
        /// Check senderID
        guard senderID != kIOHIDEventSenderIDUndefined else { return }
        
        /// Get new active device
        var newDevice = getActiveDevice(eventSenderID: senderID)
        
        /// Fallback
        ///     Note: Swift let me do `attachedDevices.first` (even thought that's not defined on NSArray) without a compiler warning which did return a Device? but the as! Device? cast still crashed. Using `attachedDevices.firstObject` it doesn't crash.
        if newDevice == nil {
            newDevice = DeviceManager.attachedDevices.firstObject as! Device?
        }
        
        /// Unwrap device
        guard let newDevice = newDevice else { return }
        
        /// Check device has changed
        ///     Update: I think this is unnecessary to check, since we already checked if the senderID has changed - which is a unique identifier of the device - but performance seems to be worse?
        guard newDevice != _activeDevice else { return }
        
        /// Store main derived value
        _activeDevice = newDevice
        
        /// Store serialized representation
        ///     Notes:
        ///     - To get an id for the physical device, we're combining vendorID, productID and serialNumber. We're doing the same thing to serialize the displays.
        ///     - .serialNumber() is emptyString on my Roccat mouse. Maybe there's a different way to retrieve it?
        ///     - We tried to use newDevice.uniqueID(), but that isn't constant after a restart.
        let serialization = "\(newDevice.vendorID())-\(newDevice.productID())-\(newDevice.serialNumber())"
        _configOverrideConditions[kConfigOverrideConditionKeyActiveDevice] = serialization
        
        /// Notify switch master
        SwitchMaster.shared.helperStateChanged()
    }
    
    private func getActiveDevice(eventSenderID: UInt64) -> Device? {
        guard let iohidDevice = getSendingDeviceWithSenderID(eventSenderID)?.takeUnretainedValue() else { return nil }
        let result = getActiveDevice(IOHIDDevice: iohidDevice)
        return result
    }
    private func getActiveDevice(IOHIDDevice: IOHIDDevice) -> Device? {
        let device = DeviceManager.attachedDevice(with: IOHIDDevice)
        return device
    }
    
    // MARK: State - Active Profile
    
    @objc var activeProfile: NSString? {
        get {
            deriveActiveProfile()
            return _configOverrideConditions[kConfigOverrideConditionKeyActiveProfile] as! NSString?
        }
    }
    private func deriveActiveProfile() {
        /// We could store the active profile directly in the configOverrideConditions dict for optimization.
        return
        let result = config("Keypath.to.active.profile")
        _configOverrideConditions[kConfigOverrideConditionKeyActiveProfile] = result
    }
    
    // MARK: State - Logged-in account
    /// See Apple Docs at: https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPMultipleUsers/Concepts/FastUserSwitching.html#//apple_ref/doc/uid/20002209-104219-BAJJIFCB
    
    @objc private(set) var userIsActive: Bool = false
    
    private func initUserIsActive() {
        
        /// Init userIsActive
        userIsActive = userIsActive_Manual()
        
        /// Listen to user switches and update userIsActive
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil, queue: nil) { notification in
            self.userIsActive = true
            assert(self.userIsActive_Manual() == self.userIsActive)
            SwitchMaster.shared.helperStateChanged()
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: nil) { notification in
            self.userIsActive = false
            assert(self.userIsActive_Manual() == self.userIsActive)
            SwitchMaster.shared.helperStateChanged()
        }
        
    }
    
    private func userIsActive_Manual() -> Bool {
        /// For debugging and stuff
        guard let d = CGSessionCopyCurrentDictionary() as NSDictionary? else { return false }
        guard let result = d.value(forKey: kCGSessionOnConsoleKey) as? Bool else { return false }
        return result
    }
    
    // MARK: Helper stuff
    
    func pointerLocsAreEqual(_ p1: CGPoint?, _ p2: CGPoint?) -> Bool {
        pointsAreEqual(p1, p2, .mousePointerDefaultThreshold)
    }
    func pointsAreEqual(_ p1: CGPoint?, _ p2: CGPoint?, _ th: PointEqualityThreshold) -> Bool {

        /// TODO: Move this somewhere else
        
        if p1 == nil && p2 == nil { return true }
        if p1 == nil && p2 != nil
            || p1 != nil && p2 == nil { return false }
        
        let isDifferent = abs(p2!.x - p1!.x) > th.value || abs(p2!.y - p1!.y) > th.value
        return !isDifferent
    }
    struct PointEqualityThreshold {
        let value: Double
        static let mousePointerDefaultThreshold = PointEqualityThreshold(value: 10.0)
    }
}


