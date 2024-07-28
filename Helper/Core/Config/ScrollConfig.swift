//
// --------------------------------------------------------------------------
// ScrollConfig.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Cocoa

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
            var u_speed = new.u_speed
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
                if u_speed == kMFScrollSpeedSystem {
                    u_speed = kMFScrollSpeedMedium
                }
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
                if u_speed == kMFScrollSpeedSystem {
                    u_speed = kMFScrollSpeedMedium
                }
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
            if u_speed == kMFScrollSpeedSystem && !usePreciseMod && !useQuickMod {
                new.accelerationCurve = nil
            } else {
                new.accelerationCurve = getAccelerationCurve(forSpeed: u_speed, precise: precise, smoothness: new.u_smoothness, animationCurve: new.animationCurve, inputAxis: inputAxis, display: display, scaleToDisplay: scaleToDisplay, modifiers: modifiers, useQuickModSpeed: useQuickMod, usePreciseModSpeed: usePreciseMod, consecutiveScrollTickIntervalMax: new.consecutiveScrollTickIntervalMax, consecutiveScrollTickInterval_AccelerationEnd: new.consecutiveScrollTickInterval_AccelerationEnd)
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
        
//        if HelperState.shared.isLockedDown { return kMFScrollInversionNonInverted }
        return c("reverseDirection") as! Bool ? kMFScrollInversionInverted : kMFScrollInversionNonInverted
    }()
    
    // MARK: Old Invert Direction
    /// Rationale: We used to have the user setting be "Natural Direction" but we changed it to being "Reverse Direction". This is so it's more transparent to the user when Mac Mouse Fix is intercepting the scroll input and also to have the SwitchMaster more easily decide when to turn the scrolling tap on or off. Also I think the setting is slightly more intuitive this way.
    
