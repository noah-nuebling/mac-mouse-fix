//
// --------------------------------------------------------------------------
// MenuBarItem.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
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
    
    @IBOutlet weak var disableScrollItem: NSMenuItem!
    @IBOutlet weak var disableButtonsItem: NSMenuItem!
    
    @IBOutlet weak var appCompatItem: NSMenuItem!
    @IBOutlet var appCompatView: NSView!
    
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
        
        /// Setup menu strings
        if #available(macOS 13, *) {
            /// TESTING. Make this available before macOS 13.
            do {
                /// Set markdown. (Doesn't seem to do anything)
                disableScrollItem.attributedTitle = try NSAttributedString(markdown: "Smooth Scrolling")
                disableButtonsItem.attributedTitle = try NSAttributedString(markdown: "Mouse Buttons Remaps")
            } catch {
                fatalError()
            }
        } else {
            disableScrollItem.title = "Turn off Smooth Scrolling"
            disableButtonsItem.title = "Turn off Mouse Button Remaps"
        }
        
        /// Setup group item
        /// `.indentationLevel` doesn't work. Do indentation in IB instead
        appCompatItem.view = appCompatView
        appCompatItem.isHidden = true /// Doesn't work?
        
        /// Configure
        MenuBarItem.reload()
    }
    
    // MARK: Load from config
    
    @objc static func reload() {
        
        let shouldShow = config("Other.showMenuBarItem") as? Bool ?? false
        instance?.statusItem?.isVisible = shouldShow
        
        if shouldShow {
            
            let buttonsKilled = config("Other.buttonKillSwitch") as? Bool ?? false
            let scrollKilled = config("Other.scrollKillSwitch") as? Bool ?? false
            
            instance?.disableButtonsItem.state = !buttonsKilled ? .on : .off
            instance?.disableScrollItem.state = !scrollKilled ? .on : .off
            
            return
        } else {
            
            /// Disable all settings from the menuItem, if the menuItem is disabled
            setConfig("Other.scrollKillSwitch", true as NSObject)
            setConfig("Other.buttonKillSwitch", true as NSObject)
            commitConfig()
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
}
