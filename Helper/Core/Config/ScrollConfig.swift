//
// --------------------------------------------------------------------------
// ScrollConfig.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

import Cocoa
import CocoaLumberjackSwift

@objc class ScrollConfig: NSObject, NSCopying /*, NSCoding*/ {
    
    /// This class has almost all instance properties
    /// You can request the config once, then store it.
    /// You'll receive an independent instance that you can override with custom values. This should be useful for implementing Modifications in Scroll.m
    ///     Everything in ScrollConfigResult is lazy so that you only pay for what you actually use
    ///  Edit: Since we're always copying the scrollConfig before returning to apply some overrides, all this lazyness is sort of useless I think. Because during copy, all the lazy computed properties will be calculated from what I've seen. But this will only happen during the first copy, so it's whatever.
    
    // MARK: Convenience functions
    ///     For accessing top level dict and different sub-dicts
    
    private static var _scrollConfigRaw: NSDictionary? = nil /// This needs to be static, not an instance var. Otherwise there are weird crashes in Scroll.m. Not sure why.
    private func c(_ keyPath: String) -> NSObject? {
        return ScrollConfig._scrollConfigRaw?.object(forCoolKeyPath: keyPath) /// Not sure whether to use coolKeyPath here?
    }
    
    // MARK: Static functions
    
    @objc private(set) static var shared = ScrollConfig() /// Singleton instance
    
    @objc static func reload() {
        
        /// Guard not equal
        
        let newConfigRaw = config("Scroll") as! NSDictionary?
        guard !(_scrollConfigRaw?.isEqual(newConfigRaw) ?? false) else {
            return
        }
        
        /// Notes:
        /// - This should be called when the underlying config (which mirrors the config file) changes
        /// - All the property values are cached in `currentConfig`, because the properties are lazy. Replacing with a fresh object deletes this implicit cache.
        /// - TODO: Make a copy before storing in `_scrollConfigRaw` just to be sure the equality checks always work
        shared = ScrollConfig()
        _scrollConfigRaw = newConfigRaw
        cache = nil
//        ReactiveScrollConfig.shared.handleScrollConfigChanged(newValue: shared)
        SwitchMaster.shared.scrollConfigChanged(scrollConfig: shared)
    }
    private static var cache: [_HT<MFScrollModificationResult, MFAxis, CGDirectDisplayID>: ScrollConfig]? = nil
    
    // MARK: Overrides
    
