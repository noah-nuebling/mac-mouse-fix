//
// --------------------------------------------------------------------------
// MenuBarItem.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Foundation

@objc class MenuBarItem: NSObject {
    
    static var instance: MenuBarItem? = nil
    @IBOutlet var menu: NSMenu!
    var statusItem: NSStatusItem? = nil
    var topLevelObjects: NSArray? = []
    
    @objc static func load_Manual() {
        instance = MenuBarItem()
        Bundle.main.loadNibNamed(NSNib.Name("MenuBarItem"), owner: instance, topLevelObjects: &(instance!.topLevelObjects))
    }
    
    override func awakeFromNib() {
        /// Setup statusbar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "Mac Mouse Fix"
        let image = NSImage(named: NSImage.Name("CoolMenuBarIcon"))
        statusItem?.button?.image = image
        statusItem?.menu = menu
        statusItem?.isVisible = false
        
        /// Configure
        MenuBarItem.reload()
    }
    
    // MARK: Load from config
    
    @objc static func reload() {
        let shouldShow = config("Other.showMenuBarItem") as? Bool
        if shouldShow != nil, shouldShow! == true {
            instance?.statusItem?.isVisible = true
            return
        }
        instance?.statusItem?.isVisible = false
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
