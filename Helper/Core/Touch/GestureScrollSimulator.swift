//
// --------------------------------------------------------------------------
// GestureScrollSimulator.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020 (Swiftified in 2026)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Foundation
import CoreGraphics
import QuartzCore

@objc class GestureScrollSimulator: NSObject {
    
    private static let scrollLinePixelator = VectorSubPixelator.biased()
    private static let momentumAnimator = TouchAnimator()
    
    private static let momentumQueue: DispatchQueue = {
        return DispatchQueue(label: "com.nuebling.mac-mouse-fix.gesture-scroll", qos: .userInteractive)
    }()
    
    private static var momentumScrollCallback: (() -> Void)?
    
    @objc static func getAfterStartingMomentumScrollCallback() -> (() -> Void)? {
        return momentumScrollCallback
    }
    
    @objc static func afterStartingMomentumScroll(_ callback: (() -> Void)?) {
        momentumQueue.async {
            if momentumAnimator.isRunning && callback != nil {
                DDLogError("Trying to set momentumScroll start callback while it's running. This can lead to bad issues and you probably don't want to do it.")
                assertionFailure()
            }
            momentumScrollCallback = callback
        }
    }
    
    @objc static func suspendMomentumScroll() {
        momentumQueue.sync {
            stopMomentumScroll_Unsafe()
        }
    }
    
    @objc static func stopMomentumScroll() {
        DDLogDebug("momentumScroll stop request. Caller: \(SharedUtility.callerInfo() ?? "unknown")")
        momentumQueue.async {
            stopMomentumScroll_Unsafe()
        }
    }
    
    private static func stopMomentumScroll_Unsafe() {
        momentumAnimator.cancel(forAutoMomentumScroll: true)
    }
    
    @objc static func postGestureScrollEvent(
        withDeltaX dx: Int64,
        deltaY dy: Int64,
        phase: IOHIDEventPhaseBits,
        autoMomentumScroll: Bool,
        invertedFromDevice: Bool
    ) {
        if !(dx == 0 && dy == 0 ? (phase == IOHIDEventPhaseBits(kIOHIDEventPhaseEnded) || phase == IOHIDEventPhaseBits(kIOHIDEventPhaseMayBegin) || phase == IOHIDEventPhaseBits(kIOHIDEventPhaseCancelled)) : true) {
            DDLogWarn("Trying to post gesture scroll with zero deltas while phase is not Ended, MayBegin, or Cancelled - ignoring")
            assertionFailure()
            return
        }
        
        stopMomentumScroll_Unsafe()
        
        struct StaticVars {
            static var lastInputTime: CFTimeInterval = 0
            static var lastScrollVec = Vector(x: 0, y: 0)
        }
        
        let now = CACurrentMediaTime()
        var timeSinceLastInput: CFTimeInterval
        
        if phase == IOHIDEventPhaseBits(kIOHIDEventPhaseBegan) {
            timeSinceLastInput = Double.greatestFiniteMagnitude
        } else {
            timeSinceLastInput = now - StaticVars.lastInputTime
        }
        
        if phase == IOHIDEventPhaseBits(kIOHIDEventPhaseBegan) {
            scrollLinePixelator.reset()
        }
        
        if phase == IOHIDEventPhaseBits(kIOHIDEventPhaseBegan) ||
            phase == IOHIDEventPhaseBits(kIOHIDEventPhaseChanged) ||
            phase == IOHIDEventPhaseBits(kIOHIDEventPhaseMayBegin) ||
            phase == IOHIDEventPhaseBits(kIOHIDEventPhaseCancelled) {
            
            let vecScrollPoint = Vector(x: CGFloat(dx), y: CGFloat(dy))
            var vecScrollLine = Vector(x: 0, y: 0)
            var vecScrollLineInt = Vector(x: 0, y: 0)
            var vecGesture = Vector(x: 0, y: 0)
            
            getDeltaVectors(point: vecScrollPoint, subPixelator: scrollLinePixelator, line: &vecScrollLine, lineInt: &vecScrollLineInt, gesture: &vecGesture)
            
            StaticVars.lastScrollVec = vecScrollPoint
            
            postGestureScrollEvent(
                withGestureVector: vecGesture,
                scrollVectorLine: vecScrollLine,
                scrollVectorLineInt: vecScrollLineInt,
                scrollVectorPoint: vecScrollPoint,
                phase: phase,
                momentumPhase: .none,
                invertedFromDevice: invertedFromDevice
            )
            
        } else if phase == IOHIDEventPhaseBits(kIOHIDEventPhaseEnded) {
            let zeroVector = Vector(x: 0, y: 0)
            postGestureScrollEvent(
                withGestureVector: zeroVector,
                scrollVectorLine: zeroVector,
                scrollVectorLineInt: zeroVector,
                scrollVectorPoint: zeroVector,
                phase: IOHIDEventPhaseBits(kIOHIDEventPhaseEnded),
                momentumPhase: .none,
                invertedFromDevice: invertedFromDevice
            )
            
            if autoMomentumScroll {
                let exitVelocity = Vector(
                    x: StaticVars.lastScrollVec.x / CGFloat(timeSinceLastInput),
                    y: StaticVars.lastScrollVec.y / CGFloat(timeSinceLastInput)
                )
                
                let stopSpeed = 1.0
                let dragCoeff = 30.0
                let dragExp = 0.7
                
                startMomentumScroll(
                    timeSinceLastInput: timeSinceLastInput,
                    exitVelocity: exitVelocity,
                    stopSpeed: stopSpeed,
                    dragCoefficient: dragCoeff,
                    dragExponent: dragExp,
                    invertedFromDevice: invertedFromDevice
                )
            }
        } else {
            DDLogError("Trying to send GestureScroll with invalid IOHIDEventPhase: \(phase)")
            assertionFailure()
        }
        
        StaticVars.lastInputTime = now
    }
    
