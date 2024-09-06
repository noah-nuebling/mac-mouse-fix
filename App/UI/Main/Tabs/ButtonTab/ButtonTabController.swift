//
// --------------------------------------------------------------------------
// ButtonTabController.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Foundation

@objc class ButtonTabController: NSViewController, NSPopoverDelegate {
    
    //
    // MARK: - Outlets
    //
    
    /// AddField
    
    @IBOutlet weak var addField: AddField!
    
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
        alert.messageText = NSLocalizedString("restore-buttons-alert.title", comment: "")
        alert.informativeText = ""
        
        let restoreButton = alert.addButton(withTitle: NSLocalizedString("restore-buttons-alert.commit", comment: ""))
        let cancelButton = alert.addButton(withTitle: NSLocalizedString("restore-buttons-alert.back", comment: ""))
        restoreButton.keyEquivalent = IBUtility.keyChar(forLiteral: "return")
        cancelButton.keyEquivalent = IBUtility.keyChar(forLiteral: "escape")
        
        ///
        /// Get device info
        ///
        
        /// Get info
        let (name, nOfButtons, bestPresetMatch) =  MessagePortUtility.shared.getActiveDeviceInfo() ?? (nil, nil, nil)
        /// Process info
        ///     Note: Use non-breaking-space for nicer layout for long mouse names. (E.g. my VXE mouse connected over BT has the name "RivieraWaves SAS VXE R1SE+")
        ///         Update: Actually like the layout less with nbsp.
//        name = name?.replacingOccurrences(of: " ", with: "\u{00a0}") as NSString?
        
        ///
        /// Add accessoryView
        ///
        
