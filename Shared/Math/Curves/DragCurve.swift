//
// --------------------------------------------------------------------------
// DragCurve.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//


/**
 Models the the effects of drag forces. Drag forces are like friction forces, but magnitude depends on the current speed
 It's easier in to just use the differential drag definition directly and calculate a new speed every frame based on the previous speed. And then figure out how far to animate each frame based on that speed.
 But you can also solve the differential drag equations in to get d(t) and v(t) functions (distance / velocity for a given time).
 These solved drag equations are what this class provides.
 The solved drag equations have the advantage, that we can simply plug them into our existing Animator.swift class.
 And they also allow us to analyze the animation in a deeper way.
 For example they let us find out how long and how far we'll animate for before coming to a stop, by setting v(t) to 0 and solving for t, and then plugging that t back into d(t).
 That kind of thing is not easy is not easy if you use the frame by frame based approach.
 Also mathsy stuff is fun and I really need to stop overengineering things but I can't please help.
 */

/**
 Here are the relevant __formulas__.
 Use these to solve/view them:
 - https://www.wolframalpha.com/
 - https://www.desmos.com/calculator/c4g8u0ysvd
 
 
 # Drag definition
 (Aka. "The differential equation")
 ```
 v'(t) = - a v(t)^b
 ```
 Source Wikipedia. Simplified and adapted for our needs.
- Stripped away things that depend on mass and area of the object and stuff
- Made the exponent into a variable (b) instead of 2. To be able to control the feel of the curve better.
 
 # Speed equation
 (Aka. Solved differential equation)
 ```
 v(t) = ((b - 1) (a t + c))^(1/(1 - b))
 ```
 Altered slightly, so that c is the time offset: that way it might be easier to deal with / reason about
 ```
 v(t)=((b-1)(a(t-c)))^{(1/(1-b))}
 ```
 - ^ WA can't integrate this for some reason.
 ```
 v(t) = ((b - 1) (a (t - c)))^(1/(1 - b))
 ```
 - ^ I wrote the equation more like the original and now WA __can__ integrate it. Weird
 - `c` shifts the curve along the t axis
 
 Edit: We need to use different functions for b == 1 and b == 2. here are the equations for copy-pasting
    (b == 1)
    `v(t) = e^(-a (t - c))`
    (b == 2)
    `v(t) = 1/(a (t - c))`
 
 Now we want to __solve for c__, so we can ask:
 - What is the c that gives us the curve for an initial speed of v_0?
 - Or phrased differently: what is the c such that the curve crosses the v axis at v_0
 - Or phrased differently: what is the c such that the curve passes through the point: (t: 0, v: v_0)
 
 I can't get Wolfram Alpha to solve for c so we'll solve it on paper.
 Result
 ```
 c = t - ( (v^{1-b}) / ((b-1)a) )
 ```
 ^ (I might have made a mistake with the signs. Just flip the sign if this doesn't work)
 
 Now we want to solve for t, so we can ask:
 - At which point in time does the curve stop moving
 - Or phrased differently: At which t does v(t) become (reasonably close to) 0
 
 ```
 t = v^{1 - b}/(a (b - 1)) + c
 ```
 ^ (WA says: Only valid where a (b - 1) v^b != 0)
 
 # Distance equation
 (Aka. Indefinite Integral or antiderivative of the speed equation)
 ```
 d(t) = (a (b - 1) (t - c))^(1/(1 - b) + 1)/(a (b - 2)) + k
 ```
 - `k` shifts the curve along the d axis
 - This isn't defined for b = 2. We want to use b = 2. That's a problem.
 
 Edit: We need to use different equations for b == 1 and b == 2. Here they are for copy-pasting
    (b == 1)
    `d(t) = -e^(a (c - t))/a + k`
    (b == 2)
    `d(t) = log(t - c)/a + k`
 
 Now we want to solve for k so we can ask:
 - What is the k that gives us the curve that starts at distance 0
 - Or phrased differently: what is the k such that the curve passes through (t: 0, d: 0)
 
```
 k = ((b - 1) (c - t) (a (b - 1) (t - c))^(1/(1 - b)))/(b - 2) + d
 ```
 ^ WA says this is only valid where b != 2 and a != 0. The requirement that b != 0 might be a problem
 
 Or we can simply get k such that the curve passes through (t, d) with `k = -d(t) + d`. Where d(t) is defined as above but with k=0.
 
 That's it. Now we have all the formulas ready!
 
 Edit:
 Our formula for d(t) isn't define at b=2, so here's another formula for b=2. We got this by plugging b=2 into our v(t) equation and then letting WA integrate it.
 ```
 d(t) = log(a (c - t))/a + k
 ```
 ^ Where log(x) is the natural log
 
 Edit 26. June 21
 I'm trying to actually put this to use for momentum scrolling right now, and I've noticed that almost none of the functions we defined were defined when b was 1. That lead to division by zero on most of them. A few weren't even defined for b == 2. So What I did now is add special formulas for when b == 1 and changed some other formulas around so they work with b == 1. I (sloppily) documented the way that I arrived at these new formulas in the function bodies. Basically I just used Wolfram Alpha and did the same thing as above just plugging in 1 for b.
 
 Edit 13. Feb 22
 We want to create drag curves based on overall distance now
 For that we need to solve d(t) for c, and we need to solve d(t) for t.
 For the c solution we used the same logic as for the k solution. For the t solution we used WA
 
 `t = ((a (2 - b) k)^(-1/(b - 2)) (-a c (a (2 - b) k)^(1/(b - 2)) + a b c (a (2 - b) k)^(1/(b - 2)) + (a (2 - b) k)^(b/(b - 2))))/(a (b - 1))`
 
 (b == 1)
    `t = c - log(a k)/a`
        (for and a>0 and k>0)
 (b == 2)
    `t = e^(-a k) + c`
        (for a!=0)
 
 
 */


