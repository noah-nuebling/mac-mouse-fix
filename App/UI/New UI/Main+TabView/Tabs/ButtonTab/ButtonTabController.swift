//
// --------------------------------------------------------------------------
// ButtonTabController.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Foundation
import CocoaLumberjackSwift

@objc class ButtonTabController: NSViewController {
    
    ///
    /// Outlets
    ///
    
    /// AddField
    
    @IBOutlet weak var addField: NSBox!
    @IBOutlet weak var plusIconView: NSImageView!
    
    /// TableView
    
    @IBOutlet var tableController: RemapTableController!
    
    @IBOutlet weak var scrollView: MFScrollView!
    @IBOutlet weak var clipView: NSClipView!
    @IBOutlet weak var tableView: RemapTableView!
    
    /// Buttons
    
    @IBOutlet weak var optionsButton: NSButton!
    @IBOutlet weak var restoreDefaultButton: NSButton!
    
    ///
    /// IBActions
    ///
    
    @IBAction func openOptions(_ sender: Any) {
        ButtonOptionsViewController.add()
    }
    
    
    ///
    /// Init & lifecycle
    ///
    
    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        
        /// This init is never being called
        assert(false)
        
        /// Set garbage values
        pointerIsInsideAddField = false
        trackingArea = NSTrackingArea()
        
        /// Init super
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        
        /// Do actual init
        initAddFieldStuff()
    }
    required init?(coder: NSCoder) {
        
        /// Set garbage values
        pointerIsInsideAddField = false
        trackingArea = NSTrackingArea()
        
        /// Init super
        super.init(coder: coder)
        
        /// Real init
        initAddFieldStuff()
    }
    
