//
//  State.swift
//  tabTestStoryboards
//
//  Created by Noah Nübling on 2/11/22.
//

/// Don't overuse this or things will get messy!

import Cocoa
import ReactiveSwift

class State: NSObject {
    
    /// Declare singleton instance
    static let shared = State()
    
    /// Vars
    var appIsEnabled = MutableProperty(false)
    
    /// References
    var window: ResizingTabWindow? {
        return NSApp.mainWindow as? ResizingTabWindow
    }
    
}