import Foundation

@objc class DragCurve: Curve {

    private var a: Double
    private var b: Double
    private var c: Double
    private var k: Double
    
    private var isNegative: Bool
    
    @objc var timeInterval: Interval
    private var _distanceInterval: Interval
    @objc var distanceInterval: Interval {
        get {
            if self.isNegative {
                return Interval.init(start: -_distanceInterval.start, end: -_distanceInterval.end)
            }
            return _distanceInterval
        }
    }

    @objc init(coefficient: Double, exponent: Double, distance d: Double, stopSpeed vs: Double) {
        ///
        /// Distance-based init
        ///
        /// This is quite similar to the `Initial-speed-based init`. Make sure to keep both in sync when you make changes.
        
        /// Init everything to garbage so we can call super.init()
        
        // TODO: Test this and make it work
        
        a = 0
        b = 0
        c = 0
        k = 0
        isNegative = false
        timeInterval = .unitInterval
        _distanceInterval = .unitInterval
        
        /// Call super init
        
        super.init()
        
        /// Validate input
        
        assert(exponent >= 0)
        assert(coefficient > 0)
        assert(SharedUtility.sign(of: d) == SharedUtility.sign(of: vs))
        assert(vs > 0)
        
        /// Store curve shape
        self.a = coefficient
        self.b = exponent

        /// Get t for stop speed
        ///     Since c=0, this is not the true stop time `t_s`, but instead it's `t_s - c`. (I think)
        let t_s0 = solveT(v: vs, c: 0)

        /// Get k
        ///     So that the whole curve will cover a distance of `d`
        self.k = solveK(d: d, t: t_s0, c: 0)
        
        /// Get c
        ///     Such that the curve passes through (d=0, t=0)
        self.c = solveC(d: 0, t: 0, k: self.k)
        
        /// Get time to stop
        let timeToStop = t_s0 + c
        self.timeInterval = Interval(0, timeToStop)
        
        /// Get distance to stop
        /// -> From curve
        ///     We could also use `d`, but that might not match the curve and time interval exactly due to rounding errs in the previous calculations

        let distanceToStop = solveD(t: timeToStop, c: self.c, k: self.k)
        self._distanceInterval = Interval(0, distanceToStop)
        
        /// Validate / Debug
        
        assert(abs(timeInterval.length) != Double.infinity)
        
        let v0 = solveV(t: 0, c: self.c)
        assert(abs(v0) > abs(vs))
        
        // TODO: We're not storing the timeInterval and _distanceInterval
        //  Also I'm not sure if we need to scale the stop time or sth
        
//        DDLogDebug("DragDurve initialized with v0: \(v0), distance int: \(self._distanceInterval), timeToStop: \(timeToStop)");
        
    }
    
