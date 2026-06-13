//
// --------------------------------------------------------------------------
// Scroll.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#if IS_HELPER

import Cocoa
import ApplicationServices
import IOKit

private let eventTapCallback: CGEventTapCallBack = { proxy, type, event, refcon in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        DDLogDebug("Scroll.swift: eventTap was disabled by \(type == .tapDisabledByTimeout ? "timeout. Re-enabling." : "user input.")")
        if type == .tapDisabledByTimeout {
            if let tap = Scroll.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        }
        return Unmanaged.passUnretained(event)
    }
    
    if let resultEvent = Scroll.handleEventTap(proxy: proxy, type: type, event: event) {
        return Unmanaged.passUnretained(resultEvent)
    } else {
        return nil
    }
}

@objc(Scroll)
public class Scroll: NSObject {
    
    fileprivate static var _eventTap: CFMachPort?
    public static var eventTap: CFMachPort? {
        return _eventTap
    }
    
    private static var _eventSource: CGEventSource?
    private static var _scrollQueue: DispatchQueue!
    private static var _animator: TouchAnimator!
    
    private static var _systemWideAXUIElement: AXUIElement?
    @objc public static func systemWideAXUIElement() -> AXUIElement? {
        return _systemWideAXUIElement
    }
    
    // 动态变量
    private static var _modifications = MFScrollModificationResult(inputMod: kMFScrollInputModificationNone, effectMod: kMFScrollEffectModificationNone)
    private static var _scrollConfig: ScrollConfig?
    private static var _animationParams: MFScrollAnimationCurveParameters?
    private static var _lastScrollAnalysisResult = ScrollAnalysisResult(
        consecutiveScrollTickCounter: 0,
        consecutiveScrollSwipeCounter: 0,
        scrollDirectionDidChange: false,
        timeBetweenTicks: 0,
        DEBUG_timeBetweenTicksRaw: 0,
        DEBUG_consecutiveScrollSwipeCounterRaw: 0
    )
    private static var _lastScrollAnalysisResultTimeStamp: CFTimeInterval = 0
    
    // 缓存变量
    private static var cachedDev: IOHIDDevice?
    private static var cachedIsHiResLogitech = false
    private static var cachedIsApple = false
    private static var cachedIsInternal = false
    private static var cachedFirmwareHandlesInvert = false
    
    private static var _appSwitcherIsOpen = false
    
    @objc public static func load_Manual() {
        _scrollQueue = DispatchQueue(label: "com.nuebling.mac-mouse-fix.helper.scroll", qos: .userInteractive)
        _systemWideAXUIElement = AXUIElementCreateSystemWide()
        
        if _eventSource == nil {
            _eventSource = CGEventSource(stateID: .combinedSessionState)
        }
        
        if _eventTap == nil {
            let mask = 1 << CGEventType.scrollWheel.rawValue
            _eventTap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: CGEventMask(mask),
                callback: eventTapCallback,
                userInfo: nil
            )
            DDLogDebug("Scroll.swift: _eventTap: \(_eventTap == nil ? "nil" : "non-nil")")
            if let tap = _eventTap {
                let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
                CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
                CGEvent.tapEnable(tap: tap, enable: false)
            }
        }
        