//    @objc func scrollInvert(event: CGEvent) -> MFScrollInversion {
//        /// This can be used as a factor to invert things. kMFScrollInversionInverted is -1.
//
//        if HelperState.shared.isLockedDown { return kMFScrollInversionNonInverted }
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
    /// Notes:
    /// - This flag will be set on GestureScroll events, as well as DockSwipe, and maybe other events and and will invert some interactions like scrolling to delete messages in Mail
    /// - Why did we decide to always have this off? My guess is that invertedFromDevice is meant to preserve physical relationship between fingers and UI for interactions like delete messages in Mail, but since this physical relationship doesn't exist on the scrollwheel, it makes sense to just set this to a constant value independent of scroll inversion. However, it might be better to always turn *on* invertedFromDevice, instead of keeping it turned *off*, since that's the default setting in macOS, and turning it off leads to bugs when sending pinch type Dock swipes to open Launchpad. We implemented a workaround for this bug, but still should be better to always turn this on. 
    ///     - Edit: Always turning inverted from device **on** now. Seems to work fine so far. It makes the direction of unread-swipes in Mail make more sense.
    
    @objc let invertedFromDevice = true;
    
    // MARK: Analysis
    
    @objc lazy var scrollSwipeThreshold_inTicks: Int = 2 /*other["scrollSwipeThreshold_inTicks"] as! Int;*/ /// If `scrollSwipeThreshold_inTicks` consecutive ticks occur, they are deemed a scroll-swipe.
    
    @objc lazy var scrollSwipeMax_inTicks: Int = 11 /// Max number of ticks that we think can occur in a single swipe naturally (if the user isn't using a free-spinning scrollwheel). (See `consecutiveScrollSwipeCounter_ForFreeScrollWheel` definition for more info)
    
    @objc lazy var consecutiveScrollTickIntervalMax: TimeInterval = 160/1000
    /// ^ Notes:
    ///     If more than `_consecutiveScrollTickIntervalMax` seconds passes between two scrollwheel ticks, then they aren't deemed consecutive.
    ///        other["consecutiveScrollTickIntervalMax"] as! Double;
    ///     msPerStep/1000 <- Good idea but we don't want this to depend on msPerStep
    
    @objc lazy var consecutiveScrollTickIntervalMin: TimeInterval = 1/1000
    /// ^ Notes:
    ///     - This variable is used to cap the observed scrollTickInterval to a reasonable value. We also use it for Math.scale() ing the timeBetweenTicks into a value between 0 and 1. But I'm not sure this is better than just using 0 instead of `consecutiveScrollTickIntervalMin`.
    ///     - 15ms seemst to be smallest scrollTickInterval that you can naturally produce. But when performance drops, the scrollTickIntervals that we see can be much smaller sometimes.
    ///     - Update: This is not true for my Roccat Mouse connected via USB. The tick times go down to around 5ms on that mouse. I can reproduce the 15ms minimum using my Logitech M720 connected via Bluetooth. I guess it depends on the mouse hardware or on the transport (bluetooth vs USB).
    ///         - Action: We're lowering the `consecutiveScrollTickIntervalMax` from 15 -> 1. Primarily to be able to implement the `baseMsPerStepCurve` algorithm better, but also because our assumption that the lowest possible value is 15 is not true for all mice.
    ///         **HACK**: We need to keep the  the `consecutiveScrollTickInterval_AccelerationEnd` at 15ms for now, because lowering that to 5ms would change the behaviour or the acceleration algorithm and make scrolling slower, and we don't have time to adjust the acceleration curves right now.

    @objc lazy var consecutiveScrollSwipeMaxInterval: TimeInterval = {
        /// If more than `_consecutiveScrollSwipeIntervalMax` seconds passes between two scrollwheel swipes, then they aren't deemed consecutive.
        
        let result: Double = SharedUtilitySwift.eval {
            
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
        
        let result: Double = SharedUtilitySwift.eval {
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
    
    @objc lazy var consecutiveScrollTickInterval_AccelerationEnd: TimeInterval = 15/1000 //consecutiveScrollTickIntervalMin
    /// ^ Notes:
    ///     - Used to define accelerationCurve. If the time interval between two ticks becomes less than `consecutiveScrollTickInterval_AccelerationEnd` seconds, then the accelerationCurve becomes managed by linear extension of the bezier instead of the bezier directly.
    ///     - This should ideally be equal to `consecutiveScrollTickIntervalMin`. For an explanation why it's different at the moment, see the notes on consecutiveScrollTickIntervalMin
    
    /// Note: We are just using RollingAverge for smoothing, not ExponentialSmoothing, so this is currently unused.
    @objc lazy var ticksPerSecond_DoubleExponentialSmoothing_InputValueWeight: Double = 0.5
    @objc lazy var ticksPerSecond_DoubleExponentialSmoothing_TrendWeight: Double = 0.2
    @objc lazy var ticksPerSecond_ExponentialSmoothing_InputValueWeight: Double = 0.5
    /// ^  Notes:
    ///     1.0 -> Turns off smoothing. I like this the best
    ///     0.6 -> On larger swipes this counteracts acceleration and it's unsatisfying. Not sure if placebo
    ///     0.8 ->  Nice, light smoothing. Makes  scrolling slightly less direct. Not sure if placebo.
    ///     0.5 -> (Edit) I prefer smoother feel now in everything. 0.5 Makes short scroll swipes less accelerated which I like
    
    // MARK: Fast scroll
    
    
    @objc lazy var fastScrollCurve: ScrollSpeedupCurve? = {
        
        /// NOTES:
        /// - We're using swipeThreshold to configure how far the user must've scrolled before fastScroll starts kicking in.
        /// - It would probably be better to have an explicit mechanism that counts how many pixels the user has scrolled already and then lets fastScroll kick in after a threshold is reached. That would also scale with the scrollSpeed setting. These current `fastScrollSpeedup` values are chosen so you don't accidentally trigger it at the lowest scrollSpeed, but they could be higher at higher scrollspeeds.
        /// - Fastscroll starts kicking in on the `swipeThreshold + 1` th scrollSwipe
        /// - Edit: Why do we need speedup for kMFScrollAnimationCurveNameTouchDriver and kMFScrollAnimationCurveNameTouchDriverLinear?
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
    
    @objc lazy var u_smoothness: MFScrollSmoothness = {
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
    
    @objc lazy var accelerationCurve: Curve? = nil /// Initial value is unused I think. Will always be overriden before it's used anywhere. Edit: No, this stays nil, if we useAppleAcceleration
    
    // MARK: Keyboard modifiers
    
    /// Event flag masks
    @objc lazy var horizontalModifiers = CGEventFlags(rawValue: c("modifiers.horizontal") as! UInt64)
    @objc lazy var zoomModifiers = CGEventFlags(rawValue: c("modifiers.zoom") as! UInt64)
    
    @objc func copy(with zone: NSZone? = nil) -> Any {
        
        /// TODO: Think about whether this could have todo with the weird scrolling crashes for MMF 3.0.2. Any race conditions or sth?
        
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
    @objc let speedSmoothing: Double /// `speedSmoothing` replaces `baseCurve`. If it is active, the baseCurve will be dynamically calculated, such that the animation speed doesn't jump after a scrollwheel-tick occurs.
    @objc let baseMsPerStepCurve: Curve? /// If this is not nil, the minStepDuration will be controlled by this curve instead of baseMsPerStep. The point at which this curve is sampled will increase from 0 to 1 as the time between physical scrollWheel ticks decreases.
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
    init(baseCurve: Bezier?, speedSmoothing: Double, baseMsPerStepCurve: Curve?, baseMsPerStep: Int, dragExponent: Double, dragCoefficient: Double, stopSpeed: Int, sendGestureScrolls: Bool, sendMomentumScrolls: Bool) {
        
        /// Init for using hybridCurve (baseCurve + dragCurve) or (speedSmoothingCurve + dragCurve).
        
        if sendMomentumScrolls { assert(sendGestureScrolls) }
        assert((speedSmoothing != -1) ^ (baseCurve != nil))
        assert((baseMsPerStepCurve == nil) ^ (baseMsPerStep == -1))
        
        self.baseCurve = baseCurve
        self.speedSmoothing = speedSmoothing
        self.baseMsPerStepCurve = baseMsPerStepCurve
        self.baseMsPerStep = baseMsPerStep
        
        self.useDragCurve = true
        self.dragExponent = dragExponent
        self.dragCoefficient = dragCoefficient
        self.stopSpeed = stopSpeed
        
        self.sendGestureScrolls = sendGestureScrolls
        self.sendMomentumScrolls = sendMomentumScrolls
    }
    init(baseCurve: Bezier?, msPerStep: Int, sendGestureScrolls: Bool) {
        
        assert(baseCurve != nil)
        
        /// Init for using just baseCurve
        
        self.baseMsPerStep = msPerStep
        
        self.baseCurve = baseCurve
        self.speedSmoothing = -1
        self.baseMsPerStepCurve = nil
        
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

        /// vvv Higher baseMsPerStep
//        return MFScrollAnimationCurveParameters(baseCurve: nil, speedSmoothing: 0.00, baseMsPerStepCurve: 90, baseMsPerStep: 160, dragExponent: 1.0, dragCoefficient: 23, stopSpeed: 30, sendGestureScrolls: false, sendMomentumScrolls: false)
        
        /// vvv Combination of previous 2
//        return MFScrollAnimationCurveParameters(baseCurve: nil, speedSmoothing: 0.00, baseMsPerStepCurve: 90, baseMsPerStep: 140, dragExponent: 1.05, dragCoefficient: 15, stopSpeed: 30, sendGestureScrolls: false, sendMomentumScrolls: false)
        
        /// vvv This tries to 'feel' like MMF 2.
        ///     - For medium and large scroll swipes it feels similarly responsive snappy to MMF 2 due to the 90 baseMsPerStepMin. (In MMF 2 the baseMsPerStep was 90)
        ///     - For single ticks on default settings, the speed feels similar to MMF 2 due to the 140 baseMsPerStep and due to the step size being larger than MMF 2.
        ///     - In MMF 2, exponent is 1.0 and coeff is 2.3. Here the coeff is 23. Not sure if that's the same but feels similar.
        ///     - Update:
        ///         - We've now replaced baseMsPerStepMin with baseMsPerStepCurve and changed all the parameters around. (See below for more info on that) Not sure this feels like MMF 2 anymore. But it feels really good.
        
        /// Define curve for the baseMsPerStepCurve speedup
        /// 
        /// Notes:
        ///
        /// - The reason why we introduced a curve, is that when we tried linear interpolation for the baseMsPerStepMin, we found that little 2-3 tick swipes were too fast, but larger/faster swipes were too slow. Initially, we tried to fix that by adding additional smoothing inside ScrollAnalyzer by initializing the `_tickTimeSmoother` with a value. However, this messed up the scroll distance acceleration, so we turned that back off. This curve is our second attempt at making the 2-3 tick swipes animate slower while making the larger or faster swipes animate faster. In contrast to the previous ScrollAnalyzer-based approach, this approach doesn't have a time component, where if you scroll at the same speed for a longer time it speeds up more. Not sure if this is a good or bad thing.
        /// - The curve we're using (at the time of writing) is basically just a shifted and scaled exponential function. I designed it using this desmos page: https://www.desmos.com/calculator/l8plcdlpmn. I first tried using a Bezier curve, but it didn't get curved enough. I thought about using a curve based on 1/x instead of e^x, but they looked very similar in desmos and e^x is simpler to deal with.
        /// 
        /// - Sidenotes:
        ///     - It's overall a little messy that we have these hybrid curves whose duration we can't directly control, but then we create complex curves for the duration of the baseCurve of the HybridCurve to gain back some control of the overall duration. It's sort of messy and confusing. All in the name of having the deceleration feel 'physical'. (That's the purpose of the HybridCurves) I mean this is still the best feeling scrolling algorithm I know of so I guess it works, but I really wonder if it wouldn't have been possible to design something more elegant. Maybe we could've done a sort of spring animator and then dynamically chose the starting speed such that the animation covers a certain distance in a certain time. That's the thing we really want to have explicit control over: The distance. But we also want to have control over the feel and over the duration. However, if you want to have a 'physical' feel it's complicated to also control the distance and duration. And actually in case of the high smoothness curves I think I'm pretty happy not having to explicitly control the duration. The duration just falls out of the physics in a nice way. Update: Stared at Desmos for a while and came to the conclusion that our current idea is the best and with spring animations we'd have more or less the same problem. (Can't easily control both duration and distance while keeping consistent physics)
        ///
        /// - **Ideaaa**: It seems that what I'm currently trying to to when designing these curves is 1. Make the animations speed for fastest scrollwheel movements as fast as possible without becoming disorientating to look at 2. Adjust the animation speed for lower scrollwheel speed to feel 'the same' or 'consistent' with the fastest scrollwheel speed - because the 'consistent' feel makes it easier to control. (I'm not sure what consistent means, it's just a feeling) --- Maybe we could do this stuff explicitly somehow. Like explicitly cap the animation speed. Update: Just measured the overall animation duration (including drag) after finding a `baseMsPerStepCurve` that feels 'consistent' to us and I found the duration is relatively close to being constant! It's currently between 260 and 300 ms - This gives me the idea that what we were subconsciously doing with the `baseMsPerStepCurve` was to try and make the overall animation duration constant. Maybe that's what made it feel 'consistent' to us. Update: Also did some testing for curves that feel 'inconsistent' to us and the variation in overall animation duration wasn't thatt much more as I thought. I think what I observed was like 240 to 340 ms. Maybe this means that the 'consistent' feel has other aspects aside from low variation in overall animation duration.
        ///     - **Implementation Ideas**: These thoughts give me two concrete ideas for potentially improving our scrolling algorithms:
        ///         1. Idea: Make a way to create a `HybridCurve` with a fixed duration along with a fixed distance. The HybridCurve should then automatically figure out what the baseCurve should be / how fast the baseMsPerStep should be. Having explicit control over the duration might allow us to create better, more 'consistent' feeling and more controllable curves. I don't think we'd want to use this for High Smoothness scrolling, since there we want a large variability in animation duration, and the way the current algorithms behave feels very natural and predictable to me already. But for the regular smoothness setting (Which uses this code right here), this could potentially be nice. But on the other hand, maybe the bit of variability in animation duration is good? I'm not sure. Butt, if we implemented a system for explicitly controlling the animation duration, we could still vary the animation duration with the animation distance or with the scrollwheel speed. We'd simply have more control over it, which I think really couldn't hurt?
        ///             - Conclusion: This idea is interesting. I think it would be good to try at some point. But to really ship this, we'd have to be careful and dedicate a lot of time to testing. I think for now, the current approach of defining a `baseSpeedupCurve` to get some control over the scroll animation duration seems like it's good enough. Maybe it's even inherently better than this idea. I'm not sure. That's why I should test it at some point. But not now.
        ///         2. Idea: Make a way to explicitly specify a maxAnimationSpeed(Target) which is the highest speed where your eyes can follow scrolling content on the screen (This probably depends on screen refresh rate and other stuff, but we can assume our own screen as a heuristic I think). The duration of the animation curve could then be dynamically determined to be such that, when the user does a scroll swipe at max speed, the resulting animation has a max speed of maxAnimationSpeed(Target). Note that this means we'd choose different animation durations for different "Scrolling Speed" user settings that the user might choose (These user settings really determine sensitivity to be precise) . As a simpler-to-implement stand-in for such a mechanism, we could simply scale the baseMsPerStep with the accelerationCurve. E.g. we could desing the baseMsPerStep around the mediumSpeed accelerationCurve, then sample both the mediumSpeed accelerationCurve and the currentSpeed accelerationCurve at let's say 80% of the maximum scrollwheel speed that the user can input, and then get the scaling factor `s` between the 80% values of those two curves. Then we could multiply the baseMsPerStep with `s`. That way we only have to find a suitable baseMsPerStep for the mediumSpeed accelerationCurve and the rest would be adjusted such that the user can produce an animation speed of *up to* maxAnimationSpeed(Target) no matter what "Scrolling Speed" setting they choose.
        ///             - Sidenote: I'm putting "Target" in `maxAnimationSpeed(Target)` because it's not supposed to be a hard cap for the animation speed it's more like a heuristic saying: if the user inputs the fastest scroll they can, then the movement on the screen should be about this fast.
        ///             - Conclusion: I think this is an idea worth exploring, especially when we introduce more options for the user to choose a "Scrolling Speed".  However, this would need a lot of testing to make sure we're getting it right, and I should only do it if I have time to dedicate to this. So not now.
        ///
        /// - Idea:
        ///     - What's interesting is that the animationDuration is influenced by both the baseMsPerStep speed up mechanism as well as by the Drag physics inside the HybridCurve. But at the time of writing, the baseMsPerStep speed up is applied purely based on timeBetweenscrollwheelTicks, while the animationDuration modification from the drag physics is applied based on how many pixels are left to scroll. (Which is also a result of the timeBetweenscrollwheelTicks but with an additional time component I think). This is quite messy to think about. Based on these thoughts, I would think that the animationDuration is very unpredictable. But in practise it doesn't feel that way. 
        ///
        /// - Finding parameters:
        ///     - I liked 4.0, 140.0, 60.0 for a while - It feels super direct and immediate. And still smoother than Chrome. However I found that it's hard to follow scrolling movements with your eyes at least on my displays.
        ///     - I liked 4.0, 180.0, 110.0
        ///         - Notes:
        ///             - 110 feels like MMF 2 on fast swipes, it's slow enough that  you can still see the content well. 110 is the lower end for clear visibiliy during scrolling I think. Setting the max to 180 makes the speed feel 'consistent' for slow and fast swipes which helps controllability.
        ///             - I have played around with small changes to this a bit. E.g. using 170 instead of 180. I had the impression that 4.0, 180.0, 110.0 is close to a local optimum.
        ///                 - I also tried 200.0, 120.0 - I thought 120 feelt less grating and confusing to eyes, but that made it feel a bit too unresponsive
        ///             - The max animation speed of this feels similar to the pre 3.0.1 algorithm. We did this whole baseMsPerStepCurve (and the predecessor baseMsPerStepMin) stuff because we thought that things felt too unresponsive and now it feels like we've arrived at something similar to the starting point. But, I really think this is at the upper end of animation speed that is nice to use, and the responsiveness is noticably better than pre 3.0.1. Controllability is also better I think.
        ///             - You'd think that the whole baseCurveSpeedup and curvature stuff would make the scrolling less predictable/controllable. Not totally sure, but I feel like for this curve if we turn the speedup off it becomes harder to control/predict. Update: I looked at the overall animation duration (including DragCurve and BaseCurve) and there's less variation in that with this speedup mechanism. Maybe decreased variability makes things more predictable / easy to control. See **Ideaaa** above for more on this.

        let curvature = 4.0                  /* 5.0   4.0 */ /// Should be >= 0.0
        let baseMsPerStepCurveMax = 180.0    /* 140.0 150.0  180.0  200.0 */
        let baseMsPerStepCurveMin = 110.0    /* 60.0  90.0    110.0  120.0 */ /// MMF 2 feels more like 110 not 90 or 60
        
        let baseSpeedupCurve: Curve
        
        if curvature == 0.0 {
            let e = { x in
                Math.scale(value: x, from: .unitInterval, to: Interval(baseMsPerStepCurveMax, baseMsPerStepCurveMin))
            }
            baseSpeedupCurve = Curve(rawCurve: e)
        } else {
            
            let e1 = { x in exp(x * curvature) - 1 }
            let e2 = { x in e1(x) / e1(1) }
            let e3 = CurveTools.transformCurve(e2) { y in
                Math.scale(value: y, from: .unitInterval, to: Interval(baseMsPerStepCurveMax, baseMsPerStepCurveMin))
            }
            baseSpeedupCurve = Curve(rawCurve: e3)
        }
        
        return MFScrollAnimationCurveParameters(baseCurve: ScrollConfig.linearCurve, speedSmoothing: -1, baseMsPerStepCurve: baseSpeedupCurve, baseMsPerStep: -1, dragExponent: 1.0, dragCoefficient: 23, stopSpeed: 30, sendGestureScrolls: false, sendMomentumScrolls: false)
        
        /// - vvv Pre 3.0.1 curve (I think)
        /// - I don't like this curve atm. It's still too slow. I'm currently 'tuned into' liking the MMF 2 algorithm and it's much quicker than this.
        /// - MMF 2 has baseMsPerStep 90, this makes medium and large scroll swipes feel much more responsive. But single scroll ticks feel too fast. Maybe we could implement an algorithm where the baseMSPerStep is variable and it shrinks on consecutive scroll swipes or as the scroll speed gets higher, or sth like that. Ideas:
        ///    - Add a cap to the base scroll speed.
        ///    - Make the msPerStep a mix between baseMSPerStep and the actual msPerStep of the scrollwheel. Maybe as soon as `scrollWheelMsPerStep < baseMSPerStep` we use `scrollWheelMsPerStep` or do an interpolation between the 2
        ///         Update: Implemented this with the `baseMsPerStepMin`param (Update: Now changed to `baseMsPerStepCurve`)
        
//        return MFScrollAnimationCurveParameters(baseCurve: ScrollConfig.linearCurve, speedSmoothing: -1, baseMsPerStepCurve: nil, baseMsPerStep: 140, dragExponent: 1.05, dragCoefficient: 15, stopSpeed: 30, sendGestureScrolls: false, sendMomentumScrolls: false)
        
        /// - vvv I think I like this curve better. Still super responsive and much smoother feeling. But I'm not sure I'm 'tuned into' what the lowInertia should feel like. Bc when I designed it I really liked the snappy, 'immediate' feel, but now I don't like it anymore and wanna make everything much smoother. So I'm not sure I should change it now. Also we should adjust the speed curves if we adjust the feel of this so much.
        
//        return MFScrollAnimationCurveParameters(baseCurve: nil, speedSmoothing: 0.15, baseMsPerStepCurve: nil, baseMsPerStep: 175, dragExponent: 0.9, dragCoefficient: 25, stopSpeed: 30, sendGestureScrolls: false, sendMomentumScrolls: false)
        
    case kMFScrollAnimationCurveNameMediumInertia:
        
        fatalError()
        
        return MFScrollAnimationCurveParameters(baseCurve: ScrollConfig.linearCurve, speedSmoothing: -1, baseMsPerStepCurve: nil, baseMsPerStep: 200, dragExponent: 1.05, dragCoefficient: 15, stopSpeed: 30, sendGestureScrolls: false, sendMomentumScrolls: false)
        
        return MFScrollAnimationCurveParameters(baseCurve: ScrollConfig.linearCurve, speedSmoothing: -1, baseMsPerStepCurve: nil, baseMsPerStep: 190, dragExponent: 1.0, dragCoefficient: 17, stopSpeed: 50, sendGestureScrolls: false, sendMomentumScrolls: false)
        
    case kMFScrollAnimationCurveNameHighInertia:
        
        /// - This uses the snappiest dragCurve that can be used to send momentumScrolls.
        ///    If you make it snappier then it will cut off the built-in momentumScroll in apps like Xcode
        /// - We tried setting baseMsPerStep 205 -> 240, which lets medium scroll speed look slightly smoother since you can't tell the ticks apart, but it takes longer until text becomes readable again so I think I like it less. Edit: In MOS's scrollAnalyzer, 240 is the lowest baseMSPerStep where the animationSpeed is constant for low medium scrollwheel speed. Edit: But 215 - 220 is also almost perfect for medium speeds, and in AB testing it's barely different-feeling than 205. In AB testing, I liked 220 slightly more than 240, but the difference is small.
        /// - Speed smoothing prevents the slightly unsmooth look at medium and low scroll speeds, but it can also make scrolling feel less responsive and direct. From my testing, at 0.4 it becomes sluggish feeling. Edit: From more testing, I think 0.15 makes especially single ticks a bit smoother, and doesn't noticably impact responsiveness. I did some performance testing, since with speedSmoothing, the BezierCurves can't be optimized into simple straight lines anymore. Scrolling to the bpm of a song the CPU usage went from 1.2% -> 1.6% percent. That's a 30% increase, but it's still very fast. Currently we're using an epsilon of 0.01 for the BezierCurves. If we lower that we might get even better performance, but it already gives slightly different curves in MOS scroll analyzer with this epsilon compared to more accurate epsilon, so I don't think we should make it lower.
        /// Update: Turned speedSmoothing from 0.15 -> 0.00 rn for more responsive/predictable feel.
        ///     - This is an experiment. I thought it made it easier to use the 'scrollStop' feature where you scroll one tick in the opposite direction to stop the scroll animation. 'Throwing' the page and then stopping it felt more predictable with speedSmoothing off.
        ///     - I also heard some reports from people that scrolling in 3.0.1 is worse / performs worse than before. (I'm fairly sure we introduced speedSmoothing in 3.0.1) So maybe the performance issues could also have to do with speedSmoothing? (I don't think it should be performance intensive enough to make a difference though, but who knows?)
        ///     - However I also found that scrolling felt refreshingly responsive after turning speed smoothing off. Might be placebo, but I think I like it better.
        
        return MFScrollAnimationCurveParameters(baseCurve: nil/*ScrollConfig.linearCurve*/, speedSmoothing: /*0.15*/0.0, baseMsPerStepCurve: nil, baseMsPerStep: 220, dragExponent: 0.7, dragCoefficient: 40, stopSpeed: /*50*/30, sendGestureScrolls: false, sendMomentumScrolls: false)
        
    case kMFScrollAnimationCurveNameHighInertiaPlusTrackpadSim:
        /// Same as highInertia curve but with full trackpad simulation. The trackpad sim stuff doesn't really belong here I think.
        return MFScrollAnimationCurveParameters(baseCurve: nil/*ScrollConfig.linearCurve*/, speedSmoothing: /*0.15*/0.0, baseMsPerStepCurve: nil, baseMsPerStep: 220, dragExponent: 0.7, dragCoefficient: 40, stopSpeed: /*50*/30, sendGestureScrolls: true, sendMomentumScrolls: true)
        
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
        return MFScrollAnimationCurveParameters(baseCurve: ScrollConfig.linearCurve, speedSmoothing: -1, baseMsPerStepCurve: nil, baseMsPerStep: /*220*/300, dragExponent: 0.7, dragCoefficient: 30, stopSpeed: 1, sendGestureScrolls: true, sendMomentumScrolls: true)
        
    case kMFScrollAnimationCurveNamePreciseScroll:
        
        /// Similar to `lowInertia`
//        return MFScrollAnimationCurveParameters(baseCurve: ScrollConfig.linearCurve, baseMsPerStep: 140, dragExponent: 1.0, dragCoefficient: 20, stopSpeed: 50, sendGestureScrolls: false, sendMomentumScrolls: false)
        return MFScrollAnimationCurveParameters(baseCurve: ScrollConfig.linearCurve, speedSmoothing: -1, baseMsPerStepCurve: nil, baseMsPerStep: 140, dragExponent: 1.05, dragCoefficient: 15, stopSpeed: 50, sendGestureScrolls: false, sendMomentumScrolls: false)
        
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
     
     General thoughts / explanation on how our BezierCappedAccelerationCurve class works in this context:
     
      Define a curve describing the relationship between the inputSpeed (in scrollwheel ticks per second) (on the x-axis) and the sensitivity (In pixels per tick) (on the y-axis).
      We'll call this function y(x).
      y(x) is composed of 3 other curves. The core of y(x) is a BezierCurve *b(x)*, which is defined on the interval (xMin, xMax).
      y(xMin) is called yMin and y(xMax) is called yMax
      There are two other components to y(x):
      - For `x < xMin`, we set y(x) to yMin
      - We do this so that the acceleration is turned off for tickSpeeds below xMin. Acceleration should only affect scrollTicks that feel 'consecutive' and not ones that feel like singular events unrelated to other scrollTicks. `self.consecutiveScrollTickIntervalMax` is (supposed to be) the maximum time between ticks where they feel consecutive. So we're using it to define xMin.
      - For `xMax < x`, we lineraly extrapolate b(x), such that the extrapolated line has the slope b'(xMax) and passes through (xMax, yMax)
      - We do this so the curve is defined and has reasonable values even when the user scrolls really fast
      - (Our uses of tick and step are interchangable here)
     
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
    
    let speed_n: Double = SharedUtilitySwift.eval {
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
        
        let windowSize = Double(screenSize)*0.85 /// When we use unanimated line-scrolling this doesn't hold up, but I think we always animate when using quickMod
        
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
