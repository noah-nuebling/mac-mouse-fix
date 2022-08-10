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
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
//        statusItem?.button?.title = "Mac Mouse Fix"
        var image = NSImage(named: NSImage.Name("Icon Status Badge"))
        image = Bundle.main.image(forResource: NSImage.Name("Icon Status Badge"))
        let imageURL = Bundle.main.url(forResource: "Key", withExtension: ".png")
        statusItem?.button?.image = image
        
    }
}