//    override func viewDidLoad() {
//        super.viewDidLoad()
//
//        /// Init addField
//        initAddFieldStuff()
//
//    }
    
    var appearanceObservation: NSKeyValueObservation? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()

        /// Add trackingArea
        ///     Do we ever need to remove it?
        trackingArea = NSTrackingArea(rect: self.addField.bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow], owner: self)
        
        self.addField.addTrackingArea(trackingArea)
        
        /// Fix hover animations
        ///     Need to set some shadow before (and not directly, synchronously before) the hover animation first plays. No idea why this works
        addField.shadow = .clearShadow
        plusIconView.shadow = .clearShadow
        
        /// Make colors non-transparent
        updateColors()
        
        /// Observe darkmode changes to update colors (we do the same thing in RemapTable)
        if #available(macOS 10.14, *) {
            appearanceObservation = NSApp.observe(\.effectiveAppearance) { nsApp, change in
                self.updateColors()
            }
        }
    }
    
    func updateColors() {
        addField.wantsLayer = true
        
        /// We use non-transparent colors so the shadows don't bleed through
        
        /// Check darkmode
        
        var isDarkMode: Bool = false
        if #available(macOS 10.14, *) {
            isDarkMode = (NSApp.effectiveAppearance == .init(named: .darkAqua)!)
        }
        
        /// Update fillColor
        ///     This is reallly just quarternaryLabelColor but without transparency.
        ///     I couldn't find a nicer way to remove transparency except hardcoding it. Our solidColor methods from NSColor+Additions.m didn't work properly. I suspect it's because the NSColor objects can represent different colors depending on which context they are drawn in.
        ///     Possible nicer solution: I think the only dynamic way to remove transparency that will be reliable is to somehow render the view in the background and then take a screenhot
        ///     Other possible solution: We really want to do this so we don't see the NSShadow behind the view. Maybe we could clip the drawing of the shadow, then we wouldn't have to remove transparency at all.
        
        if isDarkMode {
            addField.fillColor = NSColor(red: 57/255, green: 57/255, blue: 57/255, alpha: 1.0)
        } else {
            addField.fillColor = NSColor(red: 227/255, green: 227/255, blue: 227/255, alpha: 1.0)
        }
        
        /// Update borderColor
        ///     This is really just .separatorColor without transparency
        
        if isDarkMode {
            addField.borderColor = NSColor(red: 77/255, green: 77/255, blue: 77/255, alpha: 1.0)
        } else {
            addField.borderColor = NSColor(red: 198/255, green: 198/255, blue: 198/255, alpha: 1.0)
        }
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        /// This is called twice, awakeFromNib as well. Use init() or viewDidLoad() to do things once
        
        ///
        /// Turn off killswitch
        ///
        
        /// We do the exact same thing in the scrollTab
        
        let isDisabled = config("Other.buttonKillSwitch") as! Bool
        
        if isDisabled {
            
            /// Turn off killSwitch
            setConfig("Other.buttonKillSwitch", false as NSObject)
            commitConfig()
            
            /// Show message to user
            if #available(macOS 13, *) {
                
                /// Build string
                var messageRaw = NSLocalizedString("button-revive-toast", comment: "First draft: __Enabled__ Mac Mouse Fix for __Buttons__.\nIt had been disabled from the Menu Bar %@ || %@ will be replaced by the menubar icon")
                var message = NSAttributedString(coolMarkdown: messageRaw)!
                let symbolString = NSAttributedString(symbol: "CoolMenuBarIcon", hPadding: 0.0, vOffset: -6, fallback: "<Mac Mouse Fix Menu Bar Item>")
                message = NSAttributedString(attributedFormat: message, args: [symbolString])
                
                /// Show message
                ToastNotificationController.attachNotification(withMessage: message, to: MainAppState.shared.window!, forDuration: -1, alignment: kToastNotificationAlignmentTopMiddle)
                
            } else {
                /// TODO: Make this work on older macOS
            }
        }
    }
    
    ///
    /// AddView stuff
    ///
    
    /// Vars
    
    var pointerIsInsideAddField: Bool
    var trackingArea: NSTrackingArea
    
    /// Init
    func initAddFieldStuff() {
        
        /// Init state
        pointerIsInsideAddField = false
        
        /// Validate: Init is not called twice
        assert(MainAppState.shared.buttonTabController == nil)
        
        /// Store self into global state
        MainAppState.shared.buttonTabController = self
    }
    
    /// AddField callbacks
    ///     TODO: Maybe think about race condition for the mouseEntered and mouseExited functions

    override func mouseEntered(with event: NSEvent) {
        pointerIsInsideAddField = true
        addFieldHoverEffect(enable: true)
        SharedMessagePort.sendMessage("enableAddMode", withPayload: nil, expectingReply: false)
    }
    override func mouseExited(with event: NSEvent) {
        pointerIsInsideAddField = false
        addFieldHoverEffect(enable: false)
        SharedMessagePort .sendMessage("disableAddMode", withPayload: nil, expectingReply: false)
    }
    
    /// Ignore MB1 & MB2
    ///     TODO: Use format strings and shared functions from UIStrings.m to obtain button names

    override func mouseUp(with event: NSEvent) {
        if !pointerIsInsideAddField { return }
        
        var messageRaw = NSLocalizedString("forbidden-capture-toast.1", comment: "First draft: **Primary Mouse Button** can't be used.\nPlease try another button")
        let message = NSAttributedString(coolMarkdown: messageRaw)!;
        
        ToastNotificationController.attachNotification(withMessage: message, to: MainAppState.shared.window!, forDuration: -1)
    }
    override func rightMouseUp(with event: NSEvent) {
        if !pointerIsInsideAddField { return }
        
        var messageRaw = NSLocalizedString("forbidden-capture-toast.2", comment: "First draft: **Secondary Mouse Button** can't be used.\nPlease try another button")
        let message = NSAttributedString(coolMarkdown: messageRaw)!;
        
        ToastNotificationController.attachNotification(withMessage: message, to: MainAppState.shared.window!, forDuration: -1)
    }
    
    /// Conclude addMode

    @objc func handleReceivedAddModeFeedbackFromHelper(payload: NSDictionary) {
        
        DDLogDebug("Received AddMode feedback with payload: \(payload)")
        
        self.wrapUpAddModeFeedbackHandling(payload: payload)
    }
    
    @objc func wrapUpAddModeFeedbackHandling(payload: NSDictionary) {
        
        /// Remove hover
        addFieldHoverEffect(enable: false, playAcceptAnimation: true)
        
        /// Send payoad to tableController
        ///     The payload is an almost finished remapsTable (aka RemapTableController.dataModel) entry with the kMFRemapsKeyEffect key missing
        tableController.addRow(withHelperPayload: payload as! [AnyHashable : Any])
        
    }
    

    ///
    /// Old MMF 2 methods for reference (had to translate some of these to swift)
    ///
    
//    - (void)handleReceivedAddModeFeedbackFromHelperWithPayload:(NSDictionary *)payload {
//
//        DDLogDebug(@"Received AddMode feedback with payload: %@", payload);
//
//        /// Tint plus icon to give visual feedback
//        NSImageView *plusIconViewCopy;
//        if (@available(macOS 10.14, *)) {
//            plusIconViewCopy = (NSImageView *)[SharedUtility deepCopyOf:_instance.plusIconView];
//            [_instance.plusIconView.superview addSubview:plusIconViewCopy];
//            plusIconViewCopy.alphaValue = 0.0;
//            plusIconViewCopy.contentTintColor = NSColor.controlAccentColor;
//            [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
//                NSAnimationContext.currentContext.duration = 0.2;
//                plusIconViewCopy.animator.alphaValue = 0.6;
//    //            _instance.plusIconView.animator.alphaValue = 0.0;
//                [NSThread sleepForTimeInterval:NSAnimationContext.currentContext.duration];
//            }];
//            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
//                [self wrapUpAddModeFeedbackHandlingWithPayload:payload andPlusIconViewCopy:plusIconViewCopy];
//            });
//        } else {
//            [self wrapUpAddModeFeedbackHandlingWithPayload:payload andPlusIconViewCopy:plusIconViewCopy];
//        }
//    }
        