    @objc static func postMomentumScrollDirectly(
        withDeltaX dx: Double,
        deltaY dy: Double,
        momentumPhase: CGMomentumScrollPhase,
        invertedFromDevice: Bool
    ) {
        if momentumPhase == .begin {
            scrollLinePixelator.reset()
        }
        
        let zeroVector = Vector(x: 0, y: 0)
        let vecScrollPoint = Vector(x: CGFloat(dx), y: CGFloat(dy))
        var vecScrollLine = Vector(x: 0, y: 0)
        var vecScrollLineInt = Vector(x: 0, y: 0)
        
        getDeltaVectors(point: vecScrollPoint, subPixelator: scrollLinePixelator, line: &vecScrollLine, lineInt: &vecScrollLineInt, gesture: nil)
        
        postGestureScrollEvent(
            withGestureVector: zeroVector,
            scrollVectorLine: vecScrollLine,
            scrollVectorLineInt: vecScrollLineInt,
            scrollVectorPoint: vecScrollPoint,
            phase: IOHIDEventPhaseBits(kIOHIDEventPhaseUndefined),
            momentumPhase: momentumPhase,
            invertedFromDevice: invertedFromDevice
        )
    }
    
    private static func startMomentumScroll(
        timeSinceLastInput: Double,
        exitVelocity: Vector,
        stopSpeed: Double,
        dragCoefficient: Double,
        dragExponent: Double,
        invertedFromDevice: Bool
    ) {
        momentumQueue.sync {
            startMomentumScroll_Unsafe(
                timeSinceLastInput: timeSinceLastInput,
                exitVelocity: exitVelocity,
                stopSpeed: stopSpeed,
                dragCoefficient: dragCoefficient,
                dragExponent: dragExponent,
                invertedFromDevice: invertedFromDevice
            )
        }
    }
    
