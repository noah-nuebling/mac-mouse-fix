//
// --------------------------------------------------------------------------
// StatusBarItem.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Foundation

@objc class StatusBarItem: NSObject {
    
    static var statusItem: NSStatusItem? = nil
    @objc static func load_Manual() {
        
        /// Setup statusbar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
//        statusItem?.button?.title = "Mac Mouse Fix"
        var image = NSImage(named: NSImage.Name("CoolStatusBarIcon"))
        statusItem?.button?.image = image
        
    }
}
