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
    
    @objc static func suspendTouchDrivers(fromDriver driver: TouchDriver) -> DriverUnsuspender? {
        /// This call should be synchronous. So it should only return, once it's cleaned up all the state from the other touch drivers. So that means the functions that this calls (`cancelAndReInitialize`) should be synchronous in this sense as well.
        ///     Other way to put this: `cancelAndReInitialize` needs prevent any output being generated before returning
        
        
        /// Cancel and then restart other touch simulation drivers
        
        if driver == kTouchDriverGestureScrollSimulator {
            /// Hack? Otherwise deadlocks in `ModifiedDragOutputTwoFingerSwipe` and `Scroll.m`
            return {}
        }
        
        if driver != kTouchDriverScroll {
            DDLogDebug("Canceling scroll")
            Scroll.suspend()
        }
        var unsuspendDrag: (() -> ())? = nil
        if driver != kTouchDriverModifiedDrag {
            DDLogDebug("Canceling drag")
            unsuspendDrag = ModifiedDrag.suspend()
        }
        if driver != kTouchDriverGestureScrollSimulator {
//            DDLogDebug("Canceling momentum")
            GestureScrollSimulator.suspendMomentumScroll()
        }
        
        return unsuspendDrag
    }
}