    @objc static func scrollConfig(modifiers: MFScrollModificationResult, inputAxis: MFAxis, display: CGDirectDisplayID) -> ScrollConfig {
        
        /// Try to get result from cache
        
        if cache == nil {
            cache = .init()
        }
        let key = _HT(a: modifiers, b: inputAxis, c: display)
        
        if let fromCache = cache![key] {
            return fromCache

        } else {
            
            /// Cache retrieval failed -> Recalculate result
            
            /// Copy og settings
            let new = shared.copy() as! ScrollConfig
            
            /// Declare overridables
            var precise = new.u_precise
            var useQuickMod = modifiers.inputMod == kMFScrollInputModificationQuick
            var usePreciseMod = modifiers.inputMod == kMFScrollInputModificationPrecise
            var scaleToDisplay = true
            var animationCurveOverride: MFScrollAnimationCurveName? = nil
            
            ///
            /// Override settings
            ///
            
            /// 1. effectModifications
            if modifiers.effectMod == kMFScrollEffectModificationHorizontalScroll {
                
                
            } else if modifiers.effectMod == kMFScrollEffectModificationZoom {
                
                /// Override animation curve
                animationCurveOverride = kMFScrollAnimationCurveNameTouchDriver
                
                /// Adjust speed params
                scaleToDisplay = false
                
            } else if modifiers.effectMod == kMFScrollEffectModificationRotate {
                
                /// Override animation curve
                animationCurveOverride = kMFScrollAnimationCurveNameTouchDriver
                
                /// Adjust speed params
                scaleToDisplay = false
                
            } else if modifiers.effectMod == kMFScrollEffectModificationCommandTab {
                
                /// Disable animation
                animationCurveOverride = kMFScrollAnimationCurveNameNone
                
            } else if modifiers.effectMod == kMFScrollEffectModificationThreeFingerSwipeHorizontal {
                
                /// Override animation curve
                animationCurveOverride = kMFScrollAnimationCurveNameTouchDriverLinear;
                
                /// Adjust speed params
                precise = false
                scaleToDisplay = false
                
                /// Turn off inputMods
                useQuickMod = false
                usePreciseMod = false
                
                /// Disable speedup
                new.fastScrollCurve = nil
                
            } else if modifiers.effectMod == kMFScrollEffectModificationFourFingerPinch {
                
                /// Override animation curve
                animationCurveOverride = kMFScrollAnimationCurveNameTouchDriverLinear;
                
                /// Adjust speed params
                precise = false
                scaleToDisplay = false
                
                /// Turn off inputMods
                useQuickMod = false
                usePreciseMod = false
                
                /// Disable speedup
                new.fastScrollCurve = nil
                
            } else if modifiers.effectMod == kMFScrollEffectModificationNone {
            } else if modifiers.effectMod == kMFScrollEffectModificationAddModeFeedback {
                /// We don't wanna scroll at all in this case but I don't think it makes a difference.
            } else {
                assert(false);
            }
            
            /// 2. inputModifications
            
            if useQuickMod {
                
                /// Set animationCurve
                /// - Only do this if the effectMods haven't set their own curve already. That way effectMod animationCurves override quickMod animationCurve. We want this because the quickMod curve can be super long and inertial which feels really bad if you're e.g. trying to zoom.
                /// - Idea: If we only send the effects while the animationCurve is in the gesturePhase we might not need this? But the gesture phase curve is just linear which would feel non-so-smooth.
                /// - Should we also do this for preciseMod? If we use the linear touchDriver curve and then override it with the eased-out preciseMod curve that might not be what we want. But I think wherever we use the linear touchDriver curve we ignore preciseMod and QuickMod anyways
                
                if animationCurveOverride == nil {
                    animationCurveOverride = kMFScrollAnimationCurveNameQuickScroll
                }
                
                /// Adjust speed params
                precise = false
                scaleToDisplay = false /// Is scaled to windowSize instead
                
                /// Make fastScroll easier to trigger
                new.consecutiveScrollSwipeMaxInterval = 725.0/1000.0
                new.consecutiveScrollTickIntervalMax = 200.0/1000.0
                new.consecutiveScrollSwipeMinTickSpeed = 12.0
                
                /// Amp-up fastScroll
                new.fastScrollCurve = ScrollSpeedupCurve(swipeThreshold: 1, initialSpeedup: 2.0, exponentialSpeedup: 10)
                
            } else if usePreciseMod {
                
                /// Set animationCurve
                /// The idea is that:
                /// - inputMods may only override effectMod animationCurve overrides, if that shortens the animation. Because you don't want long animations during scroll-to-zoom, scroll-to-reveal-desktop, etc.
                /// - The precise input mod should never turn on smoothScrolling.
                if (animationCurveOverride == nil && new.animationCurve != kMFScrollAnimationCurveNameNone)
                    || (animationCurveOverride != nil && animationCurveOverride != kMFScrollAnimationCurveNameNone) {
                    
                    animationCurveOverride = kMFScrollAnimationCurveNamePreciseScroll
                }
                
                /// Adjust speed params
                precise = false
                scaleToDisplay = false
                
                /// Turn off fast scroll
                new.fastScrollCurve = nil
            }
            
            /// Apply animationCurve override
            if let ovr = animationCurveOverride {
                new.animationCurve = ovr
            }
            
            /// Get accelerationCurve
            if new.u_speed == kMFScrollSpeedSystem && !usePreciseMod && !useQuickMod {
                new.accelerationCurve = nil
            } else {
                new.accelerationCurve = getAccelerationCurve(forSpeed: new.u_speed, precise: precise, smoothness: new.u_smoothness, animationCurve: new.animationCurve, inputAxis: inputAxis, display: display, scaleToDisplay: scaleToDisplay, modifiers: modifiers, useQuickModSpeed: useQuickMod, usePreciseModSpeed: usePreciseMod, consecutiveScrollTickIntervalMax: new.consecutiveScrollTickIntervalMax, consecutiveScrollTickInterval_AccelerationEnd: new.consecutiveScrollTickInterval_AccelerationEnd)
            }
            
            /// Cache & return
            cache![key] = new
            return new
            
        }
    }
    
    // MARK: ???
    
    @objc static var linearCurve: Bezier = { () -> Bezier in
        
        let controlPoints: [P] = [_P(0,0), _P(0,0), _P(1,1), _P(1,1)]
        
        return Bezier(controlPoints: controlPoints, defaultEpsilon: 0.001) /// The default defaultEpsilon 0.08 makes the animations choppy
    }()
    
//    @objc static var stringToEventFlagMask: NSDictionary = ["command" : CGEventFlags.maskCommand,
//                                                            "control" : CGEventFlags.maskControl,
//                                                            "option" : CGEventFlags.maskAlternate,
//                                                            "shift" : CGEventFlags.maskShift]
    
    // MARK: Derived
    /// For convenience I guess? Should probably remove these
    
    
    @objc var smoothEnabled: Bool {
        /// Does this really have to exist?
        return _animationCurveName != kMFScrollAnimationCurveNameNone
    }
    @objc var useAppleAcceleration: Bool {
        return accelerationCurve == nil
    }
    
    // MARK: Invert Direction
    
    @objc lazy var u_invertDirection: MFScrollInversion = {
        /// This can be used as a factor to invert things. kMFScrollInversionInverted is -1.
        
//        if HelperState.isLockedDown { return kMFScrollInversionNonInverted }
        return c("reverseDirection") as! Bool ? kMFScrollInversionInverted : kMFScrollInversionNonInverted
    }()
    
