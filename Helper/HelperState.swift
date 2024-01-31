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
    
    // MARK: ConfigOverrideConditions
    
    func configOverrideConditions() -> NSDictionary {
        
        var result = NSDictionary()
        
        /// Update/retrieve the relevant state
            
        /// Encode the state as strings and numbers and stuff (instead of objects) (This format is the same as what will be stored in the config.plist) (Storing strings and stuff should work better than using like a raw NSRunningApplication instance and stuff. The instance might die at some point but then still be retained as a cache key and shiii)
        /// NOTE: To get a unique id for a physical monitor, use CGDisplaySerialNumber() CGDisplayModelNumber(), and CGDisplayVendorNumber()
        /// NOTE: Cache this if it's slow? (What happens if we cache an NSRunningApplication instance and it dies? Clean the cache periodically?)
        
        /// Return
        return result
        
    }
    
    // MARK: State - Display under mouse pointer

    @objc func displayUnderMousePointer(event: CGEvent?) -> CGDirectDisplayID {
        let mouseLocation = getPointerLocationWithEvent(event);
        return self.display(atPoint: mouseLocation)
    }

    @objc func display(atPoint point: CGPoint) -> CGDirectDisplayID {
        
        /// Notes:
        /// - TODO: This is called from lots of places. Make sure it's fast!
        /// - TODO: Adopt similar caching/optimizations to `appUnderMousePointer()`
        
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
    
    private var lastAppUnderMousePointer: NSRunningApplication? = nil
    
    private var AUMLastFrontmostApp: NSRunningApplication? = nil
    private var AUMLastTimestamp: CFTimeInterval? = nil
    private var AUMLastCGLoc: NSPoint? = nil
    
    @objc func appUnderMousePointer(event: CGEvent?) -> NSRunningApplication? {
        
        /// Notes:
        /// - Before the `CGWindow` approach, we used the AXUI API. Inspired by MOS' approach. However, `AXUIElementCopyElementAtPosition()` was incredibly slow sometimes. At one time I saw it taking a second to return when scrolling on new Reddit in Safari on M1 Ventura Beta. On other windows and websites it's not noticably slow but still very slow in code terms.
        
        /// 
        /// See if we can use cache
        ///  Notes:
        ///  - This weird structure with the function is for optimization. goto statements would be much cleaner but Swift is stinky
        ///  - I'm not sure the current logic makes sense. One thing I can think of is what if the user moves their mouse quickly, but the app doesn't update because of the `cacheTimeMin`? Do the values for cacheTimeMin and cacheTimeMax makes sense? I think tracking the frontmostApp here doesn't necessarily make sense, I think it's just an approximation for window order. To be logically perfect, we should be checking if window order and window position has changed, but that's probably slow and unnecessary. Is this caching stuff necessary at all? Does it even bring a significant speedup?
        ///  TODO: I think about when these AUM values are updated and if it makes sense.
        ///
        
        var now: CFTimeInterval? = nil
        var timeElapsed: CFTimeInterval? = nil
        var pointerLocCG: CGPoint? = nil
        var frontmostApp: NSRunningApplication? = nil
        
        if ((false)) { /// Disable this optimization stuff for now - TODO: try to get it working first and then optimize.
            
            let cacheTimeMin = 0.1 /// If less than this many seconds passed then we *always* use the cache
            let cacheTimeMax = 5.0 /// If more than this many seconds passed, then we *never* use the cache
            
            func useCache() -> Bool {
                
                if lastAppUnderMousePointer == nil { return false }
                
                now = CACurrentMediaTime()
                timeElapsed = now! - (AUMLastTimestamp ?? 0.0)
                
                if timeElapsed! < cacheTimeMin { return true }
                
                if cacheTimeMax < timeElapsed! { return false }
                
                pointerLocCG = getPointerLocationWithEvent(event)
                let pointerMoved = pointsAreEqual(p1: pointerLocCG!, p2: AUMLastCGLoc ?? CGPoint(), threshold: 10.0)
                
                if pointerMoved { return false }
                
                let frontmostAppMightHaveChanged: Bool
                if frontmostAppPriority == .unused {
                    frontmostAppMightHaveChanged = true
                } else { /// Note: Does it ever make sense to force-update the frontmost app here for optimization?
                    frontmostApp = self.frontmostApp
                    frontmostAppMightHaveChanged = AUMLastFrontmostApp != frontmostApp
                }
                
                if frontmostAppMightHaveChanged { return false }
                
                return true
            }
            
            
            let useCache = useCache()
            
            if useCache {
                return lastAppUnderMousePointer!
            }
            
            /// Update 'last' state
            
            AUMLastCGLoc = pointerLocCG ?? AUMLastCGLoc
            AUMLastTimestamp = now ?? AUMLastTimestamp
            AUMLastFrontmostApp = frontmostApp ?? AUMLastFrontmostApp
        }
        
        ///
        /// Calculate appUnderMousePointer fresh
        ///
        
        /// Get PID under mouse pointer
        
        var pidUnderPointer: pid_t? = nil
        
        if pointerLocCG == nil {
            pointerLocCG = getPointerLocationWithEvent(event)
        }
        let pointerLoc: NSPoint = SharedUtility.quartz(toCocoaScreenSpace_Point: pointerLocCG!)
        
        let windowNumber = CGWindowID(NSWindow.windowNumber(at: pointerLoc, belowWindowWithWindowNumber: 0))
        let windowInfo = CGWindowListCopyWindowInfo(.optionIncludingWindow, windowNumber) as NSArray?
        if let i = windowInfo, i.count > 0, let j = i[0] as? NSDictionary, let pid = j[kCGWindowOwnerPID] as? pid_t {
            pidUnderPointer = pid
        }
        
        /// Get runningApplication
        let appUnderMousePointer = pidUnderPointer == nil ? nil : NSRunningApplication(processIdentifier: pidUnderPointer!)
        
        /// Update state
        lastAppUnderMousePointer = appUnderMousePointer
        
        /// Return
        return appUnderMousePointer
        
    }
    
    // MARK: State - Frontmost app
    
    private var frontmostAppObserver: NSObjectProtocol? = nil
    private var _frontmostAppPriority: MFStatePriority = .unused
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
                    
                    /// Store new frontmost app
                    
                    let newFrontmostApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                    if let app = newFrontmostApp, let s = self {
                        s._frontmostApp = app
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
    
    private var _frontmostApp: NSRunningApplication? = nil
    var frontmostApp: NSRunningApplication? {
        get {
            if let result = _frontmostApp { return result }
            let fallback = NSWorkspace.shared.frontmostApplication
            _frontmostApp = fallback
            return fallback
        }
    }
    func updateFrontmostApp(event: CGEvent) {
        
        /// Retrieve the frontmost app from a CGEvent, and store the result in a local variable
        /// Notes:
        /// - `.eventTargetUnixProcessID` seems to be how linearMouse gets the frontmost app. I'm not 100% sure this works reliably to get the frontmost app
        /// - I'm not totally sure it's necessary/good to have a separate interface for updating the frontMost app vs retrieving it, instead of combining them into one function.
        /// - If the update function is called more frequently than the retrieval function, we might want to optimize the update function, by only getting and storing the pid, and then only creating the NSRunningApplication instance in the retrieval function. You could call this 'lazy loading' the NSRunningApplication instance?
        
        /// Guard priority (for optimization)
        if frontmostAppPriority == .unused || frontmostAppPriority == .activeListen { return }
        
        /// Update value
        let pid = Int32(event.getIntegerValueField(.eventTargetUnixProcessID))
        updateFrontmostApp(pid: pid)
    }
    func updateFrontmostApp(pid: pid_t) {
        
        /// Guard priority (for optimization)
        if frontmostAppPriority == .unused || frontmostAppPriority == .activeListen { return }
        
        /// Update value
        /// Note: In case creating an `NSRunningApplication` instance is slow, we could cache a map from pid -> runningApplication globally for the app. Then getting the frontMost app given a CGEvent should be lightning fast!
        _frontmostApp = NSRunningApplication(processIdentifier: pid)
    }
    
    // MARK: State - Active device
    
    private var _activeDevice: Device? = nil
    @objc var activeDevice: Device? {
        set {
            _activeDevice = newValue
            SwitchMaster.shared.helperStateChanged()
        }
        get {
            if _activeDevice != nil {
                return _activeDevice
            } else { /// Just return any attached device as a fallback
                /// NOTE: Swift let me do `attachedDevices.first` (even thought that's not defined on NSArray) without a compiler warning which did return a Device? but the as! Device? cast still crashed. Using `attachedDevices.firstObject` it doesn't crash.
                return DeviceManager.attachedDevices.firstObject as! Device?
            }
        }
    }
    
    @objc func updateActiveDevice(event: CGEvent) {
        guard let iohidDevice = CGEventGetSendingDevice(event)?.takeUnretainedValue() else { return }
        updateActiveDevice(IOHIDDevice: iohidDevice)
    }
    @objc func updateActiveDevice(eventSenderID: UInt64) {
        guard let iohidDevice = getSendingDeviceWithSenderID(eventSenderID)?.takeUnretainedValue() else { return }
        updateActiveDevice(IOHIDDevice: iohidDevice)
    }
    @objc func updateActiveDevice(IOHIDDevice: IOHIDDevice) {
        guard let device = DeviceManager.attachedDevice(with: IOHIDDevice) else { return }
        activeDevice = device
    }
    
    // MARK: State - Logged-in account
    /// See Apple Docs at: https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPMultipleUsers/Concepts/FastUserSwitching.html#//apple_ref/doc/uid/20002209-104219-BAJJIFCB
    
    var userIsActive: Bool = false
    func initUserIsActive() {
        
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
    
    // MARK: Helper stuff (TODO: Move this somewhere else)
    
    func pointsAreEqual(p1: CGPoint, p2: CGPoint, threshold th: Double) -> Bool {
        
        let isDifferent = abs(p2.x - p1.x) > th || abs(p2.y - p1.y) > th
        return !isDifferent
    }
}
