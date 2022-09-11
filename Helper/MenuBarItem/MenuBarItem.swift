//
// --------------------------------------------------------------------------
// MenuBarItem.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

/// This uses non-reactive state management. It's so complicated even for this simple example!

/**
 Also see:
 https://github.com/noah-nuebling/mac-mouse-fix/issues/190
 
 */

import Foundation

@objc class MenuBarItem: NSObject {
    
    var topLevelObjects: NSArray? = []
    static var instance: MenuBarItem? = nil
    
    var statusItem: NSStatusItem? = nil
    @IBOutlet var menu: NSMenu!
    
    @IBOutlet weak var scrollEnabledItem: NSMenuItem!
    @IBOutlet weak var buttonsEnabledItem: NSMenuItem!
    
    @IBOutlet weak var appCompatItem: NSMenuItem!
    @IBOutlet var appCompatView: NSView!
    
    @IBOutlet weak var appCompatHintItem: NSMenuItem!
    @IBOutlet var appCompatHintView: NSView!
    
    @objc static func load_Manual() {
        instance = MenuBarItem()
        Bundle.main.loadNibNamed(NSNib.Name("MenuBarItem"), owner: instance, topLevelObjects: &(instance!.topLevelObjects))
        instance?.load_Manual()
    }
    
    func load_Manual() {
        
        /// Setup statusbar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.autosaveName = "MMFMenuBarItem" /// Probably unnecessary
        statusItem?.button?.title = ""
        let image = NSImage(named: NSImage.Name("CoolMenuBarIcon"))
        statusItem?.button?.image = image
        statusItem?.menu = menu
//        statusItem?.isVisible = false /// This makes the item forget its position when restarting the computer
        
        /// Setup group menu item
        /// `.indentationLevel` doesn't work. Do indentation in IB autolayout instead
        appCompatItem.view = appCompatView
        
        /// Turn off group item
//        menu.removeItem(appCompatItem)
        
        /// Setup hint menu item
        appCompatHintItem.view = appCompatHintView
        
        /// Turn off hint
        menu.removeItem(appCompatHintItem)
        
        /// Load state
        MenuBarItem.reload()
    }
    
    // MARK: Load from config
    
    @objc static func reload() {
        
        let shouldShow = config("Other.showMenuBarItem") as? Bool ?? false
        instance?.statusItem?.isVisible = shouldShow
        
        let buttonsKilled = config("Other.buttonKillSwitch") as? Bool ?? false
        let scrollKilled = config("Other.scrollKillSwitch") as? Bool ?? false
        
        if shouldShow {
            
            instance?.buttonsEnabledItem.state = !buttonsKilled ? .on : .off
            instance?.scrollEnabledItem.state = !scrollKilled ? .on : .off
            
            return
            
        } else {
            
            /// Disable all settings from the menuItem, if the menuItem is disabled
            /// Need to do the killed check to prevent infinite loops. (Not sure if true anymore). This would be easier if we just used the reactive ConfigValue instead.
            
            if (buttonsKilled || scrollKilled) {
                setConfig("Other.scrollKillSwitch", false as NSObject)
                setConfig("Other.buttonKillSwitch", false as NSObject)
                commitConfig()
            }
        }
    }
    
    // MARK: Actions
    
    @IBAction func openMMF(_ sender: Any) {
        HelperUtility.openMainApp()
    }
    
    @IBAction func disableScroll(_ sender: NSMenuItem) {
        
        // TODO: Fix bug where scrolling freezes after turning smooth scroll back on
        
        /// Toggle
        sender.state = sender.state == .on ? .off : .on
        /// Set to config
        setConfig("Other.scrollKillSwitch", !(sender.state == .on) as NSObject)
        commitConfig()
    }
    
    @IBAction func disableButtons(_ sender: NSMenuItem) {
        
        /// Toggle
        sender.state = sender.state == .on ? .off : .on
        /// Set to config
        setConfig("Other.buttonKillSwitch", !(sender.state == .on) as NSObject)
        commitConfig()
    }
    
    @IBAction func checkUpdates(_ sender: Any) {
        
        /// Implement?
    }
    
}