    @objc init(coefficient: Double, exponent: Double, initialSpeed v0_arg: Double, stopSpeed vs_arg: Double) {
        
        /// Initial-speed-based init
        
        /// Speed will never reach 0 exactly so we need to specify `stopSpeed`, the speed at which we consider it stopped
        
        /// Initialize everything so Swift doesn't complain when we use instance methods and call super.init()
        
        a = 0
        b = 0
        c = 0
        k = 0
        isNegative = false
        timeInterval = .unitInterval
        _distanceInterval = .unitInterval
        
        /// Init super so Swift doesn't complain when we use our own instance methods
        
        super.init()
        
        /// Do actual initialization
        
        /// Get mutable v0 and vs
        
        var v0 = v0_arg
        var vs = vs_arg
        
        /// Validate curve shape params
        assert(exponent >= 0)
        assert(coefficient > 0)
        
        /// Validate velocities
        ///     This asserts that everything is positive, which makes self.isNegative unused.
        
        assert(SharedUtility.sign(of: v0) == SharedUtility.sign(of: vs)) /// Same sign - Otherwise vs can't be reached at all
        assert(vs != 0) /// A speed of zero is unreachable
        assert(abs(v0) > abs(vs)) /// v0 > vs - Otherwise vs can only be reached in the past. So not at all. Also ensures v0 is not 0 which is important, as well
        assert(v0 > 0) /// This code could probably deal with negative v0, but the calling code should never input a negative v0, so we're asserting that here, too
        
        /// isNegative
        ///     The meat and potato calculations of this class don't work with a negative v0 and vs.
        ///     So if they are negative, we make everything positive and note that fact here, so we can do the main calculations as if v0 and vs were positive, and then flip the sign before we return the end result.
        ///     Actually I think we'll never use this, and this is untested, but we'll leave it in for now
        
        self.isNegative = SharedUtility.sign(of: v0) == -1
        
        /// Make positive if isNegative
        
        if self.isNegative {
            v0 *= -1
            vs *= -1
        }
        
        /// Store curve shape
        self.a = coefficient
        self.b = exponent
        
        /// Choose c such that v(t) passes through (v: v0, t: 0)
        c = solveC(v: v0, t: 0)
        
        /// Choose k such that d(t) passes through (d: 0, t: 0)
        k = solveK(d: 0, t: 0, c: c)
        
        /// Get time and distance to stop
        let timeToStop = solveT(v: vs, c: c)
        let distanceToStop = solveD(t: timeToStop, c: c, k: k)
        self.timeInterval = Interval(location: 0, length: timeToStop)
        self._distanceInterval = Interval(location: 0, length: distanceToStop)
        
        /// Asserts / Debug
        assert(abs(timeInterval.length) != Double.infinity)
//        DDLogDebug("DragDurve initialized with v0: \(v0), distance int: \(self._distanceInterval), timeToStop: \(timeToStop)");
    }
    
    /// v(t) (velocity over time)
    ///     There are 3 important variables in the v(t) equation: v, t, and c
    ///         (Also a and b but they just define the shape of the curve, and we never need to solve for them)
    ///
    ///     We can find each of these 3 variables, given the other 2, with the following 3 functions:
    
    private func solveV(t: Double, c: Double) -> Double {
        
        if (b == 1) {
            return pow(M_E, -a * (t - c))
            /// Solution for `v'(t) = - a v(t)^1` (so for b == 1) from WA
            ///     Also subtracting c from t, so c behaves like we expect (shifting the curve along the t axis)
        }
        
        return pow((b - 1) * (a * (t - c)), 1/(1 - b))
        /// ^ Always zero for b == 1
    }
    
    private func solveT(v: Double, c: Double) -> Double {
        /// Get the t where v(t) is v
        
        if (b == 1) {
            return (a * c -  log(v)) / a
            /// Source: WA ->`solve t: v = pow(e, -a * (t - c))`,
            /// Adaptions: Ignoring the `2 i π n` term, and wrapping log(v) with abs(v) and sign(v), because log(v) doesn't work when v is negative.
            ///     See `getC()` for more on these adaptions
        }
        
        return pow(v, 1 - b) / ((b - 1) * a) + c
        /// ^ This is undefined for b == 1
    }

