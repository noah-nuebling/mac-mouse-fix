//
// --------------------------------------------------------------------------
// TrialNotificationController.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Cocoa

class TrialNotificationController: NSWindowController {

    
    /// Singleton
    @objc static let shared = TrialNotificationController()
    
    /// Lifecycle
    override func windowDidLoad() {
        super.windowDidLoad()

        /// Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    }
    
    /// Interface
    
    @objc func open(daysOfUse: Int, trialDays: Int, userInitiated: Bool) {
        
        window?.makeKeyAndOrderFront(self)
    }
    
    @objc override func close() {
        super.close()
    }
    
}
