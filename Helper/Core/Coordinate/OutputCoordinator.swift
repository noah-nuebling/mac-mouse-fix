//
// --------------------------------------------------------------------------
// File.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
// 

/// NOTE: This is unused. See below for more info

/// Temporarily disable other modules that drive touch events other than the caller.
///     Guarantee: Other modules completely stop sending touch events *before* this function returns
///     This means the suspend() functions that will be called on the other modules must have this property as well.
///
/// \discussion: This makes things way less responsive especially when trying to zoom and pan around at the same time in apps like Sketch. There's a little but of jank that this adds in some apps but I haven't found anything significant. If we do need to separate events out at some point, here's a better idea:
///         Do it in the TouchSimulators. Have a thin layer over the touchsimulators that knows which types of TouchSimulation are compatible. Have it keep track of which Driver is driving which TouchSimulator. Make it ignore input from Drivers that don't have access to a simulator. You seize access to a Simulator (and all Simulators that are incompatible with it) by simply sending an event with phase start. This should give us much more granular control over which TouchSimulations we allow simultaneously.

import Foundation

@objc class OutputCoordinator: NSObject {

    @Atomic static var someoneIsSuspending = false
    
    @objc static func suspendTouchDrivers(fromDriver driver: TouchDriver) -> DriverUnsuspender? {
        
        /// Disable
        return {}
        
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
