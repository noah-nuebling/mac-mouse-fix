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

@objc internal class DoubleExponentialSmoother: NSObject{
    
    // Params
    var a: Double
    var y: Double
    
    // Dynamic
    var Lprev: Double = -1
    var Tprev: Double = -1
    var usageCounter: Int = 0
        
    /// init
    /// - Parameters:
    ///   - a: Weight for input value aka "data smoothing factor"
    ///   - y: Weight for trend aka "trend smoothing factor"
    @objc init(a: Double, y: Double) {
        
        self.a = a
        self.y = y
        
        super.init()
        
    }
    
    @objc func resetState() {
        usageCounter = 0
        // ^ Everything else will be indirectly reset by resetting this
    }
    
    @objc func smooth(value: Double) -> Double {
        
        let Yt = value /// Input value

        var Lt: Double = -1; /// Smoothed value
        var Tt: Double = -1; /// Trend
        
        switch usageCounter {
        case 0: // There is no Lprev nor Tprev, so we can't smooth
            Lt = Yt
        case 1:
            // There is Lprev but no real Tprev. But we create a fake Tprev so we can already apply the normal smoothing algorithm.
            // This seems like a weird hack but it follows the "Holt–Winters double exponential smoothing" algorithm described on this Wiki page https://en.wikipedia.org/wiki/Exponential_smoothing#Double_exponential_smoothing (if I understand it correctly)
            Tprev = Yt - Lprev; // (Lprev is effectively Yprev at this point, because Lt was set to Yt in the previous step)
            fallthrough
        default: // Lprev and Tprev exist, we can use normal smoothing algorithm
            Lt = a * Yt  + (1 - a) * (Lprev + Tprev)
            Tt = y * (Lt - Lprev) + (1 - y) * Tprev
        }
        usageCounter += 1;
        
        Lprev = Lt
        Tprev = Tt
        
        return Lt
    }
    
    @objc func predictValue(stepsIntoFuture steps: Int) -> Double {
        let Ypred = Lprev + Double(steps) * Tprev
        return Ypred
    }
    
}
