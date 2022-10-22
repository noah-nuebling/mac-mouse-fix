//
// --------------------------------------------------------------------------
// ButtonTabController.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

import Foundation
import CocoaLumberjackSwift

@objc class ButtonTabController: NSViewController, NSPopoverDelegate {
    
    //
    // MARK: - Outlets
    //
    
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
    
    //
    // - MARK: IBActions
    //
    
    @IBAction func openOptions(_ sender: Any) {
        ButtonOptionsViewController.add()
    }
    
    @IBAction func restoreDefaults(_ sender: Any) {
        
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = NSLocalizedString("restore-buttons-alert.title", comment: "First draft: Restore Default for ...")
        alert.informativeText = ""
        
        alert.addButton(withTitle: NSLocalizedString("restore-buttons-alert.commit", comment: "First draft: Restore"))
        alert.addButton(withTitle: NSLocalizedString("restore-buttons-alert.back", comment: "First draft: Cancel"))
        
        ///
        /// Get device info
        ///
        
        let (name, nOfButtons, bestPresetMatch) =  MessagePortUtility_App.getActiveDeviceInfo() ?? (nil, nil, nil)
        
        ///
        /// Add accessoryView
        ///
        
        let radio1 = NSButton(radioButtonWithTitle: NSLocalizedString("restore-buttons-alert.radio1", comment: "First draft: Mouse with 3 buttons"), target: self, action: #selector(nullAction(sender:)))
        let radio2 = NSButton(radioButtonWithTitle: NSLocalizedString("restore-buttons-alert.radio2", comment: "First draft: Mouse with 5+ buttons"), target: self, action: #selector(nullAction(sender:)))
        
        let radioStack = NSStackView(views: [radio1, radio2])
        
        var hint: CoolNSTextField? = nil
        if let nOfButtons = nOfButtons {
            
            let hintStringRaw = String(format: NSLocalizedString("restore-buttons-alert.hint", comment: "First draft: Your __%@__ mouse says it has __%d__ buttons"), name!, nOfButtons)
            let hintString = NSAttributedString(coolMarkdown: hintStringRaw)?.settingSecondaryLabelColor(forSubstring: nil).settingFontSize(NSFont.smallSystemFontSize).aligningSubstring(nil, alignment: .center).trimmingWhitespace()
            if let hintString = hintString {
                hint = CoolNSTextField(labelWithAttributedString: hintString)
                if hint != nil {
                    radioStack.addView(hint!, in: .center)
                }
            }
        }
        
        radioStack.orientation = .vertical
        radioStack.translatesAutoresizingMaskIntoConstraints = true
        
        radioStack.setCustomSpacing(5.0, after: radio1) /// Default is 8.0 (Ventura)
        radioStack.setCustomSpacing(17.0, after: radio2)
        
        let width = max(200.0, max(radio1.fittingSize.width, radio2.fittingSize.width))
        var height = radio1.frame.height + radioStack.customSpacing(after: radio1) + radio2.frame.height
        if let hint = hint {
            let hintHeight = hint.attributedStringValue.size(atMaxWidth: width).height
            height += radioStack.customSpacing(after: radio2) + hintHeight + 5 /// Not sure why `+ 5` is necessary
        } else {
            height += 4.0
        }
        
        radioStack.setFrameSize(NSSize(width: width, height: height))
        
        alert.accessoryView = radioStack
        
        ///  Select the radioButton that best matches the activeDevice
        if bestPresetMatch == 3 {
            radio1.state = .on
        } else {
            radio2.state = .on
        }
        
        /// Display alert
        
        guard let window = MainAppState.shared.window else { return }
        
        alert.beginSheetModal(for: window) { response in
            if response == .alertFirstButtonReturn {
                
                /// Get user selection
                
                let selectedPreset = radio1.state == .on ? 3 : 5
                
                /// Check Change
                
                let currentMap = config("Remaps")
                let defaultMap = config(selectedPreset == 3 ? "Other.defaultRemaps.threeButtons" : "Other.defaultRemaps.fiveButtons")
                
                if currentMap != defaultMap {
                    
                    /// Update remaps
                    
                    /// Set config
                    setConfig("Remaps", defaultMap!)
                    commitConfig()
                    
                    /// Reload table
                    DispatchQueue.main.async {
                        self.tableController.reloadAll()
                    }
                } else { /// currentMap == defaultMap
                    
                    /// Display already using notifications
                    
                    let messageRaw: String
                    if selectedPreset == 3 {
                        messageRaw = NSLocalizedString("already-using-defaults-toast.3", comment: "First draft: You're __already using__ the default setting for mice with __3 buttons__!")
                    } else {
                        messageRaw = NSLocalizedString("already-using-defaults-toast.5", comment: "First draft: You're __already using__ the default setting for mice with __5 buttons__!")
                    }
                    let message = NSAttributedString(coolMarkdown: messageRaw)!
                    DispatchQueue.main.async {
                        ToastNotificationController.attachNotification(withMessage: message, to: MainAppState.shared.window!, forDuration: -1.0)
                    }
                    return
                }
            }
        }
    }
    
    @objc func nullAction(sender: AnyObject) {
        /// Need this to make radioButtons to work together (I think)
    }
    
    //
    // - MARK: Init & lifecycle
    //
    
    
    // MARK: Init
    
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
        
        /// Init remaps when the helper becomes (or already is) enabled
        ///     This doesn't really belong here. It just needs to be executed on app start (which it is, being here)
        ///     TODO: Move this. E.g. to   `AppDelegate - applicationDidFinishLaunching`
        ///
        
        EnabledState.shared.producer.startWithValues { enabled in
            if enabled { ButtonTabController.initRemaps() }
        }
        
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
        
        /// This is a helper for `viewDidLoad`
        
        ///
        /// Update addField
        ///
        /// We use non-transparent colors so the shadows don't bleed through
        
        /// Init
        addField.wantsLayer = true
        
        /// Check darkmode
        let isDarkMode = isDarkMode()
        
        /// Get baseColor
        let baseColor: NSColor = isDarkMode ? .black : .white
        
        /// Define baseColor blending fractions
        
        let fillFraction = isDarkMode ? 0.1 : 0.25
        let borderFraction = isDarkMode ? 0.1 : 0.25
        
        /// Update fillColor
        ///     This is reallly just quarternaryLabelColor but without transparency. Edit: We're making it a little lighter actually.
        ///     I couldn't find a nicer way to remove transparency except hardcoding it. Our solidColor methods from NSColor+Additions.m didn't work properly. I suspect it's because the NSColor objects can represent different colors depending on which context they are drawn in.
        ///     Possible nicer solution: I think the only dynamic way to remove transparency that will be reliable is to somehow render the view in the background and then take a screenhot
        ///     Other possible solution: We really want to do this so we don't see the NSShadow behind the view. Maybe we could clip the drawing of the shadow, then we wouldn't have to remove transparency at all.
        
        let quarternayLabelColor: NSColor
        if isDarkMode {
            quarternayLabelColor = NSColor(red: 57/255, green: 57/255, blue: 57/255, alpha: 1.0)
        } else {
            quarternayLabelColor = NSColor(red: 227/255, green: 227/255, blue: 227/255, alpha: 1.0)
        }
        
        addField.fillColor = quarternayLabelColor.blended(withFraction: fillFraction, of: baseColor)!
        
        /// Update borderColor
        ///     This is really just .separatorColor without transparency
        
        let separatorColor: NSColor
        if isDarkMode {
            separatorColor = NSColor(red: 77/255, green: 77/255, blue: 77/255, alpha: 1.0)
        } else {
            separatorColor = NSColor(red: 198/255, green: 198/255, blue: 198/255, alpha: 1.0)
        }
        
        addField.borderColor = separatorColor.blended(withFraction: borderFraction, of: baseColor)!
        
        /// Update plusIcon color
        if #available(macOS 10.14, *) {
            plusIconView.contentTintColor = plusIconViewBaseColor()
        }
    }
    
