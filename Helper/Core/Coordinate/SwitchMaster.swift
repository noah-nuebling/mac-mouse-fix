//
// --------------------------------------------------------------------------
// SwitchMaster.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Foundation
import CoreGraphics

private let eventType_KeyboardModifier: MFEventType = MFEventType(kMFEventType_KeyboardModifier)
private let eventType_KeyPress: MFEventType         = MFEventType(kMFEventType_KeyPress)
private let eventType_Sensor: MFEventType           = MFEventType(kMFEventType_Sensor)
private let eventType_ScrollWheel: MFEventType      = MFEventType(kMFEventType_ScrollWheel)
private let eventType_AllButtons: MFEventType       = MFEventType(kMFEventType_AllButtons)

@objc public final class SwitchMaster: NSObject {

    fileprivate struct State {
        var latestGeneralConfig: NSDictionary? = nil
        var latestDevices: NSArray? = nil
        var latestRemaps: NSDictionary? = nil
        var latestScrollConfig: ScrollConfig? = nil
        var latestModifiers: NSDictionary? = nil
        
        var isLockedDown: Bool = false
        var userIsActive: Bool = true
        var addModeIsEnabled: Bool = false
        
        var eventsKilledBySwitch: MFEventType = 0
        var eventsSupportedBySomeDevice: MFEventType = 0
        var eventsModifiedByDefault: MFEventType = 0
        
        // Map from modified event bit index (0..63) -> modifying events mask
        var eventToModifyingEventsMap = [MFEventType](repeating: 0, count: 64)
        
        var lastTapScrollEvents: MFEventType = 0
        var lastTappedButtonEvents: MFEventType = 0
        var lastTapPointerEvents: MFEventType = 0
        var lastActiveEvents: MFEventType = 0
        var lastPassiveEvents: MFEventType = 0
        var lastDragEffect: NSDictionary? = nil
    }

    fileprivate static func performOnIOThread(_ work: @escaping () -> Void) {
        let ioRL = IOThread.runLoop()
        if CFEqual(CFRunLoopGetCurrent(), ioRL) {
            work()
        } else {
            mfrun(ioRL, work)
        }
    }

    fileprivate static var state: State? = nil

    @objc public static func load_Manual() {
        performOnIOThread {
            state = State()

            _ = HelperState.shared

            state?.latestDevices = DeviceManager.attachedDevices() as NSArray
            state?.latestRemaps = Remap.remaps
            state?.latestScrollConfig = ScrollConfig.defaultInstance
            state?.latestModifiers = Modifiers.modifiers(with: nil)
            state?.eventsSupportedBySomeDevice = DeviceManager.eventTypesSupportedBySomeDevice()

            DDLogInfo("SwitchMaster: Initialized (Native Swift).")
        }
    }

    @objc public static func lockDown() {
        performOnIOThread {
            guard var s = state else { return }
            s.isLockedDown = true
            state = s

            if processChangedState() {
                DDLogInfo("SwitchMaster: Toggled due to lockdown.")
            }
        }
    }

    @objc public static func helperStateChanged() {
        performOnIOThread {
            guard var s = state else { return }
            s.userIsActive = HelperState.shared.userIsActive
            state = s

            if processChangedState() {
                DDLogInfo("SwitchMaster: Toggled due to helperState change. userIsActive: \(s.userIsActive)")
            }
        }
    }

    @objc public static func generalConfigChanged(_ generalConfig: NSDictionary) {
        performOnIOThread {
            guard var s = state else { return }
            s.latestGeneralConfig = generalConfig

            var killed: MFEventType = 0
            if let btnKill = generalConfig["buttonKillSwitch"] as? Bool, btnKill {
                killed |= eventType_AllButtons
            }
            if let scrollKill = generalConfig["scrollKillSwitch"] as? Bool, scrollKill {
                killed |= eventType_ScrollWheel
            }
            s.eventsKilledBySwitch = killed
            state = s

            if processChangedState() {
                DDLogInfo("SwitchMaster: Toggled due to killSwitch change.")
            }
        }
    }

    @objc public static func attachedDevicesChanged(_ devices: NSArray) {
        performOnIOThread {
            guard var s = state else { return }
            s.latestDevices = devices
            s.eventsSupportedBySomeDevice = DeviceManager.eventTypesSupportedBySomeDevice()
            state = s

            if processChangedState() {
                DDLogInfo("SwitchMaster: Toggled due to attachedDevices change. Device count: \(devices.count)")
            }
        }
    }

