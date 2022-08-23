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
    
    /// Outlets & actions
    
    @IBOutlet weak var body: NSTextField!
    
    @IBAction func closeButtonClick(_ sender: Any) {
        self.close()
    }
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
        
        /// Unwrap window
        
        guard let window = self.window else { return }
        
        /// Make appearance notification-ish
        ///     Src: https://developer.apple.com/forums/thread/125232?answerId=392168022#392168022
        ///     Note: Should probably do this in some init func like viewDidLoad.

        if firstAppearance {
            
            /// Create effectView
            
            let windowFrame = window.frame
            let effect = NSVisualEffectView(frame: windowFrame)
            effect.blendingMode = .behindWindow
            effect.state = .active
            if #available(OSX 10.14, *) {
                effect.material = .popover /**.underWindowBackground*/
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
            window.contentView = effect
            
            /// Style window
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isOpaque = false
            window.backgroundColor = .clear
        }
        firstAppearance = false
        
        /// Make window key
        window.makeKeyAndOrderFront(self)
        
        /// Set window above everything else
        window.level = .floating
        
        /// Set window immovable
        window.isMovable = false
        
        /// Calculate position
        ///     We want to place it in the top right of the screen where notification appear
        
        /// Get top right corner of current screen
        guard let visibleFrame = NSScreen.main?.visibleFrame else {
            return
        }
        let screenCorner = NSPoint(x: visibleFrame.maxX, y: visibleFrame.maxY)
        let notifCorner = NSPoint(x: screenCorner.x - 20, y: screenCorner.y - 18)
        let notifOrigin = NSPoint(x: notifCorner.x - window.frame.width, y: notifCorner.y - window.frame.height)
        
        /// Get newFrame
        let newFrame = NSRect(x: notifOrigin.x, y: notifOrigin.y, width: window.frame.width, height: window.frame.height)
        
        /// Get animStartFrame
        let animStartFrame = NSRect(x: visibleFrame.maxX, y: newFrame.origin.y, width: newFrame.width, height: newFrame.height)
        
        /// Place window at animStart
        window.setFrame(animStartFrame, display: false, animate: false)
        
        setFrameWithCoolAnimation(animStartFrame, newFrame, window)
    }
    
    @objc override func close() {
//        super.close()
        
        /// Unwrap window and screen
        guard
            let window = self.window,
            let screen = NSScreen.main
        else { return }
        
        /// Get start and end frames
        let start = window.frame
        let end = NSRect(x: screen.visibleFrame.maxX, y: start.origin.y, width: start.width, height: start.height)
        
        /// Animate
        setFrameWithCoolAnimation(start, end, window, onComplete: {
            super.close()
        })
    }
    
    /// Helper stuff
    
    fileprivate func setFrameWithCoolAnimation(_ animStartFrame: NSRect, _ newFrame: NSRect, _ window: NSWindow, onComplete: (() -> ())? = nil) {
        /// Animate window in
        ///     Note: We're doing the same thing in ResizingTabWindow. -> Think about abstracting this away
        let animation = CASpringAnimation(speed: 3.5, damping: 1.0)
        let animator = DynamicSystemAnimator(fromAnimation: animation, stopTolerance: 0.1)
        animator.start(distance: 1.0, callback: { value in
            var f = SharedUtilitySwift.interpolateRects(value, animStartFrame, newFrame)
            f = NSIntegralRectWithOptions(f, .alignAllEdgesNearest)
            window.setValue(f, forKey: "frame")
        }, onComplete: {
            onComplete?()
        })
    }
}
