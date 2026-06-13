//
// --------------------------------------------------------------------------
// ModifiedDrag.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020 (Translated to Swift in 2026)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Foundation
import CoreGraphics
import Cocoa

/// Defines the activation state of modified drag
@objc(MFModifiedInputActivationState)
public enum ModifiedInputActivationState: UInt32 {
    case none = 0
    case initialized = 1
    case inUse = 2
}

/// A Swift representation of ModifiedDragState class to avoid C pointer arithmetic
class ModifiedDragState: NSObject {
    var eventTap: CFMachPort?
    var usageThreshold: Int64 = 7
    var effectDict: [AnyHashable: Any]?
    var naturalDirection: Bool = true
    var type: String?
    var outputPlugin: ModifiedDragOutputPlugin?
    var activationState: ModifiedInputActivationState = .none
    var initTime: CFTimeInterval = 0.0
    var isSuspended: Bool = false
    var origin: CGPoint = .zero
    var originOffset: Vector = Vector(x: 0, y: 0)
    var usageOrigin: CGPoint = .zero
    var usageAxis: MFAxis = kMFAxisNone
    var firstCallback: Bool = false
    var queue: DispatchQueue!
}

/// Swift protocol for ModifiedDrag Output Plugins
@objc
protocol ModifiedDragOutputPlugin: NSObjectProtocol {
    func initialize(with dragState: ModifiedDragState)
    func handleBecameInUse()
    func handleMouseInputWhileInUse(deltaX: Double, deltaY: Double, event: CGEvent?)
    func handleDeactivationWhileInUse(cancel: Bool)
    func suspend()
    func unsuspend()
}

@objc(ModifiedDrag)
public class ModifiedDrag: NSObject {
    
    // 内部全局静态状态，不直接向 ObjC 暴露属性
    static let _drag = ModifiedDragState()
    
    // 提供 ObjC 访问的 activationState callback API
    @objc public static func activationState(callback: @escaping (ModifiedInputActivationState) -> Void) {
        _drag.queue.async {
            callback(_drag.activationState)
        }
    }
    
    // 初始化与加载
    @objc public static func load_Manual() {
        ModifiedDragOutputTwoFingerSwipe.load_Manual()
        
        // 建立串口交互队列
        _drag.queue = DispatchQueue(label: "com.nuebling.mac-mouse-fix.helper.modified-drag", qos: .userInteractive)
        _drag.usageThreshold = 7
        
        if _drag.eventTap == nil {
            let location = CGEventTapLocation.cghidEventTap
            let placement = CGEventTapPlacement.headInsertEventTap
            let option = CGEventTapOptions.defaultTap
            
            var mask: CGEventMask = 0
            mask |= 1 << CGEventType.otherMouseDragged.rawValue
            mask |= 1 << CGEventType.mouseMoved.rawValue
            mask |= 1 << CGEventType.leftMouseDragged.rawValue
            mask |= 1 << CGEventType.rightMouseDragged.rawValue
            
            let runLoop = GlobalEventTapThread.runLoop().takeUnretainedValue()
            let eventTap = ModificationUtility.createEventTap(
                with: location,
                mask: mask,
                option: option,
                placement: placement,
                callback: eventTapCallBack,
                runLoop: runLoop
            )
            _drag.eventTap = eventTap.takeRetainedValue()
        }
    }
    
    @objc(initializeDragWithDict:)
    public static func initializeDrag(withDict effectDict: NSDictionary?) {
        guard let effectDict = effectDict else { return }
        _drag.queue.async {
            let effectDictSwift = effectDict as? [AnyHashable: Any] ?? [:]
            DDLogDebug("INITIALIZING MODIFIEDDRAG WITH previous type \(_drag.type ?? "nil") activationState \(_drag.activationState.rawValue), newEffectDict: \(effectDictSwift)")
            
            if _drag.activationState == .inUse {
                let isSame = effectDict.isEqual(to: _drag.effectDict ?? [:])
                let isAddMode = (_drag.effectDict?[kMFModifiedDragDictKeyType] as? String) == kMFModifiedDragTypeAddModeFeedback
                if !isSame && !isAddMode {
                    return
                } else {
                    return
                }
            }
            
            let type = effectDictSwift[kMFModifiedDragDictKeyType] as? String
            _drag.type = type
            _drag.effectDict = effectDictSwift
            _drag.initTime = CACurrentMediaTime()
            
            var p: ModifiedDragOutputPlugin?
            if type == kMFModifiedDragTypeThreeFingerSwipe {
                p = ModifiedDragOutputThreeFingerSwipe()
            } else if type == kMFModifiedDragTypeTwoFingerSwipe {
                p = ModifiedDragOutputTwoFingerSwipe()
            } else if type == kMFModifiedDragTypeFakeDrag {
                p = ModifiedDragOutputFakeDrag()
            } else if type == kMFModifiedDragTypeAddModeFeedback {
                p = ModifiedDragOutputAddMode()
            } else {
                assertionFailure("Unknown modified drag type: \(type ?? "nil")")
            }
            
            _drag.outputPlugin = p
            initDragState_Unsafe()
        }
    }
    