        let radio1 = NSButton(radioButtonWithTitle: NSLocalizedString("restore-buttons-alert.radio1", comment: ""), target: self, action: #selector(nullAction(sender:)))
        let radio2 = NSButton(radioButtonWithTitle: NSLocalizedString("restore-buttons-alert.radio2", comment: ""), target: self, action: #selector(nullAction(sender:)))
        radio1.setAccessibilityIdentifier("axRestoreButtons3")
        radio2.setAccessibilityIdentifier("axRestoreButtons5")
        
        let radioStack = NSStackView(views: [radio1, radio2])
        
        var hint: CoolNSTextField? = nil
        if let nOfButtons = nOfButtons {
            
            let hintStringRaw = String(format: NSLocalizedString("restore-buttons-alert.hint", comment: "Note: '%1$@' will be the name of the mouse, such as 'Logitech M720 Triathlon'"), name!, nOfButtons)
            
//            let hintString = NSAttributedString(coolMarkdown: hintStringRaw)?.settingSecondaryLabelColor(forSubstring: nil).settingFontSize(NSFont.smallSystemFontSize).aligningSubstring(nil, alignment: .center).trimmingWhitespace()
            let hintString = NSAttributedString(coolMarkdown: hintStringRaw)?.adding(.secondaryLabelColor, for: nil).settingFontSize(NSFont.smallSystemFontSize).adding(.center, for: nil).trimmingWhitespace()
            
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
                let defaultMap = config(selectedPreset == 3 ? "Constants.defaultRemaps.threeButtons" : "Constants.defaultRemaps.fiveButtons")
                
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
                    
                    if selectedPreset == 3 {    
                        Toasts.showSimpleToast(name: "k-already-using-defaults-toast.3")
                    } else {
                        
                        Toasts.showSimpleToast(name: "k-already-using-defaults-toast.5")
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
        nonGarbageInit()
    }
    
    required init?(coder: NSCoder) {
        
        /// Set garbage values
        pointerIsInsideAddField = false
        trackingArea = NSTrackingArea()
        
        /// Init super
        super.init(coder: coder)
        
        /// Real init
        nonGarbageInit()
    }
    
    func nonGarbageInit() {
        
        /// Note: Why are we doing some stuff in init and some in viewDidLoad? I don't understand the logic behind that.
        
        /// Validate: Init is not called twice
        assert(MainAppState.shared.buttonTabController == nil)
        
        /// Store self into global state
        ///     Why is this in `initAddFieldStuff`?
        MainAppState.shared.buttonTabController = self
        
        /// Init state
        pointerIsInsideAddField = false
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        /// Init remaps when the helper becomes (or already is) enabled
        ///     This doesn't really belong here. It just needs to be executed when the app is first enabled.
        ///     TODO: Move this. E.g. to   `AppDelegate - applicationDidFinishLaunching`
        ///
        EnabledState.shared.producer.startWithValues { enabled in
            if enabled { ButtonTabController.initRemaps() }
        }
        /// Add trackingArea
        createTrackingArea()
        
        /// Init AddField visuals
        addField.coolInit()
    }
    
    func createTrackingArea() {
        trackingArea = NSTrackingArea(rect: self.addField.bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow], owner: self)
        self.addField.addTrackingArea(trackingArea)
    }
    
    // MARK: Did appear
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        /// This is called every time the tab is switched to
        /// This is called twice, awakeFromNib as well. Use init() or viewDidLoad() to do things once
        
        /// Update tableView size
        self.tableView.updateSize(withAnimation: false, tabContentView: self.view)
        
        /// Display extra UI
        ///     Doing this with a delay because it doesn't work if the tab switch animation is still ongoing
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, qos: .userInteractive, flags: [], execute: {
            
            ///
            /// Get info
            ///
            
            /// Get device info
            guard let (deviceName, nOfButtons, _) = MessagePortUtility.shared.getActiveDeviceInfo() else { return }
            
            /// Get actionTable info
            let usedButtons = RemapTableUtility.getCapturedButtonsAndExcludeButtonsThatAreOnlyCaptured(byModifier: false)

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
            ///
            /// Update Summer 2024:
            /// -  If you implement this don't forget to consider making this escape-dismissable, like most other sheets and alerts in the app.
            /// - Also probably move this into ToastAndSheetTests if you implement this.
            
            let showBuyMouseAlert = false
            
            if (showBuyMouseAlert) {
                
                /// Create alert
                
                let alert = NSAlert()
                alert.alertStyle = .informational
                alert.messageText = NSLocalizedString("buy-mouse-alert.title", comment: "")
                alert.informativeText = NSLocalizedString("buy-mouse-alert.body", comment: "")
//                alert.showsSuppressionButton = true
                alert.addButton(withTitle: NSLocalizedString("buy-mouse-alert.ok", comment: ""))
                
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
        
        let buttonsAreKilled = config("General.buttonKillSwitch") as! Bool
        let scrollIsKilled = config("General.scrollKillSwitch") as! Bool
        
        if buttonsAreKilled || scrollIsKilled {
            
            /// Turn off killSwitch
            ///     NOTE: We also turn off the scrollKillSwitch because otherwise we can't record click and scroll in addMode.
            setConfig("General.buttonKillSwitch", false as NSObject)
            setConfig("General.scrollKillSwitch", false as NSObject)
            commitConfig()
            
            /// Show user feedback
            Toasts.showReviveToast(showButtons: buttonsAreKilled, showScroll: scrollIsKilled)
        }
    }
    
    //
    // MARK: Other
    //
    
    @objc static func initRemaps() {
        
        /// This func doesn't clearly belong into `ButtonTabController`
        ///     Is called when the helper is enabled
        
        let hasBeenInited = config("State.remapsAreInitialized") as! Bool? ?? false
        
        if !hasBeenInited {
            
            setConfig("State.remapsAreInitialized", true as NSObject)
            commitConfig()
            
            let (_, _, bestPresetMatch) = MessagePortUtility.shared.getActiveDeviceInfo() ?? (nil, nil, nil)
            
            /// This is copy-pasted from `restoreDefaults()`
            
            let currentMap = config("Remaps")
            let defaultMap = config(bestPresetMatch == 3 ? "Constants.defaultRemaps.threeButtons" : "Constants.defaultRemaps.fiveButtons")
            
            if (currentMap != defaultMap) {
                
                /// Set config
                setConfig("Remaps", defaultMap!)
                commitConfig()
                
                /// Reload table
                /// Note: It feels a bit hacky to call `updateColumnWidths()` here. Maybe this should be handled automatically inside the remapTable code.
                DispatchQueue.main.async {
                    MainAppState.shared.remapTableController?.reloadAll()
                    MainAppState.shared.buttonTabController?.tableView.updateColumnWidths()
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
    
    private var restoreDefaultPopover_stringAttributesFromIB: [NSAttributedString.Key : Any]? = nil
    
    func showRestoreDefaultPopover(deviceName: String, nOfButtons: Int, usedButtons: Set<NSNumber>) {
        
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
            
            /// Store attributes from IB
            if restoreDefaultPopover_stringAttributesFromIB == nil {
                restoreDefaultPopover_stringAttributesFromIB = self.restoreDefaultPopoverLabel.attributedStringValue.attributes(at: 0, effectiveRange: nil)
            }
            
            /// Setup body text
            ///     There used to be different text based on whether your were using a 3 button or a 5 button mouse, but we've simplified that now
            /// I wrote this note: "In English, there needs to be a space at the start of this string otherwise the whole string will be bold. This might be a Ventura Bug"
            ///     -> I think this problem will be resolved by us using `**` instead of `__` for emphasis.
            /// TODO: The 'Don't remind me again' checkbox at the bottom of the popover is loaded directly from the nib file. So it's localizable string is in a totally different place. This might be confusing for localizers.
            
            let message = String(format: NSLocalizedString("restore-default-buttons-popover.body", comment: "Note: The linebreak is so the popover doesn't become too wide. You can set the linebreak to your own taste. || Hint: if text in your language is typically around X times longer than English, then the lines here probably should not be much longer than X times the English version."), deviceName)
            
            if let attributes = restoreDefaultPopover_stringAttributesFromIB, let newString = NSAttributedString(coolMarkdown: message, fillOutBase: false)?.addingStringAttributes(asBase: attributes) {
                
                self.restoreDefaultPopoverLabel.attributedStringValue = newString
            }
            
            /// Turn checkbox off
            self.restoreDefaultPopoverDontRemindAgainCheckbox.state = .off
            
            /// Show
            self.restoreDefaultPopover.show(relativeTo: NSRect.zero, of: self.restoreDefaultButton, preferredEdge: .minY)
            
            /// Close on click
            ///     By intercepting events
            self.popoverMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .keyDown]) { event in
                    
                var shouldClose: Bool
                var shouldPassThroughEvent: Bool = true
                if event.type == .keyDown {
                    /// Handle keydown
                    shouldClose = (event.keyCode == kVK_Escape)
                    shouldPassThroughEvent = false /// Otherwise there's an NSBeep
                } else {
                    /// Handle clicks
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
                    
                    /// Set shouldClose
                    shouldClose = clickedOnWindow && !clickedOnPopover
                }

                /// Close popover
                if shouldClose {
                    
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
                return shouldPassThroughEvent ? event : nil
            }
        }
    }
    
    //
    // MARK: - AddView
    //
    
    /// Vars
    
    var pointerIsInsideAddField: Bool
    var trackingArea: NSTrackingArea
    
    /// AddField callbacks
    ///     TODO: Maybe think about race condition for the mouseEntered and mouseExited functions

    override func mouseEntered(with event: NSEvent) {
        DispatchQueue.main.async {
            
            /// Not sure it makes sense to dispatch async for mouseEntered and mouseExited. We added that dispatch when addField.hoverEffect was controlled by messages we received instead of being based on response to the the messages we sent.
            /// Here are some notes we wrote for the old architecture:
            /// \discussion After addMode refactoring around commit 02c9fcc20d3f03d8b0d2db6e25830276ed937107 I saw a deadlock in the animationCode maybe dispatch to main will prevent it. Edit: Nope still happens. Edit2: Could fix the deadlock by not locking the CATransaction in Animate.swift. So dispatching to main here might be unnecessary.
            
            DDLogInfo("trackingg: mouseEntered")
            
            self.pointerIsInsideAddField = true
            let success = MFMessagePort.sendMessage("enableAddMode", withPayload: nil, waitForReply: true)
            if let success = success as? Bool, success == true {
                self.addField.hoverEffect(enable: true)
            }
        }
    }
    override func mouseExited(with event: NSEvent) {
        DispatchQueue.main.async {
            self.mouseExited_Internal(dueToAddModeFeeback: false)
        }
    }
    
    func mouseExited_Internal(dueToAddModeFeeback: Bool) {
        
        DDLogInfo("trackingg: mouseExited dueToAddMode: \(dueToAddModeFeeback)")
        
        self.pointerIsInsideAddField = false
        MFMessagePort.sendMessage("disableAddMode", withPayload: nil, waitForReply: false)
        self.addField.hoverEffect(enable: false, playAcceptAnimation: dueToAddModeFeeback)
    }

    @objc func handleAddModeFeedback(payload: NSDictionary) {
        
        DispatchQueue.main.async {
            
            /// Debug
            DDLogDebug("Received AddMode feedback with payload: \(payload)")
            
            /// Send payoad to tableController
            ///     The payload is an almost finished remapsTable (aka RemapTableController.dataModel) entry with the kMFRemapsKeyEffect key missing
            self.tableController.addRow(withHelperPayload: payload as! [AnyHashable : Any])
            
            /// HACK: Force trackingArea to exit
            /// - We need to do this because `addRow()` opens an `NSMenu`. And when an NSMenu is open, `NSTrackingArea` doesn't work properly, leading to weird behaviour.
            ///     (The weird behaviour is that the mouse needs to enter twice before `mouseEntered()` is called again)
            /// - Not totally sure if the + 0.5 delay is necessary or optimal. But I did some testing and it seems to work really well like this.
            
            self.mouseExited_Internal(dueToAddModeFeeback: true)
            self.addField.removeTrackingArea(self.trackingArea)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                self.createTrackingArea()
            })
        }
    }
    
    /// Ignore MB1 & MB2
    ///     TODO: Use format strings and shared functions from UIStrings.m to obtain button names

    override func mouseUp(with event: NSEvent) {
        
        if !pointerIsInsideAddField { return }
        
        Toasts.showSimpleToast(name: "k-forbidden-capture-toast.1")
    }
    override func rightMouseUp(with event: NSEvent) {
        
        if !pointerIsInsideAddField { return }
        
        Toasts.showSimpleToast(name: "k-forbidden-capture-toast.2")
    }
}