    private static func startMomentumScroll_Unsafe(
        timeSinceLastInput: Double,
        exitVelocity: Vector,
        stopSpeed: Double,
        dragCoefficient: Double,
        dragExponent: Double,
        invertedFromDevice: Bool
    ) {
        DDLogDebug("momentumScroll start request")
        
        let zeroVector = Vector(x: 0, y: 0)
        
        if GeneralConfig.mouseMovingMaxIntervalLarge() < timeSinceLastInput || timeSinceLastInput == Double.greatestFiniteMagnitude {
            DDLogDebug("Not sending momentum scroll - timeSinceLastInput: \(timeSinceLastInput)")
            if let callback = momentumScrollCallback {
                callback()
            }
            stopMomentumScroll()
            return
        }
        
        momentumAnimator.resetSubPixelator_Unsafe()
        momentumAnimator.linkToMainScreen()
        
        momentumAnimator.start(params: { valueLeft, isRunning, curve, currentSpeed in
            let p = NSMutableDictionary()
            scrollLinePixelator.reset()
            
            let initialVelocity = initalMomentumScrollVelocity_FromExitVelocity(exitVelocity)
            let initialSpeed = magnitudeOfVector(initialVelocity)
            
            if initialSpeed <= stopSpeed {
                DDLogDebug("Not starting momentum scroll - initialSpeed smaller stopSpeed: i: \(initialSpeed), s: \(stopSpeed)")
                if let callback = momentumScrollCallback {
                    callback()
                }
                stopMomentumScroll()
                p["doStart"] = false
                return p
            }
            
            let animationCurve = DragCurve(coefficient: dragCoefficient, exponent: dragExponent, initialSpeed: initialSpeed, stopSpeed: stopSpeed)
            
            let duration = animationCurve.timeInterval.length
            let distance = animationCurve.distanceInterval.length
            
            let distanceVec = scaledVector(unitVector(initialVelocity), distance)
            
            p["vector"] = nsValueFromVector(distanceVec)
            p["duration"] = duration
            p["curve"] = animationCurve
            
            return p
        }, integerCallback: { deltaVec, animationPhase, subCurve in
            DDLogDebug("Momentum scrolling - delta: \(deltaVec), animationPhase: \(animationPhase.rawValue)")
            
            var vecScrollLine = Vector(x: 0, y: 0)
            var vecScrollLineInt = Vector(x: 0, y: 0)
            getDeltaVectors(point: deltaVec, subPixelator: scrollLinePixelator, line: &vecScrollLine, lineInt: &vecScrollLineInt, gesture: nil)
            
            var momentumPhase: CGMomentumScrollPhase
            if animationPhase == kMFAnimationCallbackPhaseStart {
                momentumPhase = .begin
            } else if animationPhase == kMFAnimationCallbackPhaseContinue {
                momentumPhase = .continuous
            } else if animationPhase == kMFAnimationCallbackPhaseEnd || animationPhase == kMFAnimationCallbackPhaseCanceled {
                momentumPhase = .end
            } else {
                assertionFailure()
                momentumPhase = .end
            }
            
            if momentumPhase == .end {
                assert(isZeroVector(deltaVec))
            }
            
            postGestureScrollEvent(
                withGestureVector: zeroVector,
                scrollVectorLine: vecScrollLine,
                scrollVectorLineInt: vecScrollLineInt,
                scrollVectorPoint: deltaVec,
                phase: IOHIDEventPhaseBits(kIOHIDEventPhaseUndefined),
                momentumPhase: momentumPhase,
                invertedFromDevice: invertedFromDevice
            )
            
            if animationPhase == kMFAnimationCallbackPhaseEnd || animationPhase == kMFAnimationCallbackPhaseCanceled {
                postGestureScrollEvent(
                    withGestureVector: zeroVector,
                    scrollVectorLine: zeroVector,
                    scrollVectorLineInt: zeroVector,
                    scrollVectorPoint: zeroVector,
                    phase: IOHIDEventPhaseBits(kIOHIDEventPhaseMayBegin),
                    momentumPhase: .none,
                    invertedFromDevice: invertedFromDevice
                )
                postGestureScrollEvent(
                    withGestureVector: zeroVector,
                    scrollVectorLine: zeroVector,
                    scrollVectorLineInt: zeroVector,
                    scrollVectorPoint: zeroVector,
                    phase: IOHIDEventPhaseBits(kIOHIDEventPhaseCancelled),
                    momentumPhase: .none,
                    invertedFromDevice: invertedFromDevice
                )
            }
            
            if animationPhase == kMFAnimationCallbackPhaseStart {
                if let callback = momentumScrollCallback {
                    callback()
                }
            }
        })
    }
    
    private static func initalMomentumScrollVelocity_FromExitVelocity(_ exitVelocity: Vector) -> Vector {
        return scaledVectorWithFunction(exitVelocity) { x in
            return x * 1.0
        }
    }
    