//    - (void)wrapUpAddModeFeedbackHandlingWithPayload:(NSDictionary * _Nonnull)payload andPlusIconViewCopy:(NSImageView *)plusIconViewCopy {
//        /// Dismiss sheet
//        [self end];
//        /// Send payload to RemapTableController
//        ///      The payload is an almost finished remapsTable (aka RemapTableController.dataModel) entry with the kMFRemapsKeyEffect key missing
//        [((RemapTableController *)AppDelegate.instance.remapsTable.delegate) addRowWithHelperPayload:(NSDictionary *)payload];
//        /// Reset plus image tint
//        if (@available(macOS 10.14, *)) {
//            plusIconViewCopy.alphaValue = 0.0;
//            [plusIconViewCopy removeFromSuperview];
//            _instance.plusIconView.alphaValue = 1.0;
//        }
//    }
//
    
    /// Visual FX
    
    func addFieldHoverEffect(enable: Bool, playAcceptAnimation: Bool = false) {
        /// Ideas: Draw focus ring or shadow, or zoom
        
        /// Debug
        
        DDLogDebug("FIELD HOOVER: \(enable)")
        
        /// Init
        addField.wantsLayer = true
        addField.layer?.transform = CATransform3DIdentity
        addField.coolSetAnchorPoint(anchorPoint: .init(x: 0.5, y: 0.5))
        
        if !enable {
            
            
            /// Animation curve
            var animation = CASpringAnimation(speed: 2.25, damping: 1.0)
            
            if playAcceptAnimation {
                animation = CASpringAnimation(speed: 3.75, damping: 0.25, initialVelocity: -10)
            }
            
            
            /// Play animation
            
            Animate.with(animation) {
                addField.reactiveAnimator().layer.transform.set(CATransform3DIdentity)
                addField.reactiveAnimator().shadow.set(NSShadow.clearShadow)
            }
            
            /// Play tint animation
            
            if #available(macOS 10.14, *) {
                if playAcceptAnimation {
                    Animate.with(CASpringAnimation(speed: 3.5, damping: 1.0)) {
                        plusIconView.reactiveAnimator().contentTintColor.set(NSColor.controlAccentColor)
                    } onComplete: {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: { /// This 'timer' is not terminated when unhover is triggered some other way, leading to slightly weird behaviour
                            Animate.with(CASpringAnimation(speed: 3.5, damping: 1.3)) {
                                self.plusIconView.reactiveAnimator().contentTintColor.set(NSColor.gray)
                            }
                        })
                    }
                } else { /// Normal un-hovering
                    Animate.with(CASpringAnimation(speed: 3.5, damping: 1.3)) {
                        self.plusIconView.reactiveAnimator().contentTintColor.set(NSColor.gray)
                    }
                }
            }
            
            
        } else {
            
            /// Setup addField shadow
            
            var isDarkMode: Bool = false
            if #available(macOS 10.14, *) {
                isDarkMode = (NSApp.effectiveAppearance == .init(named: .darkAqua)!)
            }
            
            let s = NSShadow()
            s.shadowColor = .shadowColor.withAlphaComponent(isDarkMode ? 0.75 : 0.225)
            s.shadowOffset = .init(width: 0, height: -2)
            s.shadowBlurRadius = 1.5
            
            addField.wantsLayer = true
            addField.layer?.masksToBounds = false
            addField.superview?.wantsLayer = true
            addField.superview?.layer?.masksToBounds = false
            
            /// Setup plusIcon shadow
            
            let t = NSShadow()
            t.shadowColor = .shadowColor.withAlphaComponent(0.5)
            t.shadowOffset = .init(width: 0, height: -1)
            t.shadowBlurRadius = /*3*/10
            
            plusIconView.wantsLayer = true
            plusIconView.layer?.masksToBounds = false
            plusIconView.superview?.wantsLayer = true
            plusIconView.superview?.layer?.masksToBounds = false
            
            /// Animate
            
            Animate.with(CASpringAnimation(speed: 3.75, damping: 1.0)) {
                addField.reactiveAnimator().layer.transform.set(CATransform3DTranslate(CATransform3DMakeScale(1.005, 1.005, 1.0), 0.0, 1.0, 0.0))
                addField.reactiveAnimator().shadow.set(s)
            }
            
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: {
//                Animate.with(CABasicAnimation(name: .default, duration: 0.25)) {
//                    self.plusIconView.reactiveAnimator().shadow.set(t)
//                }
//            })
        }
        
    }
    
}
