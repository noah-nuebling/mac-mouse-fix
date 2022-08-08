//
//  NSControl+Extensions.swift
//  tabTestStoryboards
//
//  Created by Noah Nübling on 12/31/21.
//

import Cocoa
import ReactiveCocoa
import ReactiveSwift

extension Reactive where Base : NSControl {
    
    /// Signals that listen to NSControl values only fire when that control invokes it's action.
    ///     When you programatically change the value, then the action isn't fired
    ///     This provides convenience methods for forcing the signal to fire after programatically changing the value
    
    func forceSignalFire() {
        base.sendAction(base.action, to: base.target) /// Not sure if this is the best way to force firing
    }
    
}