    private static func getDeltaVectors(
        point: Vector,
        subPixelator: VectorSubPixelator,
        line: inout Vector,
        lineInt: inout Vector,
        gesture: UnsafeMutablePointer<Vector>?
    ) {
        assert(point.x == round(point.x) && point.y == round(point.y))
        
        subPixelator.setPixelationThreshold(Double.infinity)
        
        var lineVal = scaledVector(point, 1.0 / 10.0)
        lineVal = subPixelator.intVector(withDoubleVector: lineVal)
        line = lineVal
        
        lineInt = vectorByApplyingToEachDimension(lineVal) { val in
            return abs(val) <= 1.0 ? signedCeil(val) : signedFloor(val)
        }
        
        if let gesture = gesture {
            gesture.pointee = scaledVector(point, 1.67)
        }
        
        DDLogDebug("\nHNGG Constructed deltas - point: \(vectorDescription(point)) \t line: \(vectorDescription(line)) \t lineInt: \(vectorDescription(lineInt))")
    }
    
    private static func postGestureScrollEvent(
        withGestureVector vecGesture: Vector,
        scrollVectorLine vecScrollLine: Vector,
        scrollVectorLineInt vecScrollLineInt: Vector,
        scrollVectorPoint vecScrollPoint: Vector,
        phase: IOHIDEventPhaseBits,
        momentumPhase: CGMomentumScrollPhase,
        invertedFromDevice: Bool
    ) {
        assert(phase == IOHIDEventPhaseBits(kIOHIDEventPhaseUndefined) || momentumPhase == .none)
        
        if runningPreRelease() {
            struct StaticVars {
                static var tsLast: Double = 0
            }
            let ts = CACurrentMediaTime()
            let timeSinceLast = ts - StaticVars.tsLast
            StaticVars.tsLast = ts
            
            DDLogDebug("\nHNGG Posting: gesture: \(vectorDescription(vecGesture)) \t line: \(vectorDescription(vecScrollLine)), lineInt: \(vectorDescription(vecScrollLineInt)), point: \(vectorDescription(vecScrollPoint)) \t phases: (\(phase), \(momentumPhase.rawValue)) \t timeSinceLast: \(timeSinceLast * 1000) \n")
        }
        
        let eventTs = UInt64(CACurrentMediaTime() * Double(NSEC_PER_SEC))
        
        guard let e22 = CGEvent(source: nil) else { return }
        
        e22.setIntegerValueField(CGEventField(rawValue: 55)!, value: 22) // NSEventTypeScrollWheel
        e22.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)  // continuous
        e22.setIntegerValueField(CGEventField(rawValue: 137)!, value: invertedFromDevice ? 1 : 0) // inverted
        
        e22.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: Int64(vecScrollLineInt.y))
        e22.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: Int64(vecScrollPoint.y))
        e22.setIntegerValueField(.scrollWheelEventFixedPtDeltaAxis1, value: fixedScrollDelta(vecScrollLine.y))
        
        e22.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: Int64(vecScrollLineInt.x))
        e22.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: Int64(vecScrollPoint.x))
        e22.setIntegerValueField(.scrollWheelEventFixedPtDeltaAxis2, value: fixedScrollDelta(vecScrollLine.x))
        
        e22.setIntegerValueField(.scrollWheelEventScrollPhase, value: Int64(phase))
        e22.setIntegerValueField(.scrollWheelEventMomentumPhase, value: Int64(momentumPhase.rawValue))
        
        DDLogDebug("\nHNGG Sent event: \(scrollEventDescription(e22))")
        
        e22.timestamp = eventTs
        e22.post(tap: .cgSessionEventTap)
        
        if phase != IOHIDEventPhaseBits(kIOHIDEventPhaseUndefined) {
            guard let e29 = CGEvent(source: nil) else { return }
            
            e29.setIntegerValueField(CGEventField(rawValue: 55)!, value: 29) // NSEventTypeGesture
            e29.setIntegerValueField(CGEventField(rawValue: 110)!, value: 6) // subtype kIOHIDEventTypeScroll
            
            var dxGesture = Double(vecGesture.x)
            var dyGesture = Double(vecGesture.y)
            if dxGesture == 0 { dxGesture = -0.0 }
            if dyGesture == 0 { dyGesture = -0.0 }
            
            e29.setDoubleValueField(CGEventField(rawValue: 116)!, value: dxGesture)
            e29.setDoubleValueField(CGEventField(rawValue: 119)!, value: dyGesture)
            
            e29.setIntegerValueField(CGEventField(rawValue: 132)!, value: Int64(phase))
            
            e29.timestamp = eventTs
            e29.post(tap: .cgSessionEventTap)
        }
    }
}