    @objc public static func remapsChanged(_ remaps: NSDictionary) {
        performOnIOThread {
            guard var s = state else { return }
            s.latestRemaps = remaps
            s.addModeIsEnabled = Remap.addModeIsEnabled

            // Rebuild map from modified event index -> modifying events mask
            s.eventToModifyingEventsMap = [MFEventType](repeating: 0, count: 64)
            remaps.enumerateKeysAndObjects { modifiersKey, modificationsValue, _ in
                guard let modifiers = modifiersKey as? NSDictionary,
                      let modifications = modificationsValue as? NSDictionary else { return }
                let modifyingEvents = RemapsAnalyzer.eventsInModifiers(modifiers)
                if modifyingEvents != 0 {
                    let modifiedEvents = RemapsAnalyzer.eventsModifiedByModifications(modifications)
                    var m = modifiedEvents
                    while m != 0 {
                        let lastBit = m & (~m + 1)
                        let index = lastBit.trailingZeroBitCount
                        if index >= 0 && index < 64 {
                            s.eventToModifyingEventsMap[index] |= modifyingEvents
                        }
                        m &= (m - 1)
                    }
                }
            }

            let eventsModifiedByDefault = RemapsAnalyzer.eventsModifiedByModifications(Remap.modifications(withModifiers: [:]))
            mfassert(eventsModifiedByDefault & eventType_Sensor == 0, "MMF never wants to intercept Pointer events without a modifier held.")
            s.eventsModifiedByDefault = (s.eventsModifiedByDefault & eventType_ScrollWheel) | eventsModifiedByDefault
            state = s

            if processChangedState() {
                DDLogInfo("SwitchMaster: Toggled due to remaps change.")
            }
        }
    }

    @objc static func scrollConfigChanged(_ scrollConfig: ScrollConfig) {
        performOnIOThread {
            guard var s = state else { return }
            s.latestScrollConfig = scrollConfig

            let scrollModifiedByDefault = scrollConfig.smoothEnabled ||
                                          scrollConfig.u_speed != kMFScrollSpeedSystem ||
                                          scrollConfig.u_invertDirection == kMFScrollInversionInverted

            if !scrollModifiedByDefault {
                s.eventsModifiedByDefault &= ~eventType_ScrollWheel
            } else {
                s.eventsModifiedByDefault |= eventType_ScrollWheel
            }
            state = s

            if processChangedState() {
                DDLogInfo("SwitchMaster: Toggled due to scrollConfig change.")
            }
        }
    }

    @objc public static func modifiersChanged(_ modifiers: NSDictionary) {
        performOnIOThread {
            guard var s = state else { return }
            s.latestModifiers = modifiers
            state = s

            if processChangedState() {
                DDLogInfo("SwitchMaster: Toggled due to modifier change.")
            }
        }
    }