    // MARK: Old Invert Direction
    /// Rationale: We used to have the user setting be "Natural Direction" but we changed it to being "Reverse Direction". This is so it's more transparent to the user when Mac Mouse Fix is intercepting the scroll input and also to have the SwitchMaster more easily decide when to turn the scrolling tap on or off. Also I think the setting is slightly more intuitive this way.
    
//    @objc func scrollInvert(event: CGEvent) -> MFScrollInversion {
//        /// This can be used as a factor to invert things. kMFScrollInversionInverted is -1.
//
//        if HelperState.isLockedDown { return kMFScrollInversionNonInverted }
//
//        if self.u_direction == self.semanticScrollInvertSystem(event) {
//            return kMFScrollInversionNonInverted
//        } else {
//            return kMFScrollInversionInverted
//        }
//    }
    
//    lazy private var u_direction: MFSemanticScrollInversion = {
//        c("naturalDirection") as! Bool ? kMFSemanticScrollInversionNatural : kMFSemanticScrollInversionNormal
//    }()
//    private func semanticScrollInvertSystem(_ event: CGEvent) -> MFSemanticScrollInversion {
//
//        /// Accessing userDefaults is actually surprisingly slow, so we're using NSEvent.isDirectionInvertedFromDevice instead... but NSEvent(cgEvent:) is slow as well...
//        ///     .... So we're using our advanced knowledge of CGEventFields!!!
//
////            let isNatural = UserDefaults.standard.bool(forKey: "com.apple.swipescrolldirection") /// User defaults method
////            let isNatural = NSEvent(cgEvent: event)!.isDirectionInvertedFromDevice /// NSEvent method
//        let isNatural = event.getIntegerValueField(CGEventField(rawValue: 137)!) != 0; /// CGEvent method
//
//        return isNatural ? kMFSemanticScrollInversionNatural : kMFSemanticScrollInversionNormal
//    }
    
    // MARK: Inverted from device flag
    /// This flag will be set on GestureScroll events and will invert some interactions like scrolling to delete messages in Mail
    
    @objc let invertedFromDevice = false;
    
    // MARK: Analysis
    
    @objc lazy var scrollSwipeThreshold_inTicks: Int = 2 /*other["scrollSwipeThreshold_inTicks"] as! Int;*/ /// If `scrollSwipeThreshold_inTicks` consecutive ticks occur, they are deemed a scroll-swipe.
    
    @objc lazy var scrollSwipeMax_inTicks: Int = 11 /// Max number of ticks that we think can occur in a single swipe naturally (if the user isn't using a free-spinning scrollwheel). (See `consecutiveScrollSwipeCounter_ForFreeScrollWheel` definition for more info)
    
    @objc lazy var consecutiveScrollTickIntervalMax: TimeInterval = 160/1000
    /// ^ If more than `_consecutiveScrollTickIntervalMax` seconds passes between two scrollwheel ticks, then they aren't deemed consecutive.
    ///        other["consecutiveScrollTickIntervalMax"] as! Double;
    ///     msPerStep/1000 <- Good idea but we don't want this to depend on msPerStep
    
    @objc lazy var consecutiveScrollTickIntervalMin: TimeInterval = 15/1000
    /// ^ 15ms seemst to be smallest scrollTickInterval that you can naturally produce. But when performance drops, the scrollTickIntervals that we see can be much smaller sometimes.
    ///     This variable can be used to cap the observed scrollTickInterval to a reasonable value
    
    
    @objc lazy var consecutiveScrollSwipeMaxInterval: TimeInterval = {
        /// If more than `_consecutiveScrollSwipeIntervalMax` seconds passes between two scrollwheel swipes, then they aren't deemed consecutive.
        
        let result = SharedUtilitySwift.eval {
            
            switch animationCurve {
            case kMFScrollAnimationCurveNameNone: 325.0
            case kMFScrollAnimationCurveNameLowInertia: 375.0
            case kMFScrollAnimationCurveNameHighInertia, kMFScrollAnimationCurveNameHighInertiaPlusTrackpadSim: 600.0
            case kMFScrollAnimationCurveNameTouchDriver, kMFScrollAnimationCurveNameTouchDriverLinear: 375.0
            case kMFScrollAnimationCurveNamePreciseScroll, kMFScrollAnimationCurveNameQuickScroll: 0.1234 /// Will be overriden
            default: -1.0
            }
        }
        assert(result != -1.0)
        return result/1000.0
    }()
    
