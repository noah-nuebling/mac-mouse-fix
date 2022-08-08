//
//  AppState.swift
//  tabTestStoryboards
//
//  Created by Noah Nübling on 2/11/22.
//

/// Don't overuse this or things will get messy!

import Cocoa
import ReactiveSwift

@objc class MainAppState: NSObject {
    
    /// Declare singleton instance
    @objc static let shared = MainAppState()
    
    /// Vars
    var appIsEnabled = MutableProperty(false)
    
    /// References
    @objc var window: ResizingTabWindow? {
        return NSApp.mainWindow as? ResizingTabWindow
    }
    
}