    public static func initDragState_Unsafe() {
        _drag.origin = getRoundedPointerLocation()
        _drag.originOffset = Vector(x: 0, y: 0)
        _drag.activationState = .initialized
        _drag.isSuspended = false
        
        _drag.outputPlugin?.initialize(with: _drag)
        
        if let tap = _drag.eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
            DDLogDebug("Enabled drag eventTap")
        }
    }
    
    @objc public static func suspend() -> (() -> Void)? {
        var unsuspend: (() -> Void)? = nil
        let drag = _drag
        
        drag.queue.sync {
            if drag.activationState != .inUse {
                return
            }
            DDLogDebug("Suspending ModifiedDrag")
            deactivate_Unsafe(cancel: true)
            drag.isSuspended = true
            drag.outputPlugin?.suspend()
            
            let ogTime = drag.initTime
            unsuspend = {
                drag.queue.async {
                    if ogTime == drag.initTime && drag.isSuspended {
                        DDLogDebug("UNSuspending ModifiedDrag")
                        drag.isSuspended = false
                        initDragState_Unsafe()
                        drag.outputPlugin?.unsuspend()
                    }
                }
            }
        }
        
        return unsuspend
    }
    
    @objc public static func deactivate() {
        deactivate(withCancel: false)
    }
    
    @objc public static func deactivate(withCancel cancel: Bool) {
        _drag.queue.async {
            deactivate_Unsafe(cancel: cancel)
        }
    }
    
    public static func deactivate_Unsafe(cancel: Bool) {
        DDLogDebug("modifiedDrag deactivate with state: \(modifiedDragStateDescription(_drag))")
        
        _drag.isSuspended = false
        if _drag.activationState == .none {
            return
        }
        
        if _drag.activationState == .inUse {
            _drag.outputPlugin?.handleDeactivationWhileInUse(cancel: cancel)
        }
        
        _drag.activationState = .none
        if let tap = _drag.eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        
        DDLogDebug("\nmodifiedDrag disabled drag eventTap. Caller info: \(SharedUtility.callerInfo() ?? "")")
    }
    
    @objc public static func getRoundedPointerLocation() -> CGPoint {
        let event = CGEvent(source: nil)
        let location = getRoundedPointerLocation(with: event)
        return location
    }
    
    public static func getRoundedPointerLocation(with event: CGEvent?) -> CGPoint {
        guard let event = event else { return .zero }
        let pointerLocation = event.location
        return CGPoint(x: floor(pointerLocation.x), y: floor(pointerLocation.y))
    }
    
    private static func modifiedDragStateDescription(_ drag: ModifiedDragState) -> String {
        return """
        
        eventTap: \(String(describing: drag.eventTap))
        usageThreshold: \(drag.usageThreshold)
        type: \(drag.type ?? "nil")
        activationState: \(drag.activationState.rawValue)
        origin: (\(drag.origin.x), \(drag.origin.y))
        originOffset: (\(drag.originOffset.x), \(drag.originOffset.y))
        usageAxis: \(drag.usageAxis.rawValue)
        phase: \(drag.firstCallback)
        """
    }
    
    // Internal callback state handlers
    public static func handleMouseInputWhileInitialized(deltaX: Int64, deltaY: Int64, event: CGEvent) {
        let ofs = _drag.originOffset
        if max(abs(ofs.x), abs(ofs.y)) > Double(_drag.usageThreshold) {
            DDLogDebug("Modified Drag entered 'in use' state")
            
            _drag.usageOrigin = getRoundedPointerLocation(with: event)
            if abs(ofs.x) < abs(ofs.y) {
                _drag.usageAxis = kMFAxisVertical
            } else {
                _drag.usageAxis = kMFAxisHorizontal
            }
            
            _drag.activationState = .inUse
            _drag.firstCallback = true
            
            let systemScrollDirection = UserDefaults.standard.object(forKey: "com.apple.swipescrolldirection") as? NSNumber
            _drag.naturalDirection = systemScrollDirection == nil ? true : systemScrollDirection!.boolValue
            
            _drag.outputPlugin?.handleBecameInUse()
            TrialCounter.shared.handleUse()
            Modifiers.handleModificationHasBeenUsed()
        }
    }
    
    public static func handleMouseInputWhileInUse(deltaX: Double, deltaY: Double, event: CGEvent) {
        var dx = deltaX
        var dy = deltaY
        
        if !_drag.naturalDirection {
            dx = -dx
            dy = -dy
        }
        
        _drag.outputPlugin?.handleMouseInputWhileInUse(deltaX: dx, deltaY: dy, event: event)
        _drag.firstCallback = false
    }
}

// CGEventTap C-style callback bridge
private let eventTapCallBack: CGEventTapCallBack = { proxy, type, event, refcon in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        DDLogDebug("ModifiedDrag eventTap was disabled by \(type == .tapDisabledByTimeout ? "timeout. Re-enabling." : "user input.")")
        if type == .tapDisabledByTimeout {
            if let tap = ModifiedDrag._drag.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        }
        return Unmanaged.passUnretained(event)
    }
    
    let dx = event.getIntegerValueField(.mouseEventDeltaX)
    let dy = event.getIntegerValueField(.mouseEventDeltaY)
    
    if dx != 0 || dy != 0 {
        if let eventCopy = event.copy() {
            let drag = ModifiedDrag._drag
            drag.queue.async {
                if let tap = drag.eventTap, !CGEvent.tapIsEnabled(tap: tap) {
                    return
                }
                
                drag.originOffset.x += Double(dx)
                drag.originOffset.y += Double(dy)
                
                if drag.isSuspended {
                    return
                }
                
                DDLogDebug("ModifiedDrag handling mouseMoved")
                
                let st = drag.activationState
                if st == .initialized {
                    ModifiedDrag.handleMouseInputWhileInitialized(deltaX: dx, deltaY: dy, event: eventCopy)
                } else if st == .inUse {
                    ModifiedDrag.handleMouseInputWhileInUse(deltaX: Double(dx), deltaY: Double(dy), event: eventCopy)
                }
            }
        }
    }
    
    event.type = .mouseMoved
    return Unmanaged.passUnretained(event)
}