    @objc lazy var consecutiveScrollSwipeMinTickSpeed: Double = {
        /// The ticks per second need to be at least `consecutiveScrollSwipeMinTickSpeed` to register a series of scrollswipes as consecutive
        
        let result = SharedUtilitySwift.eval {
            switch animationCurve {
            case kMFScrollAnimationCurveNameNone: 16.0
            case kMFScrollAnimationCurveNameLowInertia: 16.0
            case kMFScrollAnimationCurveNameHighInertia, kMFScrollAnimationCurveNameHighInertiaPlusTrackpadSim: 12.0
            case kMFScrollAnimationCurveNameTouchDriver, kMFScrollAnimationCurveNameTouchDriverLinear: 16.0
            case kMFScrollAnimationCurveNamePreciseScroll, kMFScrollAnimationCurveNameQuickScroll: 0.1234 /// Will be overriden
            default: -1.0
            }
        }
        assert(result != -1.0)
        return result
    }()
    
    @objc lazy private var consecutiveScrollTickInterval_AccelerationEnd: TimeInterval = consecutiveScrollTickIntervalMin
    /// ^ Used to define accelerationCurve. If the time interval between two ticks becomes less than `consecutiveScrollTickInterval_AccelerationEnd` seconds, then the accelerationCurve becomes managed by linear extension of the bezier instead of the bezier directly.
    
    /// Note: We are just using RollingAverge for smoothing, not ExponentialSmoothing, so this is currently unused.
    @objc lazy var ticksPerSecond_DoubleExponentialSmoothing_InputValueWeight: Double = 0.5
    @objc lazy var ticksPerSecond_DoubleExponentialSmoothing_TrendWeight: Double = 0.2
    @objc lazy var ticksPerSecond_ExponentialSmoothing_InputValueWeight: Double = 0.5
    /// ^       1.0 -> Turns off smoothing. I like this the best
    ///     0.6 -> On larger swipes this counteracts acceleration and it's unsatisfying. Not sure if placebo
    ///     0.8 ->  Nice, light smoothing. Makes  scrolling slightly less direct. Not sure if placebo.
    ///     0.5 -> (Edit) I prefer smoother feel now in everything. 0.5 Makes short scroll swipes less accelerated which I like
    
    // MARK: Fast scroll
    
    
    @objc lazy var fastScrollCurve: ScrollSpeedupCurve? = {
        
        /// NOTES:
        /// - We're using swipeThreshold to configure how far the user must've scrolled before fastScroll starts kicking in.
        /// - It would probably be better to have an explicit mechanism that counts how many pixels the user has scrolled already and then lets fastScroll kick in after a threshold is reached. That would also scale with the scrollSpeed setting. These current `fastScrollSpeedup` values are chosen so you don't accidentally trigger it at the lowest scrollSpeed, but they could be higher at higher scrollspeeds.
        /// - Fastscroll starts kicking in on the `swipeThreshold + 1` th scrollSwipe
        ///
        /// On how we chose parameters:
        /// - The `swipeThreshold` was chosen proportional to the max stepSize of the lowest scrollspeed setting of the respective animationCurve.
        /// - The `exponentialSpeedup` of the unanimated ScrollSpeedCurve is lower and the `initialSpeedup` is higher because without animation you quickly reach a speed where you can't tell how far or in which direction you scrolled. We want to have a few swipes in that window of speed where you can tell that it's speeding up but it's not yet so fast that you can't tell which direction you scrolled and how fast.
        
        
        switch animationCurve {
            
        case kMFScrollAnimationCurveNameNone:
            return ScrollSpeedupCurve(swipeThreshold: 6, initialSpeedup: 1.4, exponentialSpeedup: 3.0)
            
        case kMFScrollAnimationCurveNameLowInertia:
            return ScrollSpeedupCurve(swipeThreshold: 3, initialSpeedup: 1.33, exponentialSpeedup: 7.5)
            
        case kMFScrollAnimationCurveNameHighInertia, kMFScrollAnimationCurveNameHighInertiaPlusTrackpadSim:
            return ScrollSpeedupCurve(swipeThreshold: 2, initialSpeedup: 1.33, exponentialSpeedup: 7.5)
            
        case kMFScrollAnimationCurveNameTouchDriver, kMFScrollAnimationCurveNameTouchDriverLinear:
            return ScrollSpeedupCurve(swipeThreshold: 3, initialSpeedup: 1.33, exponentialSpeedup: 7.5)
            
        case kMFScrollAnimationCurveNamePreciseScroll, kMFScrollAnimationCurveNameQuickScroll:
            return nil as ScrollSpeedupCurve? /// Will be overriden
        
        default:
            assert(false)
            return nil as ScrollSpeedupCurve?
        }
    }()
    
    // MARK: Animation curve
    
    /// User setting
    
    private lazy var u_smoothness: MFScrollSmoothness = {
        switch c("smooth") as! String {
        case "off": return kMFScrollSmoothnessOff
        case "regular": return kMFScrollSmoothnessRegular
        case "high": return kMFScrollSmoothnessHigh
        default: fatalError()
        }
    }()
    private lazy var u_trackpadSimulation: Bool = {
        return c("trackpadSimulation") as! Bool
    }()
    
