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
    
    @IBOutlet var body: NSTextView!
    @IBOutlet weak var bodyScrollView: NSScrollView!
    
    @IBOutlet weak var payButton: PayButton!
    @IBOutlet weak var trialTextField: NSTextFieldCell!
    @IBOutlet weak var activateLicenseButton: NSTextField!
    
    @IBAction func activateLicense(_ sender: Any) {
        NSWorkspace.shared.open(URL(string: "google.com")!)
    }
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
    
    @objc func open(licenseConfig: LicenseConfig, license: MFLicenseReturn) {
        
        /// Unwrap window
        
        guard let window = self.window else { return }
        
        /// Make appearance notification-ish
        ///     Src: https://developer.apple.com/forums/thread/125232?answerId=392168022#392168022
        ///     Note: Should probably do this in some init func like viewDidLoad.

        if firstAppearance {
            
            /// Init the payButton
            /// May be more elegant to do this from IB directly but whatever
            payButton.realInit(title: licenseConfig.formattedPrice) {
                NSWorkspace.shared.open(URL(string: licenseConfig.quickPayLink)!)
            }
            
            /// Set activateLicense text
            
            activateLicenseButton.stringValue = NSLocalizedString("activate-license", comment: "First draft: Activate License")
            
            /// Set the trialString
            trialTextField.attributedStringValue = LicenseUtility.trialCounterString(licenseConfig: licenseConfig, license: license)
            
            /// Set the bodyString
            
            let bodyBase = NSLocalizedString("trial-notification", comment: "First draft: Hi! You've been using Mac Mouse Fix for **%d days** now. I hope you're enjoying it!\n\nIf you want to keep using Mac Mouse Fix, you can [buy it now](%@).")
            let bodyFormatted = String(format: bodyBase, license.daysOfUse, licenseConfig.quickPayLink)
            let bodyMarkdown = NSAttributedString(coolMarkdown: bodyFormatted)!
            body.textStorage?.setAttributedString(bodyMarkdown)
            
            /// Layout contentView
            ///     So the width is up to date for the scrollView height calculation
            window.contentView?.needsLayout = true
            window.contentView?.layoutSubtreeIfNeeded()
            
            /// Set scrollView height
            ///     Note: Can't do this with autolayout ugh. Also can't use NSTextField, which would support autolayout, because it doesn't support links.
            ///     With body.frame.width we use the width from IB
            let size = bodyMarkdown.size(atMaxWidth: body.frame.width)
            bodyScrollView.heightAnchor.constraint(equalToConstant: size.height).isActive = true
            
            /// TESTING: Set contentView width
//            window.contentView?.setFrameSize(NSSize(width: 1000, height: 600))
            
            /// Create effectView
            ///     HACK: Using contentView.frame instead of window.frame here. Not sure why works.
            
            let windowFrame = window.contentView!.frame
            let effect = NSVisualEffectView(frame: windowFrame)
            effect.blendingMode = .behindWindow
            effect.state = .active
            effect.material = .popover /**.underWindowBackground*/
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
