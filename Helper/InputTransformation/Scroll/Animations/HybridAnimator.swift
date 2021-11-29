//
// --------------------------------------------------------------------------
// HybridAnimator.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

/// This is unused in favor of HybridCurve.swift


//import Foundation
//import Bezier
//
//@objc class HybridAnimator: NSObject, Animator {
//    
//    /// This curve is intended to animate scrolling in a way that resembles the original MMF scrolling algorithm
//    /// The animator is built on top of the PixelatedAnimator
//    /// The first half of the animation  is driven by a BezierCurve, and the second half by a DragCurve.
//    /// The drag curve is used to ensure physically accurate, natural-feeling deceleration.
//
//    /// Vars - init args
//    
//    let baseAnimationCurve: Bezier
//    let dragCoefficient: Double
//    let dragExponent: Double
//    let stopSpeed: Double
//    
//    /// Vars - Other init
//    
//    let animator: PixelatedAnimator
//    
//    /// Init
//    
//    @objc init(baseAnimationCurve: Bezier, dragCoefficient: Double, dragExponent: Double stopSpeed: Double) {
//        
//        self.baseAnimationCurve = baseAnimationCurve
//        self.dragCoefficient = dragCoefficient
//        self.dragExponent = dragExponent
//        self.stopSpeed = stopSpeed
//        
//        self.animator = PixelatedAnimator(animationCurve: baseAnimationCurve)
//        
//        super.init()
//        
//    }
//    
//    @objc var isRunning: Bool {
//        self.animator.isRunning
//    }
//    
//    /// Vars - Startt and stop
//    
//    var animationTimeIntervalBase: Interval = .unitInterval
//    var animationValueIntervalBase: Interval = .unitInterval
//    /// ^ Just initing to .unitInterval so Swift doesn't complain. These values are unused
//    /// The `base` ^ values refer to the `baseAnimationCurve`. The values below v are the sum of both curves' values
//    var animationTimeInterval: Interval { animationTimeIntervalBase + dragAnimationCurve.timeInterval }
//    var animationValueInterval: Interval { animationValueIntervalBase + dragAnimationCurve.distanceInterval }
//    
//    var lastAnimationTime: Double {
//        if (animator.lastAnimationTime)
//    }
//    var lastAnimationValue: Double {
//        
//    }
//    
//    var dragAnimationCurve: DragCurve
//    
//    /// Vars - interface
//    
//    @objc var animationTimeLeft: Double {
//        return animationTimeInterval.length - lastAnimationTime
//    }
//    @objc var animationValueLeft: Double {
//        return animationValueInterval.length - lastAnimationValue
//    }
//    
//    /// Start
//    
//    @objc func start(duration: CFTimeInterval,
//                     valueInterval: Interval,
//                     callback: @escaping PixelatedAnimatorCallback) {
//        /// The duration and valueInterval passed in here will correspond to the BezierCurve (`baseAnimationCurve`)
//        ///     The DragCurve (`dragAnimationCurve`) will increase these values.
//        ///     The class properties`animationTimeInterval` and `animationValueInterval` will therefore be longer than the values passed in here.
//        
//        /// Store value and time intervals
//        self.animationTimeIntervalBase = Interval(location: 0, length: duration)
//        self.animationValueIntervalBase = valueInterval
//        
//        /// Get exit slope of baseCurve
//        let exitSlope: Double = self.baseAnimationCurve.exitSlope
//        
//        /// Get exit speed of baseCurve (== initial speed of drag curve)
//        let exitSpeed = exitSlope * animationValueIntervalBase.length / animationTimeIntervalBase.length
//        
//        /// Create DragCurve
//        dragAnimationCurve = DragCurve(coefficient: self.dragCoefficient, exponent: self.dragExponent, initialSpeed: exitSpeed, stopSpeed: self.stopSpeed)
//        
//        /// Start baseAnimation
//        
//        self.animator.start(duration: duration, valueInterval: valueInterval, animationCurve: baseAnimationCurve) { integerAnimationValueDelta, animationTimeDelta, phase in
//            
//            switch phase {
//            case kMFAnimationPhaseEnd, kMFAnimationPhaseStartAndEnd:
//                
//                /// Start dragAnimation
//                
//                self.animator.start(duration: dragAnimationCurve.timeInterval.length, valueInterval: dragAnimationCurve.distanceInterval, animationCurve: dragAnimationCurve) { integerAnimationValueDelta, animationTimeDelta, phase in
//                    
//                    callback(integerAnimationValueDelta, animationTimeDelta, phase)
//                }
//                
//            default:
//                callback(integerAnimationValueDelta, animationTimeDelta, phase)
//                
//            }
//            
//        }
//        
//        
//    }
//    
//}