    private lazy var _animationCurveName = {
        
        /// Maybe we should move the trackpad sim settings out of the MFScrollAnimationCurveName, (because that's weird?)
        
        switch u_smoothness {
        case kMFScrollSmoothnessOff: return kMFScrollAnimationCurveNameNone
        case kMFScrollSmoothnessRegular: return kMFScrollAnimationCurveNameLowInertia
        case kMFScrollSmoothnessHigh:
            return u_trackpadSimulation ? kMFScrollAnimationCurveNameHighInertiaPlusTrackpadSim : kMFScrollAnimationCurveNameHighInertia
        default: fatalError()
        }
    }()
    
    @objc var animationCurve: MFScrollAnimationCurveName {
        
        set {
            _animationCurveName = newValue
            self.animationCurveParams = animationCurveParamsMap(name: animationCurve)
        } get {
            return _animationCurveName
        }
    }
    
    @objc private(set) lazy var animationCurveParams: MFScrollAnimationCurveParameters? = { animationCurveParamsMap(name: animationCurve) }() /// Updates automatically to match `self.animationCurveName
    
    // MARK: Acceleration
    
    /// User settings
    
    @objc lazy var u_speed: MFScrollSpeed = {
        switch c("speed") as! String {
        case "system": return kMFScrollSpeedSystem /// Ignore MMF acceleration algorithm and use values provided by macOS
        case "low": return kMFScrollSpeedLow
        case "medium": return kMFScrollSpeedMedium
        case "high": return kMFScrollSpeedHigh
        default: fatalError()
        }
    }()
    @objc lazy var u_precise: Bool = { c("precise") as! Bool }()
    
    /// Stored property
    ///     This is used by Scroll.m to determine how to accelerate
    
    @objc lazy var accelerationCurve: Curve? = nil /// Initial value is unused I think. Will always be overriden before it's used anywhere
    
    // MARK: Keyboard modifiers
    
    /// Event flag masks
    @objc lazy var horizontalModifiers = CGEventFlags(rawValue: c("modifiers.horizontal") as! UInt64)
    @objc lazy var zoomModifiers = CGEventFlags(rawValue: c("modifiers.zoom") as! UInt64)
    
    @objc func copy(with zone: NSZone? = nil) -> Any {
        
        return SharedUtilitySwift.shallowCopy(ofObject: self)
    }
    
}

// MARK: - Helper stuff

/// Storage class for animationCurve params

@objc class MFScrollAnimationCurveParameters: NSObject {
    
    /// Notes:
    /// - I don't really think it make sense for sendGestureScrolls and sendMomentumScrolls to be part of the animation curve, but it works so whatever
    
    /// baseCurve params
    @objc let baseCurve: Bezier?
    @objc let baseMsPerStep: Int /// When using dragCurve that will make the actual msPerStep longer
    /// dragCurve params
    @objc let useDragCurve: Bool /// If false, use only baseCurve, and ignore dragCurve
    @objc let dragExponent: Double
    @objc let dragCoefficient: Double
    @objc let stopSpeed: Int
    /// Other params
    @objc let sendGestureScrolls: Bool /// If false, send simple continuous scroll events (like MMF 2) instead of using GestureScrollSimulator
    @objc let sendMomentumScrolls: Bool /// Only works if sendGestureScrolls and useDragCurve is true. If true, make Scroll.m send momentumScroll events (what the Apple Trackpad sends after lifting your fingers off) when scrolling is controlled by the dragCurve (and in some other cases, see TouchAnimator). Only use this when the dragCurve closely mimicks the Apple Trackpads otherwise apps like Xcode will behave differently from other apps during momentum scrolling.
    
    /// Init
    init(baseCurve: Bezier?, baseMsPerStep: Int, dragExponent: Double, dragCoefficient: Double, stopSpeed: Int, sendGestureScrolls: Bool, sendMomentumScrolls: Bool) {
        
        /// Init for using hybridCurve (baseCurve + dragCurve)
        
        if sendMomentumScrolls { assert(sendGestureScrolls) }
        
        self.baseMsPerStep = baseMsPerStep
        self.baseCurve = baseCurve
        
        self.useDragCurve = true
        self.dragExponent = dragExponent
        self.dragCoefficient = dragCoefficient
        self.stopSpeed = stopSpeed
        
        self.sendGestureScrolls = sendGestureScrolls
        self.sendMomentumScrolls = sendMomentumScrolls
    }
    init(baseCurve: Bezier?, msPerStep: Int, sendGestureScrolls: Bool) {
        
        /// Init for using just baseCurve
        
        self.baseMsPerStep = msPerStep
        self.baseCurve = baseCurve
        
        self.useDragCurve = false
        self.dragExponent = -1
        self.dragCoefficient = -1
        self.stopSpeed = -1
        
        self.sendGestureScrolls = sendGestureScrolls
        self.sendMomentumScrolls = false
    }
}

