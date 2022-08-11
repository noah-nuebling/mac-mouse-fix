//
// --------------------------------------------------------------------------
// MenuBarItem.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

/// This uses non-reactive state management. It's so complicated even for this simple example!

import Foundation

@objc class MenuBarItem: NSObject {
    
    var topLevelObjects: NSArray? = []
    static var instance: MenuBarItem? = nil
    
    var statusItem: NSStatusItem? = nil
    @IBOutlet var menu: NSMenu!
    
    @IBOutlet weak var disableScrollItem: NSMenuItem!
    @IBOutlet weak var disableButtonsItem: NSMenuItem!
    
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
        
        var shouldShow = config("Other.showMenuBarItem") as? Bool
        if shouldShow == nil { shouldShow = false }
        instance?.statusItem?.isVisible = shouldShow!
        
        if shouldShow! {
            
            var buttonsKilled = config("Other.buttonKillSwitch") as? Bool
            if buttonsKilled == nil { buttonsKilled = false }
            var scrollKilled = config("Other.scrollKillSwitch") as? Bool
            if scrollKilled == nil { scrollKilled = false }
            
            instance?.disableButtonsItem.state = buttonsKilled! ? .on : .off
            instance?.disableScrollItem.state = scrollKilled! ? .on : .off
            
            return
        } else {
            
            /// Disable all settings from the menuItem, if the menuItem is disabled
            
            setConfig("Other.scrollKillSwitch", false)
            setConfig("Other.buttonKillSwitch", false)
        }
    }
    
    // MARK: Actions
    
    @IBAction func openMMF(_ sender: Any) {
        HelperUtility.openMainApp()
    }
    
    @IBAction func disableScroll(_ sender: NSMenuItem) {
        
        /// Toggle
        sender.state = sender.state == .on ? .off : .on
        /// Set to config
        setConfig("Other.scrollKillSwitch", sender.state == .on) // TODO: Merge the two config managers now that the Helper want to write to config as well.
    }
    
    @IBAction func disableButtons(_ sender: NSMenuItem) {
        
        /// Toggle
        sender.state = sender.state == .on ? .off : .on
        /// Set to config
        setConfig("Other.buttonKillSwitch", sender.state == .on)
    }
}
