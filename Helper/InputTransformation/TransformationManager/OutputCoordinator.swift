//
// --------------------------------------------------------------------------
// File.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Foundation

@objc class OutputCoordinator: NSObject {
    
    @objc static func handleTouchSimulationWillStart(fromDriver driver: TouchDriver) {
        /// This call should be synchronous. So it should only return, once it's cleaned up all the state from the other touch drivers. So that means the functions that this calls (`cancelAndReInitialize`) should be synchronous in this sense as well.
        ///     Other way to put this: `cancelAndReInitialize` needs prevent any output being generated before returning
        
        
        /// Cancel and then restart other touch simulation drivers
        
        if driver != kTouchDriverScroll {
            Scroll.cancelAndReInitialize()
        }
        if driver != kTouchDriverModifiedDrag {
            ModifiedDrag.cancelAndReInitialize()
        }
        if driver != kTouchDriverGestureScrollSimulator {
            GestureScrollSimulator.cancelMomentumScroll()
        }
        
    }
}
