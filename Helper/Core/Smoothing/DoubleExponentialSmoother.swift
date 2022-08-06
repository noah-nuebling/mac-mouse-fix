//
// --------------------------------------------------------------------------
// Smoother.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Cocoa

/// Implemented according to this website: https://support.minitab.com/en-us/minitab-express/1/help-and-how-to/modeling-statistics/time-series/how-to/double-exponential-smoothing/methods-and-formulas/methods-and-formulas/#weights

@objc internal class DoubleExponentialSmoother: NSObject, Smoother {
    
    /// Params
    
    var a: Double
    var y: Double
    var initialValue1: Double?
    var initialValue2: Double?
        
    /// Init
    
    @objc convenience init(a: Double, y: Double) {
        self.init(privateA: a, y: y, initialValue1: nil, initialValue2: nil)
    }
    @objc convenience init(a: Double, y: Double, initialValue1: Double, initialValue2: Double) {
        self.init(privateA: a, y: y, initialValue1: initialValue1, initialValue2: initialValue2)
    }
    
    /** Main init
     - Parameters:
        - a: Weight for input value aka "data smoothing factor"
            - If you set this to 1 there is no smoothing, if you set it to 0 the output never changes
        - y: Weight for trend aka "trend smoothing factor"
            - If you set this to 1 the trend isn't
        - initialValues
            - From my understanding, the algorithm needs 2 inputs before it starts actually smoothing the values.
            - The first input establishes the initial value, the first two together establish the initial trend.
            - The first and second inputs will just be returned without alteration without any smoothing
            - So to avoid misuse of the algorithm we're requiring the initial values in the initializer
        - Need to call `a` `privateA` so that this funciton is differentiable from  `init(a:y:initialValue1:initialValue2:) `
     */
    private init(privateA: Double, y: Double, initialValue1: Double?, initialValue2: Double?) {
        
        self.a = privateA
        self.y = y
        self.initialValue1 = initialValue1
        self.initialValue2 = initialValue2
        
        super.init()
        
        self.reset()
        
    }
    
    /// Dynamic vars
    
    var Lprev: Double = -1
    var Tprev: Double = -1
    var usageCounter: Int = 0
    
    /// Main
    
    @objc func reset() {
        usageCounter = 0
        
        if let initialValue1 = self.initialValue1, let initialValue2 = self.initialValue2 {
            _ = smooth(value: initialValue1)
            _ = smooth(value: initialValue2)
        }
    }
    
    @objc func smooth(value: Double) -> Double {
        
        let Y = value /// Input value

        var L: Double = -1; /// Smoothed value
        var T: Double = -1; /// Trend
        
        switch usageCounter {
        case 0: /// There is no Lprev nor Tprev, so we can't smooth
            L = Y
        case 1:
            /// There is Lprev but no real Tprev. But we create a fake Tprev so we can already apply the normal smoothing algorithm.
            /// This seems like a weird hack but it follows the "Holt–Winters double exponential smoothing" algorithm described on this Wiki page https://en.wikipedia.org/wiki/Exponential_smoothing#Double_exponential_smoothing (if I understand it correctly)
            Tprev = Y - Lprev; // (Lprev is effectively Yprev at this point, because Lt was set to Yt in the previous step)
            fallthrough
        default: /// Lprev and Tprev exist, we can use normal smoothing algorithm
            L = a * Y  + (1 - a) * (Lprev + Tprev)
            /// ^ Shouldn't the algorithm work better if we use Tt here instead of Tprev? If we did that, then, if we set y to 1, it would effectively turn off the trend aspect and this would become normal smoothing. So y would become a simple dial for how much we factor in the trend. Edit: Implementation of this in NoahSmoother.swift ... Nope that's impossible to implement because the T definition is already using L, so the L definition can't use T
            T = y * (L - Lprev) + (1 - y) * Tprev
        }
        usageCounter += 1;
        
        Lprev = L
        Tprev = T
        
        return L
    }
    
    @objc func predictValue(stepsIntoFuture steps: Int) -> Double {
        if usageCounter >= 2 {
            let Ypred = Lprev + Double(steps) * Tprev
            return Ypred
        }
        fatalError()
    }
    @objc func lastSmoothedValue() -> Double {
        if usageCounter >= 1 {
            return Lprev
        }
        fatalError()
    }
    
}
