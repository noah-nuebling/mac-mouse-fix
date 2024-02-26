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

    @objc static func scheduledTimer(timeInterval: TimeInterval, repeats: Bool, block: @escaping (Timer) -> ()) -> Timer {
        
        /// Notes:
        /// - Remember to schedule timers from the main thread! Otherwise they won't work.
        /// - Udpate: ^^ This doesn't really make sense? The docs say that Timer.scheduledTimer schedules the timer on the current runLoop, in the default mode. (Maybe we needed commonMode in the scenario where it didn't work?)
        ///     - TODO: At the time of writing, it seems like we're doing the whole button input processing on the mainThread (maybe that's why we had to run this timer on the main thread as well for things to work). We should probably do it on the GlobalEventTapThread instead - so the mainThread is free for drawing UI stuff and we prevent race conditions by handling all the input on one thread.
        ///     - As an alternative for NSTimer there's also DispatchSourceTimer - that might be nicer/faster
        
        let blockKeeper = BlockKeeper()
        let timer = Timer.scheduledTimer(timeInterval: timeInterval, target: blockKeeper, selector: #selector(BlockKeeper.timerFireMethod(timer:)), userInfo: nil, repeats: repeats)
        
        return timer
    }
}
