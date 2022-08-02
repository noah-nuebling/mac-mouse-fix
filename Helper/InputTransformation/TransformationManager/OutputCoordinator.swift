//
// --------------------------------------------------------------------------
// File.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Foundation
import CocoaLumberjackSwift

@objc class OutputCoordinator: NSObject {

    @Atomic static var someoneIsSuspending = false
    
    @objc static func suspendTouchDrivers(fromDriver driver: TouchDriver) -> DriverUnsuspender? {
        /// Temporarily disable other modules that drive touch events other than the caller.
        ///     Guarantee: Other modules completely stop sending touch events *before* this function returns
        ///     This means the suspend() functions that will be called on the other modules must have this property as well.
        ///
        /// \discussion: This is neccessary because things get messy when several modules try to send touch events at the same time. Especially when they are all trying to send the same type of event the order of event phases will get messed up and the system will be confused.
        
        /// Prevent deadlocks
        if someoneIsSuspending { return {} } /// You can't suspend - you'll be suspended!
        someoneIsSuspending = true
        defer { someoneIsSuspending = false }
        
        /// Declare unsuspender
        var unsuspender: (() -> ())? = nil
        
        /// Hack? But works fine. Otherwise deadlocks in `ModifiedDragOutputTwoFingerSwipe` and `Scroll.m`
        if driver == kTouchDriverGestureScrollSimulator {
            return {}
        }
        
        /// Suspend other touch simulation drivers
        if driver != kTouchDriverScroll {
            Scroll.suspend()
        }
        if driver != kTouchDriverModifiedDrag {
            unsuspender = ModifiedDrag.suspend()
        }
        if driver != kTouchDriverGestureScrollSimulator {
            GestureScrollSimulator.suspendMomentumScroll()
        }
        
        /// Return
        return unsuspender
    }
}
