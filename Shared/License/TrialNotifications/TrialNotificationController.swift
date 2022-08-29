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
import CocoaLumberjackSwift

class TrialNotificationController: NSWindowController {

    
    /// Singleton
    @objc static let shared = TrialNotificationController(window: nil)
    
    /// Outlets & actions
    
    @IBOutlet var body: NSTextView!
    @IBOutlet weak var bodyScrollView: NSScrollView!
    
    @IBOutlet weak var applePayBadge: NSImageView!
    @IBOutlet weak var payButton: PayButton!
    
    @IBOutlet weak var trialSection: TrialSection!
    
    @IBAction func closeButtonClick(_ sender: Any) {
        self.close()
    }
    
    /// Vars
    var trackingArea: NSTrackingArea? = nil
    var darkModeObservation: Any? = nil
    var trialSectionManager: TrialSectionManager! = nil
    
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
            
            self.window?.collectionBehavior = .canJoinAllSpaces
            
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
            
            /// Enable antialiasing on the ApplePayBadge
            applePayBadge.enableAntiAliasing()
            
            /// Setup tracking area
            
            trackingArea = NSTrackingArea(rect: window.contentView!.frame, options: [.activeAlways, .mouseEnteredAndExited], owner: self)
            window.contentView!.addTrackingArea(trackingArea!)
            
            /// Init the payButton
            /// May be more elegant to do this from IB directly but whatever
            payButton.realInit(title: licenseConfig.formattedPrice) {
                NSWorkspace.shared.open(URL(string: licenseConfig.quickPayLink)!)
            }
            
            /// Init the trialSection
            trialSectionManager = TrialSectionManager(self.trialSection)
            trialSectionManager.startManaging(licenseConfig: licenseConfig, license: license)
            
            /// Set the bodyString
            
            let bodyBase = NSLocalizedString("trial-notif.body", comment: "First draft: Hi! You've been using Mac Mouse Fix for **%d days** now. I hope you're enjoying it!\n\nIf you want to keep using Mac Mouse Fix, you can [buy it now](%@).")
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
            
            /// Set effectView border
            ///     This is trying to emulate the border that NSWindows have in darkmode under Ventura. Little hacky and ugly because we're hardcoding the color. Nicer solution might be to somehow change the borderRadius on the NSWindow and then use the NSWindow background directly, instead of making the window background invisible and using the effectView as a background.
            
            if #available(macOS 10.14, *) {
                
                let updateBorder = {
                    
                    let isDarkMode = NSApp.effectiveAppearance.name == .darkAqua
                    if isDarkMode {
                        effect.layer!.borderWidth = 1.0
                        effect.layer!.borderColor = NSColor(deviceRed: 140/255, green: 140/255, blue: 140/255, alpha: 0.5).cgColor
                    } else {
                        effect.layer!.borderColor = .clear
                    }
                    
                }
                
                updateBorder()
                
                darkModeObservation = NSApp.observe(\.effectiveAppearance) { app, change in
                    updateBorder()
                }
            }

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
        
        /// Animate in
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
    
    /// Swap trialSection -> activate license on hover

    
    override func mouseEntered(with event: NSEvent) {
        
        DispatchQueue.main.async {
            self.trialSectionManager.showActivate()
        }
    }

    override func mouseExited(with event: NSEvent) {
            
        DispatchQueue.main.async {
            self.trialSectionManager.showTrial()
        }
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
            DispatchQueue.main.sync {
                window.setValue(f, forKey: "frame")
            }
        }, onComplete: {
            onComplete?()
        })
    }
}
