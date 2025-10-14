//
// --------------------------------------------------------------------------
// TrialNotificationController.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
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
        
        /// Close notification
        self.close()
        
        /// Wait for close animation to finish
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                
            /// Disable helper
            HelperServices.disableHelperFromHelper()
        })
    }
    
    /// Vars
    var trackingArea: NSTrackingArea? = nil
    var darkModeObservation: NSKeyValueObservation? = nil
    var trialSectionManager: TrialSectionManager! = nil
    var spaceSwitchObservation: Any? = nil
    
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
        
        /// Make views compact on Tahoe
        if #available(macOS 26.0, *) {
            self.window?.contentView?.prefersCompactControlSizeMetrics = true;
        }
    }
    
    deinit {
        if let obs = self.spaceSwitchObservation {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
    }
    
    /// Interface
    
    var firstAppearance = true
    
    @objc func open(licenseConfig: MFLicenseConfig, licenseState: MFLicenseState, trialState: MFTrialState, triggeredByUser: Bool) {
        
        /// Validate
        
        assert(Thread.isMainThread)
        
        /// Unwrap window
        
        guard let window = self.window else { return }
        
        /// Make appearance notification-ish
        ///     Src: https://developer.apple.com/forums/thread/125232?answerId=392168022#392168022
        ///     Note: Should probably do this in some init func like viewDidLoad.

        if firstAppearance {
            
            /// Enable antialiasing on the ApplePayBadge
            applePayBadge.enableAntiAliasing()
            
            /// Update layout
            ///     So the tracking areas are correct
            
            trialSection.needsLayout = true
            trialSection.superview!.needsLayout = true
            trialSection.superview!.layoutSubtreeIfNeeded()
            
            /// Setup tracking area
            ///     Explanation for the width and height calculations:
            ///     - The tracking area matches the bottom slice of the notification, below the horizontal line. 20 px is the vertical padding around the trialSection.
            ///     - Why choose the entire vertical slice? This feels similar to the TrialSection tracking area on the About Tab. Also, when the user hovers the "$2.99" button at the right side of the bottom slice, they will trigger the hover effect and discover the convenient "Activate License" link.
            ///
            ///     Update: I don't like it! So we're disabling the switching on hover now.
            ///         This means we're not really using the main functionality of the trialSectionManager anywhere right now. It still works fine but maybe refactor?
            ///     Update 2: [Jul 2025] I've wished for the "Activate License" button on the TrialNotification a few times recently. While it may feel a bit weird to use in its current form, it's just too useful -> Enabling this now.
            
            let trackingRect = NSRect(x: 0, y: 0, width: window.frame.width, height: 20 + trialSection.frame.height + 20)
            trackingArea = NSTrackingArea(rect: trackingRect, options: [.activeAlways, .mouseEnteredAndExited], owner: self)
            trialSection.superview!.addTrackingArea(trackingArea!)
            
            /// Init the payButton
            /// May be more elegant to do this from IB directly but whatever
            ///     Use the quickPayLink for ASAP checkout if the users' flow has been interrupted
            payButton.realInit(title: MFLicenseConfigFormattedPrice(licenseConfig)) {
                LicenseUtility.buyMMF(licenseConfig: licenseConfig, locale: Locale.current, useQuickLink: !triggeredByUser)
            }
            
            /// Init the trialSection
            trialSectionManager = TrialSectionManager(self.trialSection)
            trialSectionManager.startManaging(licenseConfig: licenseConfig, trialState: trialState)
            
            /// Set the bodyString
            
            let bodyBase = NSLocalizedString("trial-notif.body", comment: "First draft: Hi there! You've been using Mac Mouse Fix for **%d days** now. I hope you're enjoying it!\n\nIf you want to keep using Mac Mouse Fix, you can [buy it now](%@).")
            let bodyFormatted = String(format: bodyBase, trialState.daysOfUseUI, licenseConfig.quickPayLink)
            let bodyMarkdown = NSAttributedString(coolMarkdown: bodyFormatted)!
            body.textStorage?.setAttributedString(bodyMarkdown)
            
            /// Layout contentView
            ///     So the width is up to date for the scrollView height calculation
            window.contentView?.needsLayout = true
            window.contentView?.layoutSubtreeIfNeeded()
            
            /// Set scrollView height
            /// Notes:
            /// - Can't do this with autolayout ugh. Also can't use NSTextField, which would support autolayout, because it doesn't support links.
            /// - With body.frame.width we use the width from IB
            /// - By setting priority to 999 we give priority to the min height from IB. That's so the MMF Icon which is centered to the textField doesn't get too close to the the dismiss button.
            let size = body.frame.size /*bodyMarkdown.size(atMaxWidth: body.frame.width)*/ /// Update: [Jul 2025] `NSAttributedString sizeAtMaxWidth:` was too short in Chinese. But simply using the NSTextView's height (`body.frame.size.height`) works! I think we shouldn't have a scrollView around the textView here. We never want anything to be cut off.
            let bodyHeight = bodyScrollView.heightAnchor.constraint(equalToConstant: size.height)
            bodyHeight.priority = .init(999) /// Give the min height from IB priority
            bodyHeight.isActive = true
            
            /// TESTING: Set contentView width
//            window.contentView?.setFrameSize(NSSize(width: 1000, height: 600))
            
            /// Create effectView
            ///     HACK: Using contentView.frame instead of window.frame here. Not sure why works.
            ///     Material .popover matches real notifications and looks great, but in darkmode it makes our links unreadable over a bright background. Calendar.app also uses the .popover material and it displays links. It fixes this issue by using a much brighter link color. But we're just using a darker, less translucent material (.underWindowBackground) as and easy fix.
            
            let windowFrame = window.contentView!.frame
            let effect = NSVisualEffectView(frame: windowFrame)
            effect.blendingMode = .behindWindow
            if #available(macOS 10.14, *) {
                effect.material = .underWindowBackground
            } else {
                effect.material = .popover /**.underWindowBackground*/
            }
            effect.wantsLayer = true
            effect.state = .active
            
            /// HACK:
            ///     Observe space switches, and then do some random update on the effectView.
            ///     When the space begins to switch, the effectView loses its translucency. This doesn't happen for Calendar.app popovers, so there must be a way to turn this off. Edit: Actually the Calendar.app popovers don't follow you to the current space and this problem only started occuring when we made the window follow you to the current space. So it's not quite comparable.
            ///     Our hack solution is to observe space switches and then do some random update on the effectView because that seems to enable the translucency again.
            ///     This is not quite perfect because __during__ the space switch, the translucency will still be disabled. But it's barely noticably.
            self.spaceSwitchObservation = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: OperationQueue.main) { notification in
                
                DDLogError("Space did change")
                effect.state = .inactive
                effect.state = .active
            }
            
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
                
                darkModeObservation = NSApp.observe(\.effectiveAppearance, changeHandler: { app, change in
                    updateBorder()
                })
            }

            /// Set corner radius
            /// Notes:
            /// - 16 matches system notifications on Ventura
            /// - 20 matches widgets on Ventura
            
            effect.layer?.cornerRadius = 20.0
            
            /// Mojave hack
            ///  Under Mojave there's a white border at the top of the window. It looks reallly weird since it doesn't align with our rounded corners. This is a well known Apple Bug. See this electron GitHub Issue: https://github.com/electron/electron/issues/13164.
            ///  - Possible solutions:
            ///     - Just live with it
            ///     - Just turn off the custom corner rounding for 10.14 `<-` We went with this
            ///     - Remove .titled from the style.
            ///         - Seems to remove the white border but it also removes the rounded corners entirely for some reason.
            
            
            /// Swap out contentView -> effectView
            ///     Under macOS 12 (originally wrote this under macOS 13 Beta) the effectView's subviews just disappear as soon as we set it as contentView? Setting window.contentView = nil in between fixes it. Not sure why.
            
            
            var runningMojave = false
            if #available(macOS 10.14, *) {
                if #available(macOS 10.15, *) { } else {
                    runningMojave = true
                }
            }
            
            if !runningMojave { /// Only use the effectView when not running Mojave
                let ogContent = self.window!.contentView!
                window.contentView = nil
                effect.addSubview(ogContent)
                window.contentView = effect
                window.backgroundColor = .clear
            }
            
            /// Style window
            ///     The styleMask added here (borderless, titled, fullSizeContentView) is the same that is defined through IB. But it's kind of nice to have it here explicitly I guess?
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isOpaque = false
            window.styleMask = [.borderless, .titled, .fullSizeContentView]
            
            
            /// vvv Old code pre Mojave hack - remove this
            
            
            //            /// Swap out contentView -> effectView
            //            ///     Under macOS 12 (originally wrote this under macOS 13 Beta) the effectView's subviews just disappear as soon as we set it as contentView? Setting window.contentView = nil in between fixes it. Not sure why.
            //            let ogContent = self.window!.contentView!
            //            window.contentView = nil
            //            effect.addSubview(ogContent)
            //            window.contentView = effect
