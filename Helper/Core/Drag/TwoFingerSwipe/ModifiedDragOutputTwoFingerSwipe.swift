//
// --------------------------------------------------------------------------
// ModifiedDragOutputTwoFingerSwipe.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022 (Translated to Swift in 2026)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Foundation
import CoreGraphics
import Cocoa

@objc(ModifiedDragOutputTwoFingerSwipe)
class ModifiedDragOutputTwoFingerSwipe: NSObject, ModifiedDragOutputPlugin {
    
    // 全局静态属性，用于存放 TouchAnimator 实例和 DispatchGroup
    static let _smoothingAnimator = TouchAnimator()
    static let _momentumScrollWaitGroup = DispatchGroup()
    static var _smoothingAnimatorShouldStartMomentumScroll: Bool = false
    
    @objc public static func load_Manual() {
        ModificationUtility.makeCursorSettable()
    }
    
    private weak var drag: ModifiedDragState?
    private var eventPhase: IOHIDEventPhaseBits = IOHIDEventPhaseBits(kIOHIDEventPhaseUndefined)
    
    func initialize(with dragState: ModifiedDragState) {
        self.drag = dragState
        Scroll.resetState()
    }
    
    func handleBecameInUse() {
        guard let drag = self.drag else { return }
        
        if GeneralConfig.freezePointerDuringModifiedDrag() {
            PointerFreeze.freezePointer(atPosition: drag.usageOrigin)
        } else {
            PointerFreeze.freezeEventDispatchPoint(atPosition: drag.usageOrigin)
        }
        
        ModifiedDragOutputTwoFingerSwipe._smoothingAnimator.resetSubPixelator()
        ModifiedDragOutputTwoFingerSwipe._smoothingAnimator.linkToMainScreen()
    }
    
    func handleMouseInputWhileInUse(deltaX: Double, deltaY: Double, event: CGEvent?) {
        guard let drag = self.drag else { return }
        
        let twoFingerScale = 1.0
        let firstCallback = drag.firstCallback
        
        ModifiedDragOutputTwoFingerSwipe._smoothingAnimator.start(params: { [weak self] valueLeft, isRunning, animationCurve, currentSpeed in
            guard let self = self else { return NSDictionary() }
            
            let p = NSMutableDictionary()
            let currentVec = Vector(x: deltaX * twoFingerScale, y: deltaY * twoFingerScale)
            let combinedVec = addedVectors(currentVec, valueLeft)
            
            if firstCallback {
                self.eventPhase = IOHIDEventPhaseBits(kIOHIDEventPhaseBegan)
            }
            
            if magnitudeOfVector(combinedVec) == 0.0 {
                DDLogWarn("twoFinger Not starting baseAnimator since combinedMagnitude is 0.0")
                p["doStart"] = false
            } else {
                p["vector"] = nsValueFromVector(combinedVec)
                p["curve"] = ScrollConfig.linearCurve
                p["duration"] = 3.0 / 60.0
            }
            
            return p as NSDictionary
            
        }, integerCallback: { [weak self] deltaVec, animatorPhase, subCurve in
            guard let self = self, let drag = self.drag else { return }
            
            DDLogDebug("\n twoFinger smoothingAnimator callback - delta: (\(deltaVec.x), \(deltaVec.y)), phase: \(animatorPhase.rawValue), shouldStartMomentumScroll: \(ModifiedDragOutputTwoFingerSwipe._smoothingAnimatorShouldStartMomentumScroll)")
            
            if animatorPhase == kMFAnimationCallbackPhaseEnd {
                if ModifiedDragOutputTwoFingerSwipe._smoothingAnimatorShouldStartMomentumScroll {
                    GestureScrollSimulator.postGestureScrollEvent(
                        withDeltaX: 0,
                        deltaY: 0,
                        phase: IOHIDEventPhaseBits(kIOHIDEventPhaseEnded),
                        autoMomentumScroll: true,
                        invertedFromDevice: drag.naturalDirection
                    )
                }
                ModifiedDragOutputTwoFingerSwipe._smoothingAnimatorShouldStartMomentumScroll = false
                return
            }
            
            GestureScrollSimulator.postGestureScrollEvent(
                withDeltaX: Int64(deltaVec.x),
                deltaY: Int64(deltaVec.y),
                phase: self.eventPhase,
                autoMomentumScroll: true,
                invertedFromDevice: drag.naturalDirection
            )
            
            self.eventPhase = IOHIDEventPhaseBits(kIOHIDEventPhaseChanged)
        })
    }
    
    func handleDeactivationWhileInUse(cancel: Bool) {
        guard let drag = self.drag else { return }
        
        if cancel {
            if ModifiedDragOutputTwoFingerSwipe._smoothingAnimator.isRunning {
                ModifiedDragOutputTwoFingerSwipe._smoothingAnimator.cancel()
            }
            GestureScrollSimulator.postGestureScrollEvent(
                withDeltaX: 0,
                deltaY: 0,
                phase: IOHIDEventPhaseBits(kIOHIDEventPhaseEnded),
                autoMomentumScroll: true,
                invertedFromDevice: drag.naturalDirection
            )
            GestureScrollSimulator.suspendMomentumScroll()
            PointerFreeze.unfreeze()
            return
        }
        
        DDLogDebug("twoFinger Entering _momentumScrollWaitGroup")
        ModifiedDragOutputTwoFingerSwipe._momentumScrollWaitGroup.enter()
        
        GestureScrollSimulator.afterStartingMomentumScroll {
            DDLogDebug("twoFinger Leaving _momentumScrollWaitGroup")
            ModifiedDragOutputTwoFingerSwipe._momentumScrollWaitGroup.leave()
            GestureScrollSimulator.afterStartingMomentumScroll(nil)
        }
        
        if ModifiedDragOutputTwoFingerSwipe._smoothingAnimator.isRunning {
            ModifiedDragOutputTwoFingerSwipe._smoothingAnimatorShouldStartMomentumScroll = true
            DDLogDebug("twoFinger Set _smoothingAnimatorShouldStartMomentumScroll = YES")
        } else {
            DDLogDebug("twoFinger Starting momentumScroll directly")
            GestureScrollSimulator.postGestureScrollEvent(
                withDeltaX: 0,
                deltaY: 0,
                phase: IOHIDEventPhaseBits(kIOHIDEventPhaseEnded),
                autoMomentumScroll: true,
                invertedFromDevice: drag.naturalDirection
            )
        }
        
        DDLogDebug("twoFinger Waiting for dispatch group")
        let rt = ModifiedDragOutputTwoFingerSwipe._momentumScrollWaitGroup.wait(timeout: .now() + 2.0)
        
        if rt == .timedOut {
            DDLogError("twoFinger _momentumScrollWaitGroup timed out. Will crash.")
            if !runningPreRelease() {
                PointerFreeze.unfreeze()
            }
            assert(false)
            exit(EXIT_FAILURE)
        }
        
        PointerFreeze.unfreeze()
    }
    
    func suspend() {}
    func unsuspend() {}
}
