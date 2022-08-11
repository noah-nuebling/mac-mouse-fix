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
    
    static var instance: StatusBarItem? = nil
    @IBOutlet var menu: NSMenu!
    var statusItem: NSStatusItem? = nil
    var topLevelObjects: NSArray? = []
    
    @objc static func load_Manual() {
        instance = StatusBarItem()
        Bundle.main.loadNibNamed(NSNib.Name("StatusBarItem"), owner: instance, topLevelObjects: &(instance!.topLevelObjects))
    }
    
    override func awakeFromNib() {
        /// Setup statusbar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "Mac Mouse Fix"
        let image = NSImage(named: NSImage.Name("CoolStatusBarIcon"))
        statusItem?.button?.image = image
        statusItem?.menu = menu
    }
    
    // MARK: Actions
    
    @IBAction func openMMF(_ sender: Any) {
        HelperUtility.openMainApp()
    }
    
    @IBAction func disableScroll(_ sender: Any) {
    }
    
    @IBAction func disableButtons(_ sender: Any) {
    }
}