fileprivate func animationCurveParamsMap(name: MFScrollAnimationCurveName) -> MFScrollAnimationCurveParameters? {
    
    /// Map from animationCurveName -> animationCurveParams
    /// For the origin behind these curves see ScrollConfigTesting.md
    /// @note I just checked the formulas on Desmos, and I don't get how this can work with 0.7 as the exponent? (But it does??) If the value is `< 1.0` that gives a completely different curve that speeds up over time, instead of slowing down.
    
    switch name {
        
    /// --- User selected ---
        
    case kMFScrollAnimationCurveNameNone:
        
        return nil
        
    case kMFScrollAnimationCurveNameNoInertia:
        
        fatalError()
        
        let baseCurve =
        Bezier(controlPoints: [_P(0, 0), _P(0, 0), _P(0.66, 1), _P(1, 1)], defaultEpsilon: 0.001)
//            Bezier(controlPoints: [_P(0, 0), _P(0.31, 0.44), _P(0.66, 1), _P(1, 1)], defaultEpsilon: 0.001)
//            ScrollConfig.linearCurve
//            Bezier(controlPoints: [_P(0, 0), _P(0.23, 0.89), _P(0.52, 1), _P(1, 1)], defaultEpsilon: 0.001)
        return MFScrollAnimationCurveParameters(baseCurve: baseCurve, msPerStep: 250, sendGestureScrolls: false)
        
    case kMFScrollAnimationCurveNameLowInertia:
        
        return MFScrollAnimationCurveParameters(baseCurve: ScrollConfig.linearCurve, baseMsPerStep: 140, dragExponent: 1.05, dragCoefficient: 15, stopSpeed: 30, sendGestureScrolls: false, sendMomentumScrolls: false)
        
    case kMFScrollAnimationCurveNameMediumInertia:
        
        fatalError()
        
        return MFScrollAnimationCurveParameters(baseCurve: ScrollConfig.linearCurve, baseMsPerStep: 200, dragExponent: 1.05, dragCoefficient: 15, stopSpeed: 30, sendGestureScrolls: false, sendMomentumScrolls: false)
        
        return MFScrollAnimationCurveParameters(baseCurve: ScrollConfig.linearCurve, baseMsPerStep: 190, dragExponent: 1.0, dragCoefficient: 17, stopSpeed: 50, sendGestureScrolls: false, sendMomentumScrolls: false)
        
    case kMFScrollAnimationCurveNameHighInertia:
        /// - Snappiest curve that can be used to send momentumScrolls.
        ///    If you make it snappier then it will cut off the built-in momentumScroll in apps like Xcode
        /// - We tried setting baseMsPerStep 205 -> 240, which lets medium scroll speed look slightly smoother since you can't tell the ticks apart, but it takes longer until text becomes readable again so I think I like it less.
        return MFScrollAnimationCurveParameters(baseCurve: ScrollConfig.linearCurve, baseMsPerStep: 205/*240*/, dragExponent: 0.7, dragCoefficient: 40, stopSpeed: /*50*/30, sendGestureScrolls: false, sendMomentumScrolls: false)
        
    case kMFScrollAnimationCurveNameHighInertiaPlusTrackpadSim:
        /// Same as highInertia curve but with full trackpad simulation. The trackpad sim stuff doesn't really belong here I think.
        return MFScrollAnimationCurveParameters(baseCurve: ScrollConfig.linearCurve, baseMsPerStep: 205/*240*/, dragExponent: 0.7, dragCoefficient: 40, stopSpeed: /*50*/30, sendGestureScrolls: true, sendMomentumScrolls: true)
        
    /// --- Dynamically applied ---
        
    case kMFScrollAnimationCurveNameTouchDriver:

        /// v Note: At the time of writing, this curve is equivalent to a BezierCappedAccelerationCurve with curvature 1.
        let baseCurve = Bezier(controlPoints: [_P(0, 0), _P(0, 0), _P(0.5, 1), _P(1, 1)], defaultEpsilon: 0.001)
        return MFScrollAnimationCurveParameters(baseCurve: baseCurve, msPerStep: /*225*/250/*275*/, sendGestureScrolls: false)
        
    case kMFScrollAnimationCurveNameTouchDriverLinear:
        
        return MFScrollAnimationCurveParameters(baseCurve: ScrollConfig.linearCurve, msPerStep: 180/*200*/, sendGestureScrolls: false)
    
    case kMFScrollAnimationCurveNameQuickScroll:
        
        /// - Almost the same as `highInertia` just more inertial. Actually same feel as trackpad-like parameters used in `GestureScrollSimulator` for autoMomentumScroll.
        /// - Should we use trackpad sim (sendMomentumScrolls and sendGestureScrolls) here?
        return MFScrollAnimationCurveParameters(baseCurve: ScrollConfig.linearCurve, baseMsPerStep: /*220*/300, dragExponent: 0.7, dragCoefficient: 30, stopSpeed: 1, sendGestureScrolls: true, sendMomentumScrolls: true)
        
    case kMFScrollAnimationCurveNamePreciseScroll:
        
        /// Similar to `lowInertia`
//        return MFScrollAnimationCurveParameters(baseCurve: ScrollConfig.linearCurve, baseMsPerStep: 140, dragExponent: 1.0, dragCoefficient: 20, stopSpeed: 50, sendGestureScrolls: false, sendMomentumScrolls: false)
        return MFScrollAnimationCurveParameters(baseCurve: ScrollConfig.linearCurve, baseMsPerStep: 140, dragExponent: 1.05, dragCoefficient: 15, stopSpeed: 50, sendGestureScrolls: false, sendMomentumScrolls: false)
        
    /// --- Testing ---
        
    case kMFScrollAnimationCurveNameTest:
        
        return MFScrollAnimationCurveParameters(baseCurve: ScrollConfig.linearCurve, msPerStep: 350, sendGestureScrolls: false)
        
    /// --- Other ---
    
    default:
        fatalError()
    }
}