    // MARK: Did appear
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        /// This is called every time the tab is switched to
        /// This is called twice, awakeFromNib as well. Use init() or viewDidLoad() to do things once
        
        /// Display extra UI
        ///     Doing this with a delay because it doesn't work if the tab switch animation is still ongoing
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, qos: .userInteractive, flags: [], execute: {
            
            ///
            /// Get info
            ///
            
            /// Get device info
            guard let (deviceName, nOfButtons, _) = MessagePortUtility_App.getActiveDeviceInfo() else { return }
            
            /// Get actionTable info
            let usedButtons = RemapTableUtility.getCapturedButtons()

            ///
            /// Show buyMouseAlert
            ///
            /// Notes:
            /// The idea was to show this under the __conditions__ that
            ///     - 1. The user is using a 3 button mouse
            ///     - 2. The alert hasn't been shown before
            ///     - 3. This isn't the first time opening the buttons tab
            ///     But I don't like it in it's current form so we're not showing it at all for now
            ///
            /// In the future we might __extend/improve__ the alert like this:
            ///     - 1. Make it prettier / more readable by using custom layout and markdown formatting
            ///     - 2. Include links to top 3 recommended mice (and maybe a link to a longer list of recommended mice). Maybe get a brand deal with some good mouse manufacturer for promoting their products.
            ///     - 3. Maybe show a small/unbtrustive toast instead of an alert and have it link to the more complex content / recommendations
            
            let showBuyMouseAlert = false
            
            if (showBuyMouseAlert) {
                
                /// Create alert
                
                let alert = NSAlert()
                alert.alertStyle = .informational
                alert.messageText = NSLocalizedString("buy-mouse-alert.title", comment: "First draft: Your mouse only has 3 buttons")
                alert.informativeText = NSLocalizedString("buy-mouse-alert.body", comment: "First draft: Get a mouse with 5+ buttons to unlock the full potential of Mac Mouse Fix!")
//                alert.showsSuppressionButton = true
                alert.addButton(withTitle: NSLocalizedString("buy-mouse-alert.ok", comment: "First draft: OK"))
                
                /// Display alert
                guard let window = MainAppState.shared.window else { return }
                alert.beginSheetModal(for: window) { _ in
                    
                    /// Show restoreDefault Popover
                    ///     after buyMouseAlert is dismissed
                    self.showRestoreDefaultPopover(deviceName: deviceName as String, nOfButtons: nOfButtons, usedButtons: usedButtons)
                    
                }
            } else {
                
                /// Show restoreDefault Popover
                ///     Immediately if buyMouseAlert is not shown at all
                
                self.showRestoreDefaultPopover(deviceName: deviceName as String, nOfButtons: nOfButtons, usedButtons: usedButtons)
            }
            
        })
        
        
        ///
        /// Turn off killswitch
        ///
        
        /// We do the exact same thing in the scrollTab
        
        let isDisabled = config("Other.buttonKillSwitch") as! Bool
        
        if isDisabled {
            
            /// Turn off killSwitch
            setConfig("Other.buttonKillSwitch", false as NSObject)
            commitConfig()
                
            /// Build string
            let messageRaw = NSLocalizedString("button-revive-toast", comment: "First draft: __Enabled__ Mac Mouse Fix for __Buttons__\nIt had been disabled from the Menu Bar %@ || Note: %@ will be replaced by the menubar icon")
            var message = NSAttributedString(coolMarkdown: messageRaw)!
            let symbolString = NSAttributedString(symbol: "CoolMenuBarIcon", hPadding: 0.0, vOffset: -6, fallback: "<Mac Mouse Fix Menu Bar Item>")
            message = NSAttributedString(attributedFormat: message, args: [symbolString])
            
            /// Show message
            ToastNotificationController.attachNotification(withMessage: message, to: MainAppState.shared.window!, forDuration: -1, alignment: kToastNotificationAlignmentTopMiddle)
        }
    }
    
    //
    // MARK: Other
    //
    
    @objc static func initRemaps() {
        
        /// This func doesn't clearly belong into `ButtonTabController`
        ///     Is called when the helper is enabled
        
        let hasBeenInited = config("Other.remapsAreInitialized") as! Bool? ?? false
        
        if !hasBeenInited {
            
            setConfig("Other.remapsAreInitialized", true as NSObject)
            commitConfig()
            
            let (_, _, bestPresetMatch) = MessagePortUtility_App.getActiveDeviceInfo() ?? (nil, nil, nil)
            
            /// This is copy-pasted from `restoreDefaults()`
            
            let currentMap = config("Remaps")
            let defaultMap = config(bestPresetMatch == 3 ? "Other.defaultRemaps.threeButtons" : "Other.defaultRemaps.fiveButtons")
            
            if (currentMap != defaultMap) {
                
                /// Set config
                setConfig("Remaps", defaultMap!)
                commitConfig()
                
                /// Reload table
                DispatchQueue.main.async {
                    MainAppState.shared.remapTableController?.reloadAll()
                }
            }
        }
    }
    
    //
    // MARK: - Restore Default Popover
    //
    
    /// Notes:
    ///  - The reason we're monitoring animations is that for some reason the ScrollTab breaks if we're switching from buttonTab to scrollTab while the restoreDefaltPopover is animating in. So we want to disallow tab switches while it's animating as a quick fix. 
    
    /// Outlets
    
    @IBOutlet var restoreDefaultPopover: NSPopover! /// Why is this one not weak and the other outlets are? Why would an outlet need to be not weak?
    @IBOutlet weak var restoreDefaultPopoverLabel: MarkdownTextField!
    @IBOutlet weak var restoreDefaultPopoverDontRemindAgainCheckbox: NSButton!
    
    /// Properties
    
    var restoreDefaultPopoverIsAnimating = false
    private var popoverMonitor: Any? = nil
    
    /// Delegate methods
    
    func popoverWillShow(_ notification: Notification) {
        restoreDefaultPopoverIsAnimating = true
    }
    func popoverDidShow(_ notification: Notification) {
        restoreDefaultPopoverIsAnimating = false
    }
    func popoverWillClose(_ notification: Notification) {
        restoreDefaultPopoverIsAnimating = true
    }
    func popoverDidClose(_ notification: Notification) {
        restoreDefaultPopoverIsAnimating = false
    }
    
    /// Show popover method
    
    fileprivate func showRestoreDefaultPopover(deviceName: String, nOfButtons: Int, usedButtons: Set<NSNumber>) {
        
        /// This is a helper for `viewDidAppear()`
        
        /// Put info together
        
        var show3Button = false
        var show5Button = false
        
        if usedButtons.isEmpty {
            
            /// All actions are disabled. The user probably did this on purpose. Reminding them that they are using the "wrong" layout is probably annoying, so we don't do it.
            
        } else if nOfButtons <= 2 {
            
            /// The current mouse has less than 2 buttons, it can't be used with Mac Mouse Fix, since button 3 is the lowest usable button currently.
            
        } else if 3 == nOfButtons
                    && !usedButtons.contains(3) {
            
            /// The recommended layout for this mouse is the 3 button layout, focused around button 3, but the current settings don't map anything to button 3. Since button 3 is the lowest usable button currently, this means that the current settings can't be doing anything for the currently active device. So we give the user a hint.
            
            show3Button = true
            
        } else if 4 == nOfButtons {
            
            /// Never seen a mouse with 4 buttons. Idk what the "recommended" settings should be here, so we just ignore this case
            
        } else if 5 <= nOfButtons
                    && !usedButtons.contains(4) && !usedButtons.contains(5) {
            
            /// The recommended layout for this mouse is the 5+ button layout, focused around button 4 and button 5, but the current settings don't map anything to button 4 or 5
            
            show5Button = true
        }
        if config("Other.dontRemindToRestoreDefault3") as? Bool ?? false {
            show3Button = false
        }
        if config("Other.dontRemindToRestoreDefault5") as? Bool ?? false {
            show5Button = false
        }
        assert(!(show3Button && show5Button))
        
        ///
        /// Show popover
        ///
        
        if show3Button || show5Button {
            
            ///
            /// Init popover UI
            ///
            
            /// Assign delegate
            ///     So we can observe animations
            self.restoreDefaultPopover.delegate = self
            
            /// Setup body text
            ///     There used to be different text based on whether your were using a 3 button or a 5 button mouse, but we've simplified that now
            
            let message = String(format: NSLocalizedString("restore-default-buttons-popover.body", comment: "First draft:  __Click here__ to load the recommended settings\nfor your __%@__ mouse || Note: The \n linebreak is so the popover doesn't become too wide. You can set it to your taste. || Note: In English, there needs to be a space at the start of this string otherwise the whole string will be bold. This might be a Ventura Bug"), deviceName)
            
            assignAttributedStringKeepingBase(&self.restoreDefaultPopoverLabel.attributedStringValue, NSAttributedString(coolMarkdown: message, fillOutBase: false)!)
            
            /// Turn checkbox off
            self.restoreDefaultPopoverDontRemindAgainCheckbox.state = .off
            
            /// Show
            self.restoreDefaultPopover.show(relativeTo: NSRect.zero, of: self.restoreDefaultButton, preferredEdge: .minY)
            
            /// Close on click
            ///     By intercepting events
            self.popoverMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
                
                /// Check click on window
                let clickedOnWindow = self.view.hitTest(event.locationInWindow) != nil
                
                /// Check click on popover
                let popupView = self.restoreDefaultPopover.contentViewController?.view
                let locInScreen = NSEvent.mouseLocation
                let locInPopupWindow = popupView?.window?.convertPoint(fromScreen: locInScreen)
                var clickedOnPopover = false
                if let loc = locInPopupWindow {
                    clickedOnPopover = popupView?.hitTest(loc) != nil
                }
                
                /// Close popover
                if clickedOnWindow && !clickedOnPopover {
                    
                    /// Store user choice about not being reminded again
                    //  TODO: Now that the UI message doesn't contain info about how many buttons the users mouse has and how that doesn't fit the current settings, it's kind of weird to make the don't remind based on button number. Intuitively it should maybe be based on mouse model? Not sure.
                    
                    let dontRemind = self.restoreDefaultPopoverDontRemindAgainCheckbox.state == .on
                    if dontRemind {
                        if show3Button {
                            setConfig("Other.dontRemindToRestoreDefault3", true as NSObject)
                            commitConfig()
                        } else if show5Button {
                            setConfig("Other.dontRemindToRestoreDefault5", true as NSObject)
                            commitConfig()
                        } else {
                            assert(false)
                        }
                    }
                    
                    /// Close popover
                    self.restoreDefaultPopover.close()
                    
                    /// Remove event monitor
                    if self.popoverMonitor != nil {
                        NSEvent.removeMonitor(self.popoverMonitor!)
                        self.popoverMonitor = nil
                    }
                }
                
                /// Return intercepted event
                return event
            }
        }
    }
    
    //
    // MARK: - AddView
    //
    
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
        
        let messageRaw = NSLocalizedString("forbidden-capture-toast.1", comment: "First draft: **Primary Mouse Button** can't be used\nPlease try another button")
        let message = NSAttributedString(coolMarkdown: messageRaw)!;
        
        ToastNotificationController.attachNotification(withMessage: message, to: MainAppState.shared.window!, forDuration: -1)
    }
    override func rightMouseUp(with event: NSEvent) {
        if !pointerIsInsideAddField { return }
        
        let messageRaw = NSLocalizedString("forbidden-capture-toast.2", comment: "First draft: **Secondary Mouse Button** can't be used\nPlease try another button")
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
                                self.plusIconView.reactiveAnimator().contentTintColor.set(self.plusIconViewBaseColor())
                            }
                        })
                    }
                } else { /// Normal un-hovering
                    Animate.with(CASpringAnimation(speed: 3.5, damping: 1.3)) {
                        self.plusIconView.reactiveAnimator().contentTintColor.set(self.plusIconViewBaseColor())
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
    
    private func plusIconViewBaseColor() -> NSColor {
        
        return NSColor.systemGray
    }
    
    private func isDarkMode() -> Bool {
        
        if #available(macOS 10.14, *) {
            let isDarkMode = (NSApp.effectiveAppearance == .init(named: .darkAqua)!)
            return isDarkMode
        }
        return false
    }
}
