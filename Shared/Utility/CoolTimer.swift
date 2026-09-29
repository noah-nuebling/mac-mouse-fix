//
// --------------------------------------------------------------------------
// CoolTimer.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// Make block-based timer available for macOS versions before 10.12
///     Edit: This is obsolete now since we're dropping support for 10.12 and earlier with MMF 2.2.1

import Cocoa

@objc fileprivate class BlockKeeper: NSObject {
    var block: (Timer) -> () = {_ in }
    @objc func timerFireMethod(timer: Timer) {
        block(timer)
    }
}

@objc class CoolTimer: NSObject {

    @objc static func scheduledTimer(timeInterval: TimeInterval, repeats: Bool, runLoop: CFRunLoop, block: @escaping (Timer) -> ()) -> Timer {

        /// Note: [2026] Wont work on `dispatch_queues` and detached threads, if you pass `CFRunLoopGetCurrent()` since noone ever runs those runloops
        ///     Old note from DockSwipe simulator which was (one of?) the place where we had a bug because of this: (Were running on sime dispatchQueue worker and used [NSTimer scheduledTimer...]
        ///         27.08.2024 (macOS Sequoia Beta) - The double/triple send didn't work. I fixed it by adding  `dispatch_async(dispatch_get_main_queue()`. Not sure how long this had been broken. (Fixed in e8f90d2f32829e3e5f1621fa8e4b58634c9ea07b)

        let blockKeeper = BlockKeeper()
        blockKeeper.block = block

        let timer = Timer(timeInterval: timeInterval, target: blockKeeper, selector: #selector(BlockKeeper.timerFireMethod(timer:)), userInfo: nil, repeats: repeats)
        CFRunLoopAddTimer(runLoop, timer as CFRunLoopTimer, .commonModes)

        return timer
    }
}