/// Define function that maps userSettings -> accelerationCurve
fileprivate func getAccelerationCurve(forSpeed speedArg: MFScrollSpeed, precise: Bool, smoothness: MFScrollSmoothness, animationCurve: MFScrollAnimationCurveName, inputAxis: MFAxis, display: CGDirectDisplayID, scaleToDisplay: Bool, modifiers: MFScrollModificationResult, useQuickModSpeed: Bool, usePreciseModSpeed: Bool, consecutiveScrollTickIntervalMax: Double, consecutiveScrollTickInterval_AccelerationEnd: Double) -> Curve {
    
    /// Notes:
    /// - The inputs to the curve can sometimes be ridiculously high despite smoothing, because our time measurements of when ticks occur are very imprecise
    ///     - Edit: Not sure this is still true since we switched to using CGEvent timestamps instead of CACurrentMediaTime() time at some point. I think we also made some changes so the timeBetweenTicks is always reported to be at least `consecutiveScrollTickIntervalMin` or `consecutiveScrollTickInterval_AccelerationEnd`, which would mean we don't have to worry about this here.
    /// - `_n` stands for 'normalized', so the value is between 0.0 and 1.0
    /// - Before we used the `BezierCappedAccelerationCurve` we used `capHump` / `accelerationHump` curvature system. The last commit with that system (commented out) is 1304067385a0e77ed1c095e39b8fa2ae37b9bde4
    
    /**
     General thoughts on BezierCappedAccelerationCurve:
      Define a curve describing the relationship between the inputSpeed (in scrollwheel ticks per second) (on the x-axis) and the sensitivity (In pixels per tick) (on the y-axis).
      We'll call this function y(x).
      y(x) is composed of 3 other curves. The core of y(x) is a BezierCurve *b(x)*, which is defined on the interval (xMin, xMax).
      y(xMin) is called yMin and y(xMax) is called yMax
      There are two other components to y(x):
      - For `x < xMin`, we set y(x) to yMin
      - We do this so that the acceleration is turned off for tickSpeeds below xMin. Acceleration should only affect scrollTicks that feel 'consecutive' and not ones that feel like singular events unrelated to other scrollTicks. `self.consecutiveScrollTickIntervalMax` is (supposed to be) the maximum time between ticks where they feel consecutive. So we're using it to define xMin.
      - For `xMax < x`, we lineraly extrapolate b(x), such that the extrapolated line has the slope b'(xMax) and passes through (xMax, yMax)
      - We do this so the curve is defined and has reasonable values even when the user scrolls really fast
      - (We use tick and step are interchangable here)
     
      HyperParameters:
      - `curvature` raises sensitivity for medium scrollSpeeds making scrolling feel more comfortable and accurate. This is especially nice for very low minSens.
     */

    var screenSize: size_t = -1
    if useQuickModSpeed || scaleToDisplay {
        
        if inputAxis == kMFAxisHorizontal
            || modifiers.effectMod == kMFScrollEffectModificationHorizontalScroll {
            screenSize = CGDisplayPixelsWide(display);
        } else if inputAxis == kMFAxisVertical {
            screenSize = CGDisplayPixelsHigh(display);
        } else {
            fatalError()
        }
    }
    
    let speed_n = SharedUtilitySwift.eval {
        switch speedArg {
        case kMFScrollSpeedLow: 0.0
        case kMFScrollSpeedMedium: 0.5
        case kMFScrollSpeedHigh: 1.0
        case kMFScrollSpeedSystem: -1.0
        default: -1.0
        }
    }
    
    let minSend_n = speed_n
    let maxSens_n = speed_n
    let curvature_n = speed_n
    
    var minSens: Double
    var maxSens: Double
    var curvature: Double
    
    if useQuickModSpeed {
        
        var windowSize = Double(screenSize)*0.85 /// When we use unanimated line-scrolling this doesn't hold up, but I think we always animate when using quickMod
        
        minSens = windowSize * 0.5 //100
        maxSens = windowSize * 1.5 //500
        curvature = 0.0
        
    } else if usePreciseModSpeed {

        minSens = 1
        maxSens = 20
        curvature = 2.0
        
    } else if animationCurve == kMFScrollAnimationCurveNameTouchDriver
                || animationCurve == kMFScrollAnimationCurveNameTouchDriverLinear {
        
        /// At the time of writing, this is an exact copy of the `regular` smoothness acceleration curves. Not totally sure if that makes sense. One reason I can come up with for adjusting this to the user's scroll speed settings is that the user might use the scroll speed settings to compensate for differences in their physical scrollwheel and therefore the speed should apply to everything they do with the scrollwheel
        
        minSens =   CombinedLinearCurve(yValues: [45.0, 60.0, 90.0]).evaluate(atX: minSend_n)
        maxSens =   CombinedLinearCurve(yValues: [90.0, 120.0, 180.0]).evaluate(atX: maxSens_n)
        if !precise {
            curvature = CombinedLinearCurve(yValues: [0.25, 0.0, 0.0]).evaluate(atX: curvature_n)
        } else {
            curvature = CombinedLinearCurve(yValues: [0.75, 0.75, 0.25]).evaluate(atX: curvature_n)
        }

        
    } else if smoothness == kMFScrollSmoothnessOff { /// It might be better to use the animationCurve instead of smoothness in these if-statements
        
        minSens =   CombinedLinearCurve(yValues: [20.0, 30.0, 40.0]).evaluate(atX: minSend_n)
        maxSens =   CombinedLinearCurve(yValues: [40.0, 60.0, 80.0]).evaluate(atX: maxSens_n)
        if !precise {
            /// For the other smoothnesses we apply more curvature if precise == true, but here it felt best to have them the same. Don't know why.
            curvature = CombinedLinearCurve(yValues: [4.25, 3.0, 2.25]).evaluate(atX: curvature_n)
        } else {
            curvature = CombinedLinearCurve(yValues: [4.25, 3.0, 2.25]).evaluate(atX: curvature_n)
        }
        
    } else if smoothness == kMFScrollSmoothnessRegular {

        minSens =   CombinedLinearCurve(yValues: [/*20.0, 40.0,*/ 30.0, 60.0, 120.0]).evaluate(atX: minSend_n)
        maxSens =   CombinedLinearCurve(yValues: [/*60.0, 90.0,*/ 90.0, 120.0, 180.0]).evaluate(atX: maxSens_n)
        if !precise {
            curvature = CombinedLinearCurve(yValues: [0.25, 0.0, 0.0]).evaluate(atX: curvature_n)
        } else {
            curvature = CombinedLinearCurve(yValues: [0.75, 0.75, 0.25]).evaluate(atX: curvature_n)
        }
        
    } else if smoothness == kMFScrollSmoothnessHigh {
        
        minSens =   CombinedLinearCurve(yValues: [/*30.0,*/ 60.0, 90.0, 150.0]).evaluate(atX: minSend_n)
        maxSens =   CombinedLinearCurve(yValues: [/*90.0,*/ 120.0, 180.0, 240.0]).evaluate(atX: maxSens_n)
        if !precise {
            curvature = 0.0
        } else {
            curvature = CombinedLinearCurve(yValues: [1.5, 1.25, 0.75]).evaluate(atX: curvature_n)
        }
        
    } else {
        fatalError()
    }
    
    
    /// Precise
    
    if precise {
        minSens = 10
    }
    
    /// Screen height
    
    if scaleToDisplay {
        
        /// Get screenHeight factor
        let baseScreenSize = inputAxis == kMFAxisHorizontal ? 1920.0 : 1080.0
        let screenSizeFactor = Double(screenSize) / baseScreenSize
        
        let screenSizeWeight = 0.1
        
        /// Apply screenSizeFactor
        
        maxSens = (maxSens * (1-screenSizeWeight)) + ((maxSens * screenSizeWeight) * screenSizeFactor)
    }
    
    /// vv Old screenSizeFactor formula
    ///     Replaced this with the new formula without in-depth testing, so this might be better
    
//    if screenHeightFactor >= 1 {
//        screenHeightSummand = 20*(screenHeightFactor - 1)
//    } else {
//        screenHeightSummand = -20*((1/screenHeightFactor) - 1)
//    }
//    maxSens += screenHeightSummand
    
    /// Get Curve
    /// - Not sure if 0.08 defaultEpsilon is accurate enough when we create the curve.
    
    let xMin: Double = 1 / Double(consecutiveScrollTickIntervalMax)
    let yMin: Double = minSens
    
    let xMax: Double = 1 / consecutiveScrollTickInterval_AccelerationEnd
    let yMax: Double = maxSens
    
    let curve = BezierCappedAccelerationCurve(xMin: xMin, yMin: yMin, xMax: xMax, yMax: yMax, curvature: curvature, reduceToCubic: false, defaultEpsilon: 0.05)
    
    /// Debug
    
//    DDLogDebug("Recommended epsilon for Acceleration Curve: \(curve.getMinEpsilon(forResolution: 1000, startEpsilon: 0.02/*0.08*/, epsilonEpsilon: 0.001))")
    
    /// Return
    return curve
    
}
