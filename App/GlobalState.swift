//
//  GlobalState.swift
//  tabTestStoryboards
//
//  Created by Noah Nübling on 2/11/22.
//

/// Don't overuse this or things will get messy!

import Cocoa
import ReactiveSwift

class GlobalState: NSObject {
    
    /// Declare singleton instance
    static let shared = GlobalState()
    
    /// Vars
    var appIsEnabled = MutableProperty(false)
    
    /// References
    var window: ResizingTabWindow? {
        return NSApp.mainWindow as? ResizingTabWindow
    }
    
}
