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
    /// Init & lifecycle
    ///
    
//    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
//
//
//    }
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
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        /// Setup tracking area
        trackingArea = NSTrackingArea(rect: self.addField.frame, options: [.mouseEnteredAndExited, .activeAlways, .enabledDuringMouseDrag], owner: self)
        self.addField.superview?.addTrackingArea(trackingArea)
    }
    override func viewDidDisappear() {
        
        /// Tear down tracking area
        self.addField.superview?.removeTrackingArea(trackingArea)
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
        /// [AddViewController enableAddFieldHoverEffect:YES];
        SharedMessagePort.sendMessage("enabledAddMode", withPayload: nil, expectingReply: false)
    }
    override func mouseExited(with event: NSEvent) {
        pointerIsInsideAddField = false
        /// [AddViewController enableAddFieldHoverEffect:NO];
        SharedMessagePort .sendMessage("disableAddMode", withPayload: nil, expectingReply: false)
    }
    
    /// Ignore MB1 & MB2
    ///     TODO: Use format strings and shared functions from UIStrings.m to obtain button names

    override func mouseUp(with event: NSEvent) {
        if !pointerIsInsideAddField { return }
        var message = NSAttributedString(string: "Primary Mouse Button can't be used. \nPlease try another button.")
        message = message.addingBold(forSubstring: "Primary Mouse Button")
        ToastNotificationController.attachNotification(withMessage: message, to: MainAppState.shared.window!, forDuration: -1)
    }
    override func mouseDown(with event: NSEvent) {
        if !pointerIsInsideAddField { return }
        var message = NSAttributedString(string: "Secondary Mouse Button can't be used. \nPlease try another button.")
        message = message.addingBold(forSubstring: "Secondary Mouse Button")
        ToastNotificationController.attachNotification(withMessage: message, to: MainAppState.shared.window!, forDuration: -1)
    }
    
    /// Conclude addMode

    @objc func handleReceivedAddModeFeedbackFromHelper(payload: NSDictionary) {
        
        DDLogDebug("Received AddMode feedback with payload: \(payload)")
        
        /// tint plus icond to give visual feedback
        var plusIconViewCopy: NSImageView? = nil
        if #available(macOS 10.14, *) {
            plusIconViewCopy = SharedUtility.deepCopy(of: plusIconView!) as! NSImageView?
            plusIconView.superview?.addSubview(plusIconViewCopy!)
            plusIconViewCopy?.alphaValue = 0.0
            plusIconViewCopy?.contentTintColor = .controlAccentColor
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                plusIconViewCopy?.animator().alphaValue = 0.6
                Thread.sleep(forTimeInterval: ctx.duration)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.wrapUpAddModeFeedbackHandling(payload: payload, plusIconViewCopy:plusIconViewCopy)
            }
        } else {
            self.wrapUpAddModeFeedbackHandling(payload: payload, plusIconViewCopy:plusIconViewCopy)
        }
    }
    
    @objc func wrapUpAddModeFeedbackHandling(payload: NSDictionary, plusIconViewCopy: NSImageView?) {
        
        /// Send payoad to tableController
        ///     The payload is an almost finished remapsTable (aka RemapTableController.dataModel) entry with the kMFRemapsKeyEffect key missing
        tableController.addRow(withHelperPayload: payload as! [AnyHashable : Any])
        
        /// Reset plus image tint
        if #available(macOS 10.14, *) {
            plusIconViewCopy?.alphaValue = 0.0
            plusIconViewCopy?.removeFromSuperview()
            plusIconView.alphaValue = 1.0
        }
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
    
//    - (void)enableAddFieldHoverEffect:(BOOL)enable {
//        /// None of this works
//        NSBox *af = _instance.addField;
//        NSView *afSub = _instance.addField.subviews[0];
//        if (enable) {
//            afSub.wantsLayer = YES;
//            af.wantsLayer = YES;
//            af.layer.masksToBounds = NO;
//
//            // Shadow (doesn't work withough setting background color)
//    //        NSShadow *shadow = [[NSShadow alloc] init];
//    //        shadow.shadowColor = NSColor.blackColor;
//    //        shadow.shadowOffset = NSZeroSize;
//    //        shadow.shadowBlurRadius = 10;
//    //        afSub.shadow = shadow;
//
//            /// Focus ring
//            afSub.focusRingType = NSFocusRingTypeDefault;
//            [afSub becomeFirstResponder];
//            af.focusRingType = NSFocusRingTypeDefault;
//            [af becomeFirstResponder];
//        } else {
//            /// Shadow
//            afSub.shadow = nil;
//            afSub.layer.shadowOpacity = 0.0;
//            afSub.layer.backgroundColor = nil;
//            /// Focus ring
//            [afSub resignFirstResponder];
//
//        }
//    }
    
}