    private func solveC(v: Double, t: Double) -> Double {
        /// Get c such that v(t) passes through the point (t, v)
        
        if (b == 1) {
            
            let result = (a * t + log(v)) / a
            /// The formula from WA for `solve c: v = pow(e, -a * (t - c))` is
            ///     `(a t + 2 i π n + log(v)) / a`
            ///     I have no clue where that 2 i π n comes from or what it means. What even is n?
            ///     But WA also tells me `solve x: y = e^x` is `x = log(y) + 2 i π n`, so I guess the 2 i π n is just some imaginary stuff we can ignore?
            /// Also we added sign(of:v) and abs(v) to prevent crashes on log(v) when v is negative. I haven't really thought about this and I'm not sure it makes sense.
            
            return result
        }
        
        return t - (pow(v, 1 - b) / ((b - 1) * a))
        /// ^ Not defined for b == 1
    }
    
    
    /// d(t) (distance over time)
    ///     There are 4 important variables in the d(t) equation: d, t, c, and k
    ///         (Also a and b but we don't have functions for them)
    ///
    ///     We can solve for each of these 4 variables, given the other 3, with the following 4 functions:
    
    private func solveD(t: Double, c: Double, k: Double) -> Double {
        
        if (b == 1) {
            return -pow(M_E, a * (c - t)) / a + k
            /// Solution for `integrate pow(e, -a * (t - c))` from WA
        }
        
        if (b == 2) {
            
//            let result = log(a * (c - t)) / a + k
            /// ^ This is only defined for b == 2
            ///
            ///    I'm dealing with in issue where this is always NaN for some reason. What's going on?
            ///    The problem is that log of a negative is NaN, and c is usually negative.
            ///     After integrating v(t) again with the WA input `integrate v(t) = ((b - 1) (a (t - c)))^(1/(1 - b)), where b=2`, I now get this formula:
            ///     log(t-c)/a + k -> that should work better!
            
            return log(t-c)/a + k
        }
        
        return pow(a * (b - 1) * (t - c), 1/(1 - b) + 1) / (a * (b - 2)) + k
            /// ^ Not defined for b == 1 or b == 2
            
//        return pow((a*b - a) * (t - c), 1/(1 - b) + 1) / (a*b - 2*a) + k
//        /// ^ Not defined for b == 1 or b == 2. Not sure whats the difference to the formula above
    }
    
    private func solveT(d: Double, c: Double, k: Double) -> Double {
        
        if b == 1 {
            return c - log(a * k) / a
        }
        if b == 2 {
            return pow(M_E, -a * k) + c
        }
        
        /// If we messed this up, see Apple Note `Figuring out solveT() (MMF)`
        return
            (pow(a * (2 - b) * k, -1/(b - 2))
             * (-a * c * pow(a * (2 - b) * k, 1/(b - 2))
                 +
                 a * b * c * pow(a * (2 - b) * k, 1/(b - 2))
                 +
                 pow(a * (2 - b) * k, b/(b - 2))
               )
            )
            /
            (a * (b - 1))
    }
    
    private func solveC(d: Double, t: Double, k: Double) -> Double {
        /// Get t where d(t) is d
        
        let T: Double = solveT(d: d, c: 0, k: k)
        
        return -(T - t)
    }
    
    private func solveK(d: Double, t: Double, c: Double) -> Double {
        /// Get k such that d(t) passes through the point (t, d)
        
        let D: Double = solveD(t: t, c: c, k: 0)
        
        return -(D - d)
    }
    
    /// Interface
    
    override func evaluate(at tUnit: Double) -> Double {
        /// Animator.swift expects its animation curves to pass through (0,0) and (1,1), so we'll scale our curve accordingly
        
        let t = Math.scale(value: tUnit, from: .unitInterval, to: timeInterval)
        let d = solveD(t: t, c: self.c, k: self.k)
        var dUnit = Math.scale(value: d, from: distanceInterval, to: .unitInterval)
        
        assert(dUnit > 0)
        
        if self.isNegative {
            dUnit *= -1
        }
        
        return dUnit
    }
}