    @discardableResult
    fileprivate static func processChangedState() -> Bool {
        assertRunLoop(IOThread.runLoop())
        guard var s = state else { return false }

        var toggled = false

        let modifications = Remap.modifications(withModifiers: s.latestModifiers ?? [:])
        let eventsModifiedCurrently = RemapsAnalyzer.eventsModifiedByModifications(modifications) |
                                      (s.eventsModifiedByDefault & eventType_ScrollWheel)

        let baseModifiableEvents = s.eventsSupportedBySomeDevice &
                                   ~s.eventsKilledBySwitch &
                                   ~MFEventType_ButtonBlacklist()

        var eventsActivelyModifyingCurrently: MFEventType = 0
        var eventsPassivelyModifyingCurrently: MFEventType = 0

        if s.isLockedDown || !s.userIsActive {
            eventsActivelyModifyingCurrently = 0
            eventsPassivelyModifyingCurrently = 0
        } else if s.addModeIsEnabled {
            eventsActivelyModifyingCurrently = (eventType_AllButtons | eventType_KeyboardModifier)
            eventsPassivelyModifyingCurrently = 0
        } else {
            func eventsModifyingEvents(_ modifiedEvents: MFEventType) -> MFEventType {
                var modifying: MFEventType = 0
                var m = modifiedEvents
                while m != 0 {
                    let lastBit = m & (~m + 1)
                    let index = lastBit.trailingZeroBitCount
                    if index >= 0 && index < 64 {
                        modifying |= s.eventToModifyingEventsMap[index]
                    }
                    m &= (m - 1)
                }
                return modifying
            }

            let modifyingEvents = eventsModifyingEvents(baseModifiableEvents)
            eventsActivelyModifyingCurrently = eventsModifyingEvents(baseModifiableEvents & ~s.eventsModifiedByDefault)
            eventsPassivelyModifyingCurrently = modifyingEvents & ~eventsActivelyModifyingCurrently
        }

        eventsActivelyModifyingCurrently &= ~MFEventType_ButtonBlacklist()
        eventsPassivelyModifyingCurrently &= ~MFEventType_ButtonBlacklist()

        if s.lastActiveEvents != eventsActivelyModifyingCurrently || s.lastPassiveEvents != eventsPassivelyModifyingCurrently {
            Modifiers.setModifierPriorityWithActiveListenEvents(eventsActivelyModifyingCurrently, passiveUseEvents: eventsPassivelyModifyingCurrently)
            s.lastActiveEvents = eventsActivelyModifyingCurrently
            s.lastPassiveEvents = eventsPassivelyModifyingCurrently
            toggled = true
        }

        var eventsToListenTo: MFEventType = 0
        if !s.isLockedDown && s.userIsActive {
            eventsToListenTo = eventsModifiedCurrently
            eventsToListenTo |= (eventsActivelyModifyingCurrently | eventsPassivelyModifyingCurrently) & eventType_AllButtons
            eventsToListenTo &= baseModifiableEvents
        }

        let tapScrollEvents = (eventsToListenTo & eventType_ScrollWheel) != 0
        let tappedButtonEvents = eventsToListenTo & eventType_AllButtons
        let tapPointerEvents = (eventsToListenTo & eventType_Sensor) != 0

        let tapScrollMask: MFEventType = tapScrollEvents ? eventType_ScrollWheel : 0
        if s.lastTapScrollEvents != tapScrollMask {
            if tapScrollEvents {
                Scroll.startReceiving()
            } else {
                Scroll.stopReceiving()
            }
            toggled = true
        }

        if s.lastTappedButtonEvents != tappedButtonEvents {
            ButtonInputReceiver.listen(toButtons: tappedButtonEvents)
            toggled = true
        }

        if !tapPointerEvents && s.lastTapPointerEvents != 0 {
            ModifiedDrag.deactivate(withCancel: false)
            s.lastDragEffect = nil
            toggled = true
        } else if tapPointerEvents {
            let dragEffect = modifications?[kMFTriggerDrag] as? NSDictionary
            if let dragEffect = dragEffect {
                if s.lastDragEffect == nil || !dragEffect.isEqual(s.lastDragEffect) {
                    ModifiedDrag.initializeDrag(withDict: dragEffect)
                    s.lastDragEffect = dragEffect
                }
            }
            if s.lastTapPointerEvents == 0 {
                toggled = true
            }
        }

        s.lastTapScrollEvents = tapScrollMask
        s.lastTappedButtonEvents = tappedButtonEvents
        s.lastTapPointerEvents = tapPointerEvents ? eventType_Sensor : 0

        state = s
        return toggled
    }
}

// MARK: - C Export Callbacks for Objective-C Callers

@_cdecl("SwitchMaster_Load_Manual")
func _SwitchMaster_Load_Manual() {
    SwitchMaster.load_Manual()
}

@_cdecl("SwitchMaster_LockDown")
func _SwitchMaster_LockDown() {
    SwitchMaster.lockDown()
}

@_cdecl("SwitchMaster_HelperStateChanged")
func _SwitchMaster_HelperStateChanged() {
    SwitchMaster.helperStateChanged()
}

@_cdecl("SwitchMaster_GeneralConfigChanged")
func _SwitchMaster_GeneralConfigChanged(_ generalConfig: NSDictionary) {
    SwitchMaster.generalConfigChanged(generalConfig)
}

@_cdecl("SwitchMaster_AttachedDevicesChanged")
func _SwitchMaster_AttachedDevicesChanged(_ devices: NSArray) {
    SwitchMaster.attachedDevicesChanged(devices)
}

@_cdecl("SwitchMaster_RemapsChanged")
func _SwitchMaster_RemapsChanged(_ remaps: NSDictionary) {
    SwitchMaster.remapsChanged(remaps)
}

@_cdecl("SwitchMaster_ScrollConfigChanged")
func _SwitchMaster_ScrollConfigChanged(_ scrollConfig: ScrollConfig) {
    SwitchMaster.scrollConfigChanged(scrollConfig)
}

@_cdecl("SwitchMaster_ModifiersChanged")
func _SwitchMaster_ModifiersChanged(_ modifiers: NSDictionary) {
    SwitchMaster.modifiersChanged(modifiers)
}