//
//            /// Style window
//            window.titlebarAppearsTransparent = true
//            window.titleVisibility = .hidden
//            window.isOpaque = false
//            window.backgroundColor = .clear
            
            
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
        let animStartFrame = NSRect(x: visibleFrame.maxX, /// [Sep 2025, Tahoe RC] The window will always appear *on screen* (little bit farther left than what we specify) But I think setFrameWithCoolAnimation() then moves it to the correct starting position. Either way it's not usually noticable. Except if setFrameWithCoolAnimation() fails. 
                                    y: newFrame.origin.y,
                                    width: newFrame.width,
                                    height: newFrame.height)
        
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
            DispatchQueue.main.async {
                super.close()
            }
        })
    }
    
    /// Swap trialSection -> activate license on hover

    
    override func mouseEntered(with event: NSEvent) {
        
        DispatchQueue.main.async {
            self.trialSectionManager.showAlternate(animate: true, hAnchor: .leading)
        }
    }

    override func mouseExited(with event: NSEvent) {
            
        DispatchQueue.main.async {
            self.trialSectionManager.showInitial(animate: true, hAnchor: .leading)
        }
    }
    
    /// Helper stuff
    var animator: DynamicSystemAnimator? = nil
    fileprivate func setFrameWithCoolAnimation(_ animStartFrame: NSRect, _ newFrame: NSRect, _ window: NSWindow, onComplete: (() -> ())? = nil) {
        
        /// Animate window in
        ///     Note: We're doing the same thing in ResizingTabWindow. -> Think about abstracting this away
        
        let animation = CASpringAnimation(speed: 3.5, damping: 1.0)
        animator = DynamicSystemAnimator(fromAnimation: animation, stopTolerance: 0.1, optimizedWorkType: kMFDisplayLinkWorkTypeGraphicsRendering)
        animator!.start(distance: 1.0, callback: { value in
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
