//
// --------------------------------------------------------------------------
// TrialNotificationController.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

/// Also see ToastNotifications in the mainApp. They work similarly.

import Cocoa

class TrialNotificationController: NSWindowController {

    
    /// Singleton
    @objc static let shared = TrialNotificationController(window: nil)
    
    /// Init
    
    override init(window: NSWindow?) {
        
        if window == nil {
            super.init(window: nil)
            let nib = NSNib(nibNamed: "TrialNotificationController", bundle: nil)
            
            var topLevelObjects: NSArray?
            nib?.instantiate(withOwner: self, topLevelObjects: &topLevelObjects)
            self.window = topLevelObjects![0] as? NSWindow
            if self.window == nil {
                self.window = topLevelObjects![1] as! NSWindow
            }
            
        } else {
            super.init(window: window)
        }
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Lifecycle
    override func windowDidLoad() {
        super.windowDidLoad()

        /// Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    }
    
    /// Interface
    
    var firstAppearance = true
    @objc func open(daysOfUse: Int, trialDays: Int, userInitiated: Bool) {
        
        window?.makeKeyAndOrderFront(self)
        
        /// Make appearance notification-ish
        ///     Src: https://developer.apple.com/forums/thread/125232?answerId=392168022#392168022

        if firstAppearance {
            
            /// Create effectView
            
            let windowFrame = self.window!.frame
            let effect = NSVisualEffectView(frame: windowFrame)
            effect.blendingMode = .behindWindow
            effect.state = .active
            if #available(OSX 10.14, *) {
                effect.material = .underWindowBackground
            } else {
                effect.material = .dark
            }
            effect.wantsLayer = true
//            effect.layer?.borderColor = .clear
            
            /// Set corner radius
            /// Notes:
            /// - 16 matches system notifications on Ventura
            /// - 20 matches widgets on Ventura
            
            effect.layer?.cornerRadius = 20.0
            
            /// Swap out contentView -> effectView
            let ogContent = self.window!.contentView!
            effect.addSubview(ogContent)
            self.window?.contentView = effect
            
            /// Style window
            self.window?.titlebarAppearsTransparent = true
            self.window?.titleVisibility = .hidden
            self.window?.isOpaque = false
            self.window?.backgroundColor = .clear
        }
        firstAppearance = false
    }
    
    @objc override func close() {
        super.close()
    }
}
