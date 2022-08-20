//
// --------------------------------------------------------------------------
// CoolTimer.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
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
        /// Note: Remember to schedule timers from the main thread! Otherwise they won't work.
        
        let blockKeeper = BlockKeeper()
        blockKeeper.block = block
        
        let timer = Timer.scheduledTimer(timeInterval: timeInterval, target: blockKeeper, selector: #selector(BlockKeeper.timerFireMethod(timer:)), userInfo: nil, repeats: repeats)
        
        return timer
    }
}
