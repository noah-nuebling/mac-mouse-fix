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
            
            /// Set the trialString
            trialSection.textField?.attributedStringValue = LicenseUtility.trialCounterString(licenseConfig: licenseConfig, license: license)
            
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
    ///     This code is a little convoluted. mouseEntered and mouseExited are almost copy-pasted, except for setting up in newSection in mouseEntered.
    
    var isReplacing = false
    var isInside = false
    var queuedReplace: (() -> ())? = nil
    var ogSection: TrialSection? = nil
    
    override func mouseEntered(with event: NSEvent) {
        
        DispatchQueue.main.async {
            
            let workload = {
                
                do {
                    
                    DDLogDebug("triall enter")
                    
                    if self.isInside {
                        if let r = self.queuedReplace {
                            self.queuedReplace = nil
                            r()
                        } else {
                            self.isReplacing = false
                        }
                        return
                    }
                    self.isInside = true
                    
                    self.isReplacing = true
                    
                    let ogSection = self.trialSection!
                    let newSection = try SharedUtilitySwift.insecureCopy(of: self.trialSection)
                    
                    ///
                    /// Store original trialSection for easy restoration on mouseExit
                    ///
                    
                    if self.ogSection == nil {
                        self.ogSection = try SharedUtilitySwift.insecureCopy(of: self.trialSection!)
                    }
                    
                    ///
                    /// Setup newSection
                    ///
                    
                    /// Setup Image
                    
                    /// Create image
                    let image: NSImage
                    if #available(macOS 11.0, *) {
                        image = NSImage(systemSymbolName: "lock.open", accessibilityDescription: nil)!
                    } else {
                        image = NSImage(named: "lock.open")!
                    }
                    
                    /// Configure image
                    if #available(macOS 11, *) { newSection.imageView?.symbolConfiguration = .init(pointSize: 13, weight: .medium, scale: .large) }
                    if #available(macOS 10.14, *) { newSection.imageView?.contentTintColor = .linkColor }
                    
                    /// Set image
                    newSection.imageView?.image = image
                    
                    /// Setup hyperlink
                    
                    let linkTitle = NSLocalizedString("trial-notif.activate-license-button", comment: "First draft: Activate License")
                    let linkAddress = "https://google.com"
                    let link = Hyperlink(title: linkTitle, url: linkAddress, alwaysTracking: true, leftPadding: 30)
                    link?.font = NSFont.systemFont(ofSize: 13, weight: .regular)
                    
                    link?.translatesAutoresizingMaskIntoConstraints = false
                    link?.heightAnchor.constraint(equalToConstant: link!.fittingSize.height).isActive = true
                    link?.widthAnchor.constraint(equalToConstant: link!.fittingSize.width).isActive = true
                    
                    newSection.textField = link
                    
                    ///
                    /// Done setting up newSection
                    ///
                    
                    ReplaceAnimations.animate(ogView: ogSection, replaceView: newSection, hAnchor: .center, vAnchor: .center, doAnimate: true) {
                        
                        DDLogDebug("triall enter finish")
                        
                        self.trialSection = newSection
                        
                        if let r = self.queuedReplace {
                            self.queuedReplace = nil
                            r()
                        } else {
                            self.isReplacing = false
                        }
                    }
                } catch {
                    DDLogError("Failed to swap out trialSection on notification with error: \(error)")
                    assert(false)
                }
            }
            
            if self.isReplacing {
                DDLogDebug("triall queue enter")
                self.queuedReplace = workload
            } else {
                workload()
            }
        }
    }

    override func mouseExited(with event: NSEvent) {
        
        DispatchQueue.main.async {
            
            let workload = {
                    
                DDLogDebug("triall exit")
                
                if !self.isInside {
                    if let r = self.queuedReplace {
                        self.queuedReplace = nil
                        r()
                    } else {
                        self.isReplacing = false
                    }
                    return
                }
                self.isInside = false
                
                self.isReplacing = true
                
                let ogSection = self.trialSection!
                let newSection = self.ogSection!
                
                ReplaceAnimations.animate(ogView: ogSection, replaceView: newSection, hAnchor: .center, vAnchor: .center, doAnimate: true) {
                    
                    DDLogDebug("triall exit finish")
                    
                    self.trialSection = newSection
                    
                    if let r = self.queuedReplace {
                        self.queuedReplace = nil
                        r()
                    } else {
                        self.isReplacing = false
                    }
                }
            }
            
            if self.isReplacing {
                DDLogDebug("triall queue exit")
                self.queuedReplace = workload
            } else {
                workload()
            }
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