        _animator = TouchAnimator()
        _scrollConfig = nil
    }
    
    @objc public static func configChanged() {
        _scrollConfig = nil
    }
    
    @objc public static func resetState() {
        _scrollQueue.async {
            resetState_Unsafe()
        }
    }
    
    @objc public static func resetState_Sync() {
        _scrollQueue.sync {
            resetState_Unsafe()
        }
    }
    
    private static func resetState_Unsafe() {
        DDLogDebug("Scroll.swift: reset-animator")
        _animator.cancel()
        GestureScrollSimulator.stopMomentumScroll()
        ScrollAnalyzer.resetState()
    }
    
    @objc public static func startReceiving() {
        DDLogDebug("Scroll.swift: startReceiving. isReceiving: \(isReceiving())")
        if let tap = _eventTap, !CGEvent.tapIsEnabled(tap: tap) {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }
    
    @objc public static func stopReceiving() {
        DDLogDebug("Scroll.swift: stopReceiving. isReceiving: \(isReceiving())")
        if let tap = _eventTap, CGEvent.tapIsEnabled(tap: tap) {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
    }
    
    @objc public static func isReceiving() -> Bool {
        if let tap = _eventTap {
            return CGEvent.tapIsEnabled(tap: tap)
        }
        return false
    }
    
    private static func CGScrollWheelEventDescription(_ event: CGEvent) -> String {
        let d = event.getDoubleValueField(.scrollWheelEventDeltaAxis1)
        let dPoint = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)
        let dFixed = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
        let dContinuous = event.getIntegerValueField(.scrollWheelEventIsContinuous)
        let dCount = event.getDoubleValueField(.scrollWheelEventScrollCount)
        let dInstant = event.getDoubleValueField(.scrollWheelEventInstantMouser)
        let dPhase = event.getDoubleValueField(.scrollWheelEventScrollPhase)
        let dMomPhase = event.getDoubleValueField(.scrollWheelEventMomentumPhase)
        return "d: \(d) dPoint: \(dPoint) dFixed: \(dFixed) isContinuous: \(dContinuous) count: \(dCount) instant: \(dInstant) phase: \(dPhase) momPhase: \(dMomPhase)"
    }
    
    fileprivate static func handleEventTap(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> CGEvent? {
        let isPixelBased = event.getIntegerValueField(.scrollWheelEventIsContinuous)
        let scrollPhase = event.getIntegerValueField(.scrollWheelEventScrollPhase)
        let scrollDeltaAxis1 = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
        let scrollDeltaAxis2 = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2)
        let drawingTabletID = event.getIntegerValueField(.tabletEventDeviceID)
        let isDiagonal = (scrollDeltaAxis1 != 0 && scrollDeltaAxis2 != 0)
        
        let sendingDev = CGEventGetSendingDevice(event)?.takeUnretainedValue()
        
        if sendingDev != nil && sendingDev != cachedDev {
            let vendorID = IOHIDDeviceGetProperty(sendingDev!, kIOHIDVendorIDKey as CFString) as? NSNumber
            let productName = IOHIDDeviceGetProperty(sendingDev!, kIOHIDProductKey as CFString) as? String
            
            cachedIsApple = (vendorID != nil && vendorID!.intValue == 1452)
            cachedIsInternal = (productName != nil && productName! == "Apple Internal Keyboard / Trackpad")
            let vid = vendorID?.intValue ?? 0
            let isLogitech = (vid == 1133 || vid == 13652 || vid == 0x046D || vid == 0x046d)
            
            cachedFirmwareHandlesInvert = false
            if isLogitech {
                let hiResConfig = Config.shared.config.object(forCoolKeyPath: "Pointer.logitechHiResWheel") as? NSNumber
                cachedFirmwareHandlesInvert = (hiResConfig != nil && hiResConfig!.boolValue)
            }
            cachedIsHiResLogitech = cachedFirmwareHandlesInvert
            cachedDev = sendingDev
        }
        
        let isHiResLogitech = cachedIsHiResLogitech
        
        if runningPreRelease() {
            let isNatural = event.getIntegerValueField(CGEventField(rawValue: 137)!)
            let dbgVendorID = sendingDev != nil ? IOHIDDeviceGetProperty(sendingDev!, kIOHIDVendorIDKey as CFString) as? NSNumber : nil
            let dbgProductName = sendingDev != nil ? IOHIDDeviceGetProperty(sendingDev!, kIOHIDProductKey as CFString) as? String : nil
            DDLogDebug("[DEBUG eventTapCallback] type: \(type.rawValue), isPixelBased: \(isPixelBased), isHiResLogitech: \(isHiResLogitech), scrollPhase: \(scrollPhase), sendingDev: \(String(describing: sendingDev)), Vid: \(String(describing: dbgVendorID)), Product: \(String(describing: dbgProductName)), invertDir: \(ScrollConfig.shared.u_invertDirection.rawValue), delta1: \(scrollDeltaAxis1), delta2: \(scrollDeltaAxis2), isNatural: \(isNatural)")
        }
        
        if !ScrollConfig.shared.smoothEnabled && ScrollConfig.shared.useAppleAcceleration {
            if drawingTabletID == 0 && sendingDev != nil {
                let isApple = cachedIsApple
                let isInternal = cachedIsInternal
                let firmwareHandlesInvert = cachedFirmwareHandlesInvert
                
                if !isApple && !isInternal && !firmwareHandlesInvert {
                    if ScrollConfig.shared.u_invertDirection == kMFScrollInversionInverted {
                        let d1 = event.getDoubleValueField(.scrollWheelEventDeltaAxis1)
                        let dp1 = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)
                        let df1 = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
                        event.setDoubleValueField(.scrollWheelEventDeltaAxis1, value: -d1)
                        event.setDoubleValueField(.scrollWheelEventPointDeltaAxis1, value: -dp1)
                        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: -df1)
                        
                        let d2 = event.getDoubleValueField(.scrollWheelEventDeltaAxis2)
                        let dp2 = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis2)
                        let df2 = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2)
                        event.setDoubleValueField(.scrollWheelEventDeltaAxis2, value: -d2)
                        event.setDoubleValueField(.scrollWheelEventPointDeltaAxis2, value: -dp2)
                        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: -df2)
                        
                        if runningPreRelease() {
                            DDLogDebug("[Scroll.swift eventTapCallback] Non-smooth Apple event intercepted and inverted! d1: \(d1), d2: \(d2)")
                        }
                    }
                }
            }
            return event
        }
        
        if isPixelBased != 0
            || isHiResLogitech
            || scrollPhase != 0
            || drawingTabletID != 0
            || isDiagonal {
            
            if drawingTabletID == 0 && sendingDev != nil {
                let isApple = cachedIsApple
                let isInternal = cachedIsInternal
                let firmwareHandlesInvert = cachedFirmwareHandlesInvert
                
                if !isApple && !isInternal && !firmwareHandlesInvert {
                    if ScrollConfig.shared.u_invertDirection == kMFScrollInversionInverted {
                        let d1 = event.getDoubleValueField(.scrollWheelEventDeltaAxis1)
                        let dp1 = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)
                        let df1 = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
                        event.setDoubleValueField(.scrollWheelEventDeltaAxis1, value: -d1)
                        event.setDoubleValueField(.scrollWheelEventPointDeltaAxis1, value: -dp1)
                        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: -df1)
                        
                        let d2 = event.getDoubleValueField(.scrollWheelEventDeltaAxis2)
                        let dp2 = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis2)
                        let df2 = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2)
                        event.setDoubleValueField(.scrollWheelEventDeltaAxis2, value: -d2)
                        event.setDoubleValueField(.scrollWheelEventPointDeltaAxis2, value: -dp2)
                        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: -df2)
                        
                        if runningPreRelease() {
                            DDLogDebug("[Scroll.swift eventTapCallback] HiRes event intercepted and inverted! d1: \(d1), d2: \(d2)")
                        }
                    }
                }
            }
            
            if runningPreRelease() {
                DDLogDebug("[Scroll.swift eventTapCallback] Bypassing scroll event")
            }
            return event
        }
        
        if CGEvent_IsWacomEvent(event) {
            return event
        }
        
        let tickTime = CGEventGetTimestampInSeconds(event)
        
        if let eventCopy = event.copy() {
            _scrollQueue.async {
                heavyProcessing(event: eventCopy, scrollDeltaAxis1: scrollDeltaAxis1, scrollDeltaAxis2: scrollDeltaAxis2, tickTS: tickTime)
            }
        }
        
        return nil
    }
    
    private static func heavyProcessing(event: CGEvent, scrollDeltaAxis1: Int64, scrollDeltaAxis2: Int64, tickTS: CFTimeInterval) {
        
        if runningPreRelease() {
            if let sendingDev = CGEventGetSendingDevice(event)?.takeUnretainedValue() {
                let name = IOHIDDeviceGetProperty(sendingDev, kIOHIDProductKey as CFString) as? String
                let manufacturer = IOHIDDeviceGetProperty(sendingDev, kIOHIDManufacturerKey as CFString) as? String
                DDLogDebug("Scroll.swift: Device sending scroll: \(String(describing: manufacturer)) \(String(describing: name))")
            }
        }
        
        let inputAxis = ScrollUtility.axisForVerticalDelta(scrollDeltaAxis1, horizontalDelta: scrollDeltaAxis2)
        var scrollDelta: Int64 = 0
        if inputAxis == kMFAxisVertical {
            scrollDelta = scrollDeltaAxis1
        } else if inputAxis == kMFAxisHorizontal {
            scrollDelta = scrollDeltaAxis2
        } else {
            assertionFailure("Invalid scroll axis")
        }
        
        if _scrollConfig == nil {
            _scrollConfig = ScrollConfig.shared
        }
        
        let isHorizontalEffect = _modifications.effectMod == kMFScrollEffectModificationHorizontalScroll
        let scrollDirection = ScrollUtility.directionForInputAxis(inputAxis,
                                                                 inputDelta: scrollDelta,
                                                                 invertSetting: _scrollConfig!.u_invertDirection,
                                                                 horizontalModifier: isHorizontalEffect)
        
        let firstConsecutive = ScrollAnalyzer.peekIsFirstConsecutiveTick(withTickOccuringAt: tickTS, direction: scrollDirection, config: _scrollConfig!)
        
        if firstConsecutive {
            TrialCounter.shared.handleUse()
            HelperState.shared.updateActiveDevice(event: event)
            ScrollUtility.updateMouseDidMoveWithEvent(event)
            
            if !ScrollUtility.mouseDidMove {
                ScrollUtility.updateFrontMostAppDidChange()
            }
            
            if ScrollUtility.mouseDidMove || ScrollUtility.frontMostAppDidChange {
                DDLogDebug("Scroll.swift: Frontmost app did change. Reloading config overrides.")
                let didChange = Config.shared.loadOverridesForAppUnderMousePointerWithEvent(event)
                if didChange {
                    DDLogDebug("Scroll.swift: Config did change. Resetting state.")
                    resetState_Unsafe()
                }
            }
            
            let newMods = ScrollModifiers.currentModifications(event: event)
            if !ScrollModifiers.scrollModsAreEqual(newMods, other: _modifications) {
                resetState_Unsafe()
                _modifications = newMods
            }
            
            var displayID: CGDirectDisplayID = 0
            HelperUtility.displayUnderMousePointer(&displayID, with: event)
            
            _scrollConfig = ScrollConfig.scrollConfig(modifiers: newMods, inputAxis: inputAxis, display: displayID)
        }
        
        let finalScrollDirection = ScrollUtility.directionForInputAxis(inputAxis,
                                                                       inputDelta: scrollDelta,
                                                                       invertSetting: _scrollConfig!.u_invertDirection,
                                                                       horizontalModifier: isHorizontalEffect)
        
        let scrollAnalysisResult = ScrollAnalyzer.update(withTickOccuringAt: tickTS, direction: finalScrollDirection, config: _scrollConfig!)
        _lastScrollAnalysisResult = scrollAnalysisResult
        _lastScrollAnalysisResultTimeStamp = CACurrentMediaTime()
        
        DDLogDebug("Scroll.swift: ScrollAnalysisResult: \(ScrollAnalyzer.scrollAnalysisResultDescription(scrollAnalysisResult))")
        
        scrollDelta = abs(scrollDelta)
        
        var pxToScrollForThisTick: Double = 0.0
        if _scrollConfig!.useAppleAcceleration {
            if _scrollConfig!.smoothEnabled {
                var systemLineDelta: Double = 0.0
                if inputAxis == kMFAxisVertical {
                    systemLineDelta = event.getDoubleValueField(.scrollWheelEventDeltaAxis1)
                } else if inputAxis == kMFAxisHorizontal {
                    systemLineDelta = event.getDoubleValueField(.scrollWheelEventDeltaAxis2)
                }
                pxToScrollForThisTick = abs(systemLineDelta) * 40.0
            } else {
                pxToScrollForThisTick = Double(scrollDelta)
            }
        } else {
            var timeBetweenTicks = scrollAnalysisResult.timeBetweenTicks
            assert(timeBetweenTicks == Double.greatestFiniteMagnitude || (timeBetweenTicks >= _scrollConfig!.consecutiveScrollTickIntervalMin && timeBetweenTicks <= _scrollConfig!.consecutiveScrollTickIntervalMax))
            
            if timeBetweenTicks == Double.greatestFiniteMagnitude {
                timeBetweenTicks = _scrollConfig!.consecutiveScrollTickIntervalMax
            }
            
            timeBetweenTicks = max(timeBetweenTicks, _scrollConfig!.consecutiveScrollTickInterval_AccelerationEnd)
            let scrollSpeed = 1.0 / timeBetweenTicks
            
            guard let accelerationCurve = _scrollConfig!.accelerationCurve else {
                assertionFailure("Scroll.swift: accelerationCurve is nil")
                return
            }
            let pxForThisTickDouble = accelerationCurve.evaluate(at: scrollSpeed)
            pxToScrollForThisTick = pxForThisTickDouble
            
            DDLogDebug("Scroll.swift: Acceleration curve f(\(scrollSpeed)) = \(pxToScrollForThisTick) (pxForThisTickDouble: \(pxForThisTickDouble), scrollDelta: \(scrollDelta))")
            
            if pxToScrollForThisTick <= 0.0 {
                DDLogError("Scroll.swift: pxForThisTick is smaller equal 0. This is invalid. Exiting. scrollSpeed: \(scrollSpeed), pxForThisTick: \(pxToScrollForThisTick)")
                // assertionFailure()
                return
            }
            
            if let fastScrollCurve = _scrollConfig!.fastScrollCurve {
                let consecutiveSwipes = scrollAnalysisResult.consecutiveScrollSwipeCounter
                var fastScrollFactor = fastScrollCurve.evaluate(at: consecutiveSwipes + 1)
                if fastScrollFactor > 100000 {
                    fastScrollFactor = 100000
                }
                pxToScrollForThisTick = pxToScrollForThisTick * fastScrollFactor
            }
            
            let currentAnimationSpeed = magnitudeOfVector(_animator.getLastAnimationSpeed)
            if _lastScrollAnalysisResult.scrollDirectionDidChange && currentAnimationSpeed > 0 {
                DDLogDebug("Scroll.swift: Direction change – cancel scroll.")
                _animator.cancel()
                return
            }
            
            DDLogDebug("Scroll.swift: consecTicks: \(scrollAnalysisResult.consecutiveScrollTickCounter), consecSwipes: \(scrollAnalysisResult.DEBUG_consecutiveScrollSwipeCounterRaw), consecSwipesFree: \(scrollAnalysisResult.consecutiveScrollSwipeCounter)")
            DDLogDebug("Scroll.swift: timeBetweenTicks: \(scrollAnalysisResult.timeBetweenTicks), timeBetweenTicksRaw: \(scrollAnalysisResult.DEBUG_timeBetweenTicksRaw), diff: \(scrollAnalysisResult.timeBetweenTicks - scrollAnalysisResult.DEBUG_timeBetweenTicksRaw), ticks: \(scrollAnalysisResult.consecutiveScrollTickCounter)")
        }
        
        if pxToScrollForThisTick == 0.0 {
            DDLogWarn("Scroll.swift: pxToScrollForThisTick is 0")
        } else if !_scrollConfig!.smoothEnabled {
            sendScroll(px: Int64(pxToScrollForThisTick), scrollDirection: finalScrollDirection, animated: false, animationPhase: kMFAnimationCallbackPhaseNone, momentumHint: kMFMomentumHintNone, config: _scrollConfig!)
        } else {
            let configCopyForBlock = _scrollConfig!
            _animator.start(params: { (valueLeftVec, isRunning, animationCurve, currentSpeed) -> NSDictionary in
                assert(valueLeftVec.x == 0 || valueLeftVec.y == 0)
                
                if ScrollUtility.mouseDidMove && !isRunning {
                    _animator.linkToMainScreen_Unsafe()
                }
                
                var p: [AnyHashable: Any] = [:]
                var pxLeftToScroll = 0.0
                
                if isRunning {
                    let distanceLeft = magnitudeOfVector(valueLeftVec)
                    let isSwipeSequenceStart = (scrollAnalysisResult.consecutiveScrollTickCounter == 0 && scrollAnalysisResult.consecutiveScrollSwipeCounter == 0)
                    
                    if isSwipeSequenceStart {
                        pxLeftToScroll = 0.0
                        _animator.resetSubPixelator_Unsafe()
                    } else if animationCurve is SimpleBezierHybridCurve {
                        assertionFailure()
                    } else {
                        pxLeftToScroll = distanceLeft
                    }
                } else {
                    pxLeftToScroll = 0.0
                    _animator.resetSubPixelator_Unsafe()
                }
                
                DDLogDebug("Scroll.swift: animation init - current speed: (\(currentSpeed.x), \(currentSpeed.y))")
                
                let delta = pxToScrollForThisTick + pxLeftToScroll
                let pCurve = configCopyForBlock.animationCurveParams!
                var baseDuration: Double = 0.0
                
                if pCurve.baseMsPerStep != -1 {
                    baseDuration = Double(pCurve.baseMsPerStep) / 1000.0
                } else {
                    guard let baseTimeCurve = pCurve.baseMsPerStepCurve else {
                        DDLogError("Scroll.swift: baseTimeCurve is nil")
                        return [:]
                    }
                    let baseTimeStart = baseTimeCurve.evaluate(at: 0.0)
                    let baseTimeEnd = baseTimeCurve.evaluate(at: 1.0)
                    var tickStart = configCopyForBlock.consecutiveScrollTickIntervalMax
                    let tickEnd = configCopyForBlock.consecutiveScrollTickIntervalMin
                    var tick = scrollAnalysisResult.timeBetweenTicks
                    
                    if tickStart > baseTimeStart {
                        tickStart = baseTimeStart
                        DDLogDebug("Scroll.swift: animation init - baseMsPerStepCurve - adjusting tickStart below consecutiveScrollTickIntervalMax to baseTimeStart: \(baseTimeStart)")
                        // assertionFailure()
                    }
                    
                    if tick == Double.greatestFiniteMagnitude {
                        tick = configCopyForBlock.consecutiveScrollTickIntervalMax
                    }
                    
                    if tick > configCopyForBlock.consecutiveScrollTickIntervalMax && tick != Double.greatestFiniteMagnitude {
                        DDLogError("Scroll.swift: animation init - tickTime is over max. This is a bug but we can recover. tickTime: \(tick)")
                        tick = configCopyForBlock.consecutiveScrollTickIntervalMax
                        // assertionFailure()
                    }
                    
                    let fromInterval = Interval(start: tickStart, end: tickEnd)
                    let unitTick = Math.scale(value: tick, from: fromInterval, to: Interval.unitInterval, allowOutOfBounds: true)
                    let clippedUnitTick = max(0.0, min(1.0, unitTick))
                    
                    let b = baseTimeCurve.evaluate(at: clippedUnitTick)
                    baseDuration = b / 1000.0
                    
                    DDLogDebug("Scroll.swift: animation init - baseMsPerStepCurve - calculating animation baseDuration - baseTimeEnd: \(baseTimeEnd), baseBaseTimeStart: \(baseTimeStart), tick: \(tick*1000), tickEnd: \(tickEnd*1000), tickStart: \(tickStart*1000), consecutiveScrollTickIntervalMax: \(configCopyForBlock.consecutiveScrollTickIntervalMax*1000), result: \(baseDuration*1000)")
                }
                
                var duration: Double = 0.0
                var c: Curve?
                
                if !pCurve.useDragCurve {
                    DDLogDebug("Scroll.swift: animation init – animation curve base")
                    c = pCurve.baseCurve
                    duration = baseDuration
                } else {
                    DDLogDebug("Scroll.swift: animation init – animation curve hybrid")
                    var baseCurve = pCurve.baseCurve
                    if baseCurve == nil {
                        let speedSmoothing = pCurve.speedSmoothing
                        assert(0.0 <= speedSmoothing && speedSmoothing <= 1.0)
                        
                        let baseCurveStartDirection = Vector(
                            x: 1.0 / (baseDuration / 1000.0),
                            y: magnitudeOfVector(currentSpeed) / delta
                        )
                        let baseCurveP1 = vectorFromDeltaAndDirectionVector(speedSmoothing, baseCurveStartDirection)
                        baseCurve = Bezier(controlPoints: [
                            CGPoint(x: 0, y: 0),
                            CGPoint(x: baseCurveP1.x, y: baseCurveP1.y),
                            CGPoint(x: 1, y: 1)
                        ], defaultEpsilon: 0.01)
                        
                        DDLogDebug("Scroll.swift: animation init - start speed smoothing p1 - currentSpeed: \(currentSpeed), bezier: \(baseCurve?.stringTrace(startX: 0, endX: 1, nOfSamples: 10, bias: 1) ?? "nil")")
                    }
                    
                    let hc = BezierHybridCurve(
                        baseCurve: baseCurve!,
                        minDuration: baseDuration,
                        distance: delta,
                        dragCoefficient: pCurve.dragCoefficient,
                        dragExponent: pCurve.dragExponent,
                        stopSpeed: Double(pCurve.stopSpeed),
                        distanceEpsilon: 0.2
                    )
                    
                    duration = hc.duration
                    assert(abs(hc.distance - delta) < 3)
                    DDLogDebug("Scroll.swift: animation init - Created hybrid curve with distance \(hc.distance), duration: \(hc.duration)")
                    c = hc
                }
                
                p["duration"] = duration
                p["vector"] = NSValue(point: vectorFromDeltaAndDirection(delta, finalScrollDirection))
                p["curve"] = c
                
                DDLogDebug("Scroll.swift: animation init - Returning value: \(p)")
                return p as NSDictionary
                
            }, integerCallback: { (distanceDeltaVec, animationPhase, momentumHint) in
                DDLogDebug("Scroll.swift: in-animator with vec: \(distanceDeltaVec), phase: \(animationPhase), momentum: \(momentumHint)")
                let distanceDelta = magnitudeOfVector(distanceDeltaVec)
                let config = configCopyForBlock
                
                assert(distanceDeltaVec.x == 0 || distanceDeltaVec.y == 0)
                if distanceDelta == 0 {
                    assert(animationPhase == kMFAnimationCallbackPhaseEnd || animationPhase == kMFAnimationCallbackPhaseCanceled)
                }
                
                sendScroll(px: Int64(distanceDelta), scrollDirection: finalScrollDirection, animated: true, animationPhase: animationPhase, momentumHint: momentumHint, config: config)
            })
        }
    }
    
    private enum MFScrollOutputType {
        case gestureScroll
        case continuousScroll
        case lineScroll
        case fourFingerPinch
        case threeFingerSwipeHorizontal
        case zoom
        case rotation
        case commandTab
    }
    
    private static func sendScroll(px: Int64, scrollDirection: MFDirection, animated: Bool, animationPhase: MFAnimationCallbackPhase, momentumHint: MFMomentumHint, config: ScrollConfig) {
        var dx: Int64 = 0
        var dy: Int64 = 0
        
        if scrollDirection == kMFDirectionUp {
            dy = px
        } else if scrollDirection == kMFDirectionDown {
            dy = -px
        } else if scrollDirection == kMFDirectionLeft {
            dx = -px
        } else if scrollDirection == kMFDirectionRight {
            dx = px
        } else if scrollDirection == kMFDirectionNone {
            // do nothing
        } else {
            assertionFailure()
        }
        
        var outputType: MFScrollOutputType
        if !animated {
            outputType = .lineScroll
        } else {
            if config.animationCurveParams?.sendGestureScrolls == true {
                outputType = .gestureScroll
            } else {
                outputType = .continuousScroll
            }
        }
        
        if _modifications.effectMod == kMFScrollEffectModificationZoom {
            outputType = .zoom
        } else if _modifications.effectMod == kMFScrollEffectModificationRotate {
            outputType = .rotation
        } else if _modifications.effectMod == kMFScrollEffectModificationFourFingerPinch {
            outputType = .fourFingerPinch
        } else if _modifications.effectMod == kMFScrollEffectModificationCommandTab {
            outputType = .commandTab
        } else if _modifications.effectMod == kMFScrollEffectModificationThreeFingerSwipeHorizontal {
            outputType = .threeFingerSwipeHorizontal
        }
        
        sendOutputEvents(dx: dx, dy: dy, outputType: outputType, animatorPhase: animationPhase, momentumHint: momentumHint, config: config)
    }
    
    private static func sendOutputEvents(dx: Int64, dy: Int64, outputType: MFScrollOutputType, animatorPhase: MFAnimationCallbackPhase, momentumHint: MFMomentumHint, config: ScrollConfig) {
        var eventPhase = IOHIDEventPhaseBits(kIOHIDEventPhaseUndefined)
        if animatorPhase != kMFAnimationCallbackPhaseNone {
            eventPhase = TouchAnimator.IOHIDPhase(animationCallbackPhase: animatorPhase)
        }
        
        if runningPreRelease() {
            struct StaticTime {
                static var lastTs: CFTimeInterval = 0.0
            }
            let ts = CACurrentMediaTime()
            let tsDiff = ts - StaticTime.lastTs
            StaticTime.lastTs = ts
            DDLogDebug("Scroll.swift: \nHNGG: Posting event from scrollwheel: dx: \(dx), dy: \(dy), outputType: \(outputType), phase: \(animatorPhase.rawValue), momentum: \(momentumHint.rawValue), time: \(Int(tsDiff * 1000))")
        }
        
        if dx + dy == 0 {
            assert(eventPhase == kIOHIDEventPhaseEnded || eventPhase == kIOHIDEventPhaseCancelled)
        }
        
        if outputType == .gestureScroll {
            if config.animationCurveParams?.sendMomentumScrolls == false {
                if eventPhase != IOHIDEventPhaseBits(kIOHIDEventPhaseEnded) {
                    GestureScrollSimulator.postGestureScrollEvent(withDeltaX: dx, deltaY: dy, phase: eventPhase, autoMomentumScroll: true, invertedFromDevice: _scrollConfig!.invertedFromDevice)
                } else {
                    GestureScrollSimulator.postGestureScrollEvent(withDeltaX: 0, deltaY: 0, phase: IOHIDEventPhaseBits(kIOHIDEventPhaseEnded), autoMomentumScroll: true, invertedFromDevice: _scrollConfig!.invertedFromDevice)
                    DDLogDebug("Scroll.swift: THAT CALL where displayLinkkk is stopped from Scroll.swift")
                    GestureScrollSimulator.stopMomentumScroll()
                }
            } else { // sendMomentumScrolls == true
                assert(momentumHint != kMFMomentumHintNone)
                
                struct StaticVars {
                    static var lastMomentumHint = kMFMomentumHintNone
                }
                
                if momentumHint == kMFMomentumHintGesture {
                    if StaticVars.lastMomentumHint == kMFMomentumHintMomentum {
                        GestureScrollSimulator.postMomentumScrollDirectly(withDeltaX: 0.0, deltaY: 0.0, momentumPhase: .end, invertedFromDevice: _scrollConfig!.invertedFromDevice)
                        eventPhase = IOHIDEventPhaseBits(kIOHIDEventPhaseBegan)
                        DDLogDebug("Scroll.swift: \nHybrid event - momentum: (0, 0, \(CGMomentumScrollPhase.end.rawValue)) JJJ")
                    }
                    
                    if eventPhase != IOHIDEventPhaseBits(kIOHIDEventPhaseEnded) {
                        GestureScrollSimulator.postGestureScrollEvent(withDeltaX: dx, deltaY: dy, phase: eventPhase, autoMomentumScroll: false, invertedFromDevice: _scrollConfig!.invertedFromDevice)
                    } else {
                        assert(eventPhase == IOHIDEventPhaseBits(kIOHIDEventPhaseEnded))
                        GestureScrollSimulator.postGestureScrollEvent(withDeltaX: 0, deltaY: 0, phase: IOHIDEventPhaseBits(kIOHIDEventPhaseMayBegin), autoMomentumScroll: false, invertedFromDevice: _scrollConfig!.invertedFromDevice)
                        GestureScrollSimulator.postGestureScrollEvent(withDeltaX: 0, deltaY: 0, phase: IOHIDEventPhaseBits(kIOHIDEventPhaseCancelled), autoMomentumScroll: false, invertedFromDevice: _scrollConfig!.invertedFromDevice)
                    }
                    
                    DDLogDebug("Scroll.swift: \nHybrid event - gesture: (\(dx), \(dy), \(eventPhase))")
                } else { // momentumHint is momentum
                    var momentumPhase: CGMomentumScrollPhase = .none
                    if StaticVars.lastMomentumHint == kMFMomentumHintGesture {
                        GestureScrollSimulator.postGestureScrollEvent(withDeltaX: 0, deltaY: 0, phase: IOHIDEventPhaseBits(kIOHIDEventPhaseEnded), autoMomentumScroll: false, invertedFromDevice: _scrollConfig!.invertedFromDevice)
                        momentumPhase = .begin
                        DDLogDebug("Scroll.swift: \nHybrid event - gesture: (0, 0, \(kIOHIDEventPhaseEnded)) HHH")
                    } else if StaticVars.lastMomentumHint == kMFMomentumHintMomentum {
                        if animatorPhase == kMFAnimationCallbackPhaseContinue {
                            momentumPhase = .continuous
                        } else if animatorPhase == kMFAnimationCallbackPhaseEnd || animatorPhase == kMFAnimationCallbackPhaseCanceled {
                            momentumPhase = .end
                        } else {
                            assertionFailure()
                            DDLogDebug("Scroll.swift: \nHybrid event - Assert fail >:(")
                        }
                    } else {
                        assertionFailure()
                    }
                    
                    GestureScrollSimulator.postMomentumScrollDirectly(withDeltaX: Double(dx), deltaY: Double(dy), momentumPhase: momentumPhase, invertedFromDevice: _scrollConfig!.invertedFromDevice)
                    
                    if animatorPhase == kMFAnimationCallbackPhaseEnd || animatorPhase == kMFAnimationCallbackPhaseCanceled {
                        GestureScrollSimulator.postGestureScrollEvent(withDeltaX: 0, deltaY: 0, phase: IOHIDEventPhaseBits(kIOHIDEventPhaseMayBegin), autoMomentumScroll: false, invertedFromDevice: _scrollConfig!.invertedFromDevice)
                        GestureScrollSimulator.postGestureScrollEvent(withDeltaX: 0, deltaY: 0, phase: IOHIDEventPhaseBits(kIOHIDEventPhaseCancelled), autoMomentumScroll: false, invertedFromDevice: _scrollConfig!.invertedFromDevice)
                    }
                    
                    DDLogDebug("Scroll.swift: \nHybrid event - momentum: (\(dx), \(dy), \(momentumPhase.rawValue))")
                }
                
                StaticVars.lastMomentumHint = momentumHint
                if animatorPhase == kMFAnimationCallbackPhaseEnd || animatorPhase == kMFAnimationCallbackPhaseCanceled {
                    DDLogDebug("Scroll.swift: HNGG reset lastMomentumHint")
                    StaticVars.lastMomentumHint = kMFMomentumHintNone
                }
            }
        } else if outputType == .continuousScroll {
            if dx + dy == 0 { return }
            
            guard let event = CGEvent(source: nil) else { return }
            event.setIntegerValueField(CGEventField(rawValue: 55)!, value: 22) // Set type to kCGEventScrollWheel
            event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
            
            struct StaticVars {
                static var linePixelator: VectorSubPixelator? = nil
            }
            if StaticVars.linePixelator == nil {
                StaticVars.linePixelator = VectorSubPixelator.biased()
            }
            if animatorPhase == kMFAnimationCallbackPhaseStart {
                StaticVars.linePixelator?.reset()
            }
            
            let dyLine = Double(dy) / 10.0
            let dxLine = Double(dx) / 10.0
            let pixelatedLines = StaticVars.linePixelator?.intVector(withDoubleVector: CGPoint(x: dxLine, y: dyLine)) ?? .zero
            
            event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: Int64(pixelatedLines.y))
            event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: dy)
            event.setIntegerValueField(.scrollWheelEventFixedPtDeltaAxis1, value: fixedScrollDelta(Double(pixelatedLines.y)))
            
            event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: Int64(pixelatedLines.x))
            event.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: dx)
            event.setIntegerValueField(.scrollWheelEventFixedPtDeltaAxis2, value: fixedScrollDelta(Double(pixelatedLines.x)))
            
            if runningPreRelease() {
                struct StaticTime {
                    static var tsStart: CFTimeInterval = 0
                }
                if animatorPhase == kMFAnimationCallbackPhaseStart {
                    StaticTime.tsStart = CACurrentMediaTime()
                }
                let ts = CACurrentMediaTime()
                let timeSinceStart = ts - StaticTime.tsStart
                DDLogDebug("Scroll.swift: \nHNGG: Posting continuousScroll event: \(scrollEventDescriptionWithOptions(event, true, false)), momentumHint: \(momentumHint.rawValue), time: \(Int(timeSinceStart * 1000))")
            }
            
            event.post(tap: .cgSessionEventTap)
            
        } else if outputType == .lineScroll {
            if dx + dy == 0 { return }
            
            guard let event = CGEvent(source: nil) else { return }
            event.setIntegerValueField(CGEventField(rawValue: 55)!, value: 22) // Set type to kCGEventScrollWheel
            
            let dyLine = Double(dy) / 10.0
            let dxLine = Double(dx) / 10.0
            
            var dyLineInt = Int64(dyLine)
            var dxLineInt = Int64(dxLine)
            
            if abs(dyLine) != 0 && dyLineInt == 0 { dyLineInt = Int64(mfsign(dyLine)) }
            if abs(dxLine) != 0 && dxLineInt == 0 { dxLineInt = Int64(mfsign(dxLine)) }
            
            let dyLineFixed = fixedScrollDelta(dyLine)
            let dxLineFixed = fixedScrollDelta(dxLine)
            
            event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: dyLineInt)
            event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: dy)
            event.setIntegerValueField(.scrollWheelEventFixedPtDeltaAxis1, value: dyLineFixed)
            
            event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: dxLineInt)
            event.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: dx)
            event.setIntegerValueField(.scrollWheelEventFixedPtDeltaAxis2, value: dxLineFixed)
            
            DDLogDebug("Scroll.swift: Posting lineScroll event – \(CGScrollWheelEventDescription(event))")
            event.post(tap: .cgSessionEventTap)
            
        } else if outputType == .zoom {
            var eventDelta = Double(dx + dy) / 800.0
            if eventPhase == kIOHIDEventPhaseBegan {
                if let bundleID = HelperUtility.appUnderMousePointer(with: nil)?.bundleIdentifier {
                    if bundleID.contains("com.google.Chrome")
                        || bundleID.contains("org.chromium.Chromium")
                        || bundleID.contains("company.thebrowser.Browser")
                        || bundleID.contains("com.operasoftware.Opera")
                        || bundleID.contains("com.microsoft.edgemac")
                        || bundleID.contains("com.vivaldi.Vivaldi")
                        || bundleID.contains("com.brave.Browser") {
                        TouchSimulator.postMagnificationEvent(withMagnification: eventDelta, phase: IOHIDEventPhaseBits(kIOHIDEventPhaseBegan))
                        eventPhase = IOHIDEventPhaseBits(kIOHIDEventPhaseChanged)
                        assert(eventDelta != 0)
                        if mfsign(eventDelta) > 0 {
                            eventDelta += 380.0 / 800.0
                        } else {
                            eventDelta -= 250.0 / 800.0
                        }
                    }
                }
            }
            
            TouchSimulator.postMagnificationEvent(withMagnification: eventDelta, phase: eventPhase)
            
        } else if outputType == .rotation {
            let eventDelta = Double(dx + dy) / 8.0
            TouchSimulator.postRotationEvent(withRotation: eventDelta, phase: eventPhase)
            
        } else if outputType == .fourFingerPinch || outputType == .threeFingerSwipeHorizontal {
            let type: MFDockSwipeType
            let eventDelta: Double
            
            if outputType == .fourFingerPinch {
                type = kMFDockSwipeTypePinch
                eventDelta = -Double(dx + dy) / 600.0
            } else {
                type = kMFDockSwipeTypeHorizontal
                eventDelta = -Double(dx + dy) / 600.0
            }
            
            TouchSimulator.postDockSwipeEvent(withDelta: eventDelta, type: type, phase: eventPhase, invertedFromDevice: _scrollConfig!.invertedFromDevice)
            
        } else if outputType == .commandTab {
            let d = -Double(dx + dy)
            if d == 0 { return }
            
            struct StaticVars {
                static var appSwitcherWasOpenedByCurrentConsecutiveTicks = false
            }
            
            let isFirstConsecutive = (_lastScrollAnalysisResult.consecutiveScrollTickCounter == 0)
            
            if !_appSwitcherIsOpen {
                sendKeyEvent(keyCode: 55, flags: .maskCommand, keyDown: true)
                sendKeyEvent(keyCode: 48, flags: .maskCommand, keyDown: true)
                sendKeyEvent(keyCode: 48, flags: .maskCommand, keyDown: false)
                _appSwitcherIsOpen = true
                StaticVars.appSwitcherWasOpenedByCurrentConsecutiveTicks = true
            } else {
                if isFirstConsecutive {
                    StaticVars.appSwitcherWasOpenedByCurrentConsecutiveTicks = false
                }
            }
            
            if !StaticVars.appSwitcherWasOpenedByCurrentConsecutiveTicks {
                if d > 0 {
                    sendKeyEvent(keyCode: 48, flags: .maskCommand, keyDown: true)
                    sendKeyEvent(keyCode: 48, flags: .maskCommand, keyDown: false)
                } else {
                    sendKeyEvent(keyCode: 48, flags: [.maskCommand, .maskShift], keyDown: true)
                    sendKeyEvent(keyCode: 48, flags: [.maskCommand, .maskShift], keyDown: false)
                }
            }
        }
    }
    
    @objc public static func appSwitcherModificationHasBeenDeactivated() {
        if _appSwitcherIsOpen {
            sendKeyEvent(keyCode: 55, flags: [], keyDown: false)
            _appSwitcherIsOpen = false
        }
    }
    
    private static func sendKeyEvent(keyCode: CGKeyCode, flags: CGEventFlags, keyDown: Bool) {
        if let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: keyDown) {
            event.flags = flags
            event.post(tap: .cgSessionEventTap)
        }
    }
}

#endif
