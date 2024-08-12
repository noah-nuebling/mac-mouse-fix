//
// --------------------------------------------------------------------------
// LocalizationScreenshots.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import XCTest

final class LocalizationScreenshotClass: XCTestCase {
    
    ///
    /// Constants
    ///
    
    /// Keep-in-sync with .app
    let localizedStringAnnotationActivationArgumentForScreenshottedApp = "-MF_ANNOTATE_LOCALIZED_STRINGS"
    let localizedStringAnnotationRegexForScreenshottedApp = "mfkey:(.+):(.*):" /// The first capture group is the localizationKey, the second capture group is the stringTableName
    
    /// Keep-in-sync with python script
    let xcode_screenshot_taker_output_dir_variable = "MF_LOCALIZATION_SCREENSHOT_OUTPUT_DIR"
    
    /// Keep in sync with .xcloc format
    let xcode_screenshot_taker_outputted_metadata_filename = "localizedStringData.plist"
    typealias LocalizedStringData = [LocalizedStringDatum] /// localizedStringData.plist, which is found inside .xcloc screenshot folders, has this structure
    struct LocalizedStringDatum: Encodable {
        /// Core information
        let stringKey: String
        var screenshots: [Screenshot]
        struct Screenshot: Encodable {
            let name: String
            let frame: String /// Encoding of NSRect describing where the localized ui string associated with `stringKey` appears in the screenshot.
        }
        /// These fields can be whatever I think.
        let tableName: String
        let bundlePath: String
        let bundleID: String
    }
    
    ///
    /// Internal datatypes
    ///
    
    struct ScreenshotAndMetadata {
        let screenshot: XCUIScreenshot
        let metadata: Metadata
        struct Metadata {
            let name: String
            let frames: [Frame]
            struct Frame {
                let frame: NSRect
                let strings: [String_]
                struct String_ {
                    let string: String
                    let keys: [KeyAndTable]
                    struct KeyAndTable {
                        let key: String
                        let table: String
                    }
                }
            }
        }
    }
    
    ///
    /// Main routine
    ///
    var appSnap: XCUIElementSnapshot? = nil /// This probably get out of date when the app state changes
    var appAXUIElement: AXUIElement? = nil  /// This doesn't get out of date I think
    var _app: XCUIApplication? = nil
    var app: XCUIApplication? {
        get { _app }
        set {
            _app = newValue
            appSnap = try! app!.snapshot()
            appAXUIElement = getAXUIElementForXCElementSnapshot(appSnap!)!.takeUnretainedValue()
        }
    }
    var alreadyLoggedHitTestFailers: [AXUIElement] = []
    
    func testTakeLocalizationScreenshots() throws {
        
        // --------------------------
        // MARK: Main
        // --------------------------
        
        /// Configure test
        self.continueAfterFailure = false
        
        /// Get output folder
        var outputDirectory: URL? = nil
        XCTContext.runActivity(named: "Get Output Folder") { activity in
            let outputDirectoryPath = ProcessInfo.processInfo.environment[xcode_screenshot_taker_output_dir_variable]
            if outputDirectoryPath != nil {
                outputDirectory = URL(fileURLWithPath: outputDirectoryPath!).absoluteURL
            }
            if outputDirectoryPath == nil {
                let currentWorkingDirectory = FileManager().temporaryDirectory
                outputDirectory = currentWorkingDirectory.appending(component: "MFLocalizationScreenshotsFallbackOutputFolder")
                DDLogInfo("No output directory provided. Using \(outputDirectory!) as a fallback.")
            }
        }
        guard let outputDirectory = outputDirectory else { fatalError() }
        
        /// Declare result
        var screenshotsAndMetaData: [ScreenshotAndMetadata?] = []
        
        /// Log
        DDLogInfo("Localization Screenshot Test Runner launched with output directory: \(xcode_screenshot_taker_output_dir_variable): \(outputDirectory)")
        
        var mainApp: XCUIApplication
        mainApp = XCUIApplication()
        
        /// Prepare helper app
        ///     We should launch the helper first, and not let the app enable it, so we can control its launchArguments.
        let helperPath = (mainApp.value(forKey:"path") as! NSString).appendingPathComponent("Contents/Library/LoginItems/Mac Mouse Fix Helper.app")
        let helperApp = XCUIApplication(url: URL(fileURLWithPath: helperPath))
        helperApp.launchArguments.append(localizedStringAnnotationActivationArgumentForScreenshottedApp)
        helperApp.launch()
        
        /// Prepare mainApp
        mainApp.launchArguments.append(localizedStringAnnotationActivationArgumentForScreenshottedApp) /// `["-AppleLanguages", "(de)"]`
        mainApp.launch()
        
        ///
        /// Helper
        ///
        
        /// Take helper screenshots
        app = helperApp
        XCTContext.runActivity(named: "Take Helper Screenshots") { activity in
            screenshotsAndMetaData.append(contentsOf: navigateHelperAppAndTakeScreenshots(outputDirectory))
        }
        
        ///
        /// Main App
        ///
        
        /// Take mainApp screenshots
        app = mainApp
        XCTContext.runActivity(named: "Take MainApp Screenshots") { activity in
            let newScreenshotsAndMetaData = navigateAppAndTakeScreenshots(outputDirectory)
            screenshotsAndMetaData.append(contentsOf: newScreenshotsAndMetaData)
        }
        /// Validate with mainApp
        XCTContext.runActivity(named: "Validate Completeness") { activity in
            /// We only validate toasts. if we add a new screen or other UI to the app that should be screenshotted, we don't have a way to detect that here.
            let didShowAllToastsAndSheets = (MFMessagePort.sendMessage("didShowAllToastsAndSheets", withPayload: nil, toRemotePort: kMFBundleIDApp, waitForReply: true) as! NSNumber).boolValue
            if (!didShowAllToastsAndSheets) {
                XCTFail("The app says we missed screenshotting some toast notifications.")
            }
        }
        
        ///
        /// Write results
        ///
        
        XCTContext.runActivity(named: "Write results") { activity in
            writeResults(screenshotsAndMetaData, outputDirectory)
        }
    }
    
    // --------------------------
    // MARK: Helper Screenshots
    // --------------------------
    
    fileprivate func navigateHelperAppAndTakeScreenshots( _ outputDirectory: URL) -> [ScreenshotAndMetadata?] {
        
        /// Declare result
        var result = [ScreenshotAndMetadata?]()
        
        /// Get menuBarItem
        let statusItem = app!.statusItems.firstMatch
        
        if (!statusItem.exists) {
            XCTFail("Couldn't get the the menuBarItem. Make sure to switch on 'Show in MenuBar' before running the test")
        }
        
        /// Take screenshot
        statusItem.click()
        let menu = statusItem.menus.firstMatch
        assert(menu.exists)
        let screenshot = takeLocalizationScreenshot(of: menu, name: "Status Item Menu")
        XCTAssert(screenshot != nil, "Could not take screenshots with any localization data for Status Bar Item. Perhaps, the Helper App was started without the localizedString annotation argument? (If so, close the helper and let this test-runner start it)")
        result.append(screenshot)
        
        /// Cleanup
        hitEscape()
        
        /// Return
        return result
    }
    
    // --------------------------
    // MARK: Main App Screenshots
    // --------------------------
    
    fileprivate func navigateAppAndTakeScreenshots( _ outputDirectory: URL) -> [ScreenshotAndMetadata?] {
        
        /// Declare result
        var result = [ScreenshotAndMetadata?]()
        
        /// Define toast-screenshotting helper closure
        let takeToastScreenshots = { (toastSection: String, screenshotNameFormat: String) -> [ScreenshotAndMetadata?] in
            
            var toastScreenshots = [ScreenshotAndMetadata?]()
            var i = 0
            while true {
                
                /// Display next toast/sheet/popover
                let moreToastsToGo = MFMessagePort.sendMessage("showNextToastOrSheetWithSection", withPayload: (toastSection as NSString), toRemotePort: kMFBundleIDApp, waitForReply: true)
                self.coolWait() /// Wait for appear animation
                
                /// TEST
//                print("lastWasToast: \(lastWasToast)")
//                let snap = try! self.app!.snapshot()
//                let tree = TreeNode.tree(withKVCObject: snap, childrenKey: "children")
//                let toastWindowSnap = try! self.app!.dialogs["axToastWindow"].firstMatch.snapshot()
//                let toastWindowScreenshot = self.app!.dialogs["axToastWindow"].firstMatch.screenshot()
//                let testExist = self.app!.dialogs["axToastWindow"].firstMatch.exists
                
                /// Find transient window
                ///     Explanation for .isHittable usage:
                ///         When we fade out the toasts, we just set their alphaValue to 0, but they still exist in the view- and accessibility-hierarchy.
                ///         When the alphaValue is 0, `.isHittable` becomes false. That is it the easiest way I found to discern whether a toast is actually being displayed.
                var isToast = false
                var isPopover = false
                var isSheet = false
                
                var transientUIElement = self.app!.dialogs["axToastWindow"].firstMatch /// Check for toast
                if transientUIElement.exists && transientUIElement.isHittable {
                    isToast = true
                } else {
                    transientUIElement = self.app!.popovers.firstMatch /// Check for popover
                    if transientUIElement.exists && transientUIElement.isHittable {
                        isPopover = true
                    } else {
                        transientUIElement = self.app!.sheets.firstMatch /// Check for sheet
                        if transientUIElement.exists && transientUIElement.isHittable {
                            isSheet = true
                        } else {
                            assert(false)
                        }
                    }
                }
                
                if isToast {
                    
                    /// Take toast screenshot
                    toastScreenshots.append(self.takeLocalizationScreenshot(of: transientUIElement, name: String(format: screenshotNameFormat, i)))
                    
                    /// Dismiss toast
                    /// Note:
                    ///     We don't have to do this between toasts, because toasts automatically dismiss themselves before another toast comes in.
                    ///     Leveraging would allow us to speed up the test runs.
                    ///     Problem is that when we don't dismiss the toast that makes the isToast, isSheet, isPopover detection more difficult.
                    self.hitEscape()
                    self.coolWait()
                
                } else if isPopover || isSheet {
                    
                    /// Take sheet screenshot
                    toastScreenshots.append(self.takeLocalizationScreenshot(of: transientUIElement, name: String(format: screenshotNameFormat, i)))

                    /// Dismiss sheet
                    self.hitEscape()
                    self.coolWait()
                } else {
                    assert(false)
                }
                
                /// Break
                if (moreToastsToGo == nil || (moreToastsToGo! as! NSNumber).boolValue == false) {
                    break;
                }
                
                /// Increment
                i += 1
            }
            
            /// Return
            return toastScreenshots
        }
        
        /// Find screen
        let screen = NSScreen.main!
        
        /// Find main window
        let window = app!.windows.firstMatch
        
        /// Find tab buttons
        let toolbarButtons = window.toolbars.firstMatch.children(matching: .button) /// `window.toolbarButtons` doesn't work for some reason.
        
        /// Find menuBar
        let menuBar = app!.menuBars.firstMatch
        
        /// Position the window
        let targetWindowY = 0.2 /// Normalized between 0 and 1
        let targetWindowPosition = NSMakePoint(screen.frame.midX - window.frame.width/2.0, /// Just center the window horizontally
                                               targetWindowY * (screen.frame.height - window.frame.height))
        let appleScript = NSAppleScript(source: """
        tell application "System Events"
            set position of window 1 of process "Mac Mouse Fix" to {\(targetWindowPosition.x), \(targetWindowPosition.y)}
        end tell
        """)
        var error: NSDictionary? = nil
        appleScript?.executeAndReturnError(&error)
        assert(error == nil)
        
        ///
        /// Validate that the app is enabled
        ///
        
        /// Go to general tab
        toolbarButtons["general"].click()
        coolWait()
        
        /// Find enable toggle
        let switcherino = window.switches["axEnableToggle"].firstMatch
        
        /// Assert that the app is enabled
        ///     We're launching the helper directly from the testRunner, so we can pass it arguments
        if ((switcherino.value as! Int) != 1) {
            XCTFail("Error: The app does not seem to be enabled, the test should do this automatically")
        }
        
        ///
        /// Screenshot ButtonsTab
        ///
        
        toolbarButtons["buttons"].click()
        coolWait()
        
        /// Dismiss restoreDefaultsPopover, in case it pops up.
        hitEscape()
        coolWait()
        
        /// Screenshot states
        let restoreDefaultsButton = window.buttons["axButtonsRestoreDefaultsButton"].firstMatch
        assert(restoreDefaultsButton.exists)
        restoreDefaultsButton.click()
        let restoreDefaultsSheet = window.sheets.firstMatch
        let restoreDefaultsRadioButtons = restoreDefaultsSheet.radioButtons.allElementsBoundByIndex
        for (i, radioButton) in restoreDefaultsSheet.radioButtons.allElementsBoundByIndex.reversed().enumerated() { /// Reversed for debugging
            radioButton.click()
            hitReturn()
            hitEscape() /// Close any toasts
            result.append(takeLocalizationScreenshot(of: window, name: "ButtonsTab State \(i)"))
            restoreDefaultsButton.click() /// Open the sheet back up
        }
        
        /// Go to default state
        ///     (Default settings for 5+ buttons)
        let defaultRadioButton = restoreDefaultsSheet.radioButtons["axRestoreButtons5"]
        assert(defaultRadioButton.exists)
        defaultRadioButton.click()
        hitReturn()
        hitEscape()
        
        /// Screenshot menus
        ///     (Which let you pick the action in the remaps table)
        for (i, popupButton) in window.popUpButtons.allElementsBoundByIndex.enumerated() {
            
            /// Click
            popupButton.click()
            let menu = popupButton.menus.firstMatch
            
            /// Screenshot
            result.append(takeLocalizationScreenshot(of: menu, name: "ButtonsTab Menu \(i)"))
            
            /// Option screenshot
            XCUIElement.perform(withKeyModifiers: .option) {
                result.append(takeLocalizationScreenshot(of: menu, name: "ButtonsTab Menu \(i) (Option)"))
            }
            
            /// Clean up
            hitEscape()
        }
        
        /// Screenshot buttonsTab sheets
        ///     (The ones invoked by the two buttons in the bottom left and bottom right)
        for (i, button) in window.buttons.matching(NSPredicate(format: "identifier IN %@", ["axButtonsOptionsButton", "axButtonsRestoreDefaultsButton"])).allElementsBoundByIndex.enumerated() {
            
            /// Click
            button.click()
            coolWait() /// Not necessary. Sheets have a native animation where XCUITest automatically correctly
            
            /// Get sheet
            let sheet = window.sheets.firstMatch
            
            /// Screenshot
            result.append(takeLocalizationScreenshot(of: sheet, name: "ButtonsTab Sheet \(i)"))
            
            /// Cleanup
            hitEscape()
        }
        
        /// Screenshots ButtonsTab toasts
        result.append(contentsOf: takeToastScreenshots("buttons", "ButtonsTab Toast %d"))
        
        ///
        /// Screenshot GeneralTab
        ///
        
        /// Switch to general tab
        toolbarButtons["general"].click()
        coolWait() /// Need to wait so that the test runner properly waits for the animation to finish
        
        /// Enable updates
        ///     (So that the beta section is expanded)
        let updatesToggle = window.checkBoxes["axCheckForUpdatesToggle"].firstMatch
        if (updatesToggle.value as! Int) != 1 {
            updatesToggle.click()
            coolWait()
        }
        
        /// Take screenshot of fully expanded general tab
        result.append(takeLocalizationScreenshot(of: window, name: "GeneralTab"))

        /// Screenshot toasts
        result.append(contentsOf: takeToastScreenshots("general", "GeneralTab Toast %d"))
        
        ///
        /// Screenshot menubar
        ///
        
        /// Screenshot menuBar itself
        result.append(takeLocalizationScreenshot(of: menuBar, name: "MenuBar"))
        
        /// Screenshot each menuBarItem
        var didClickMenuBar = false
        for (i, menuBarItem) in menuBar.menuBarItems.allElementsBoundByIndex.enumerated() {
            
            /// Skip Apple menu
            if i == 0 { continue }
            
            /// Reveal menu
            if !didClickMenuBar {
                menuBarItem.click()
                didClickMenuBar = true
            } else {
                menuBarItem.hover()
            }
            let menu = menuBarItem.menus.firstMatch
            
            /// Take screenshot of menu
            result.append(takeLocalizationScreenshot(of: menu, name: "MenuBar Menu \(i)"))
            
            /// Take screenshot with option held (reveal secret/alternative menuItems)
            XCUIElement.perform(withKeyModifiers: .option) {
                result.append(takeLocalizationScreenshot(of: menu, name: "MenuBar Menu \(i) (Option)"))
            }
        }
        
        /// Dismiss menu
        if didClickMenuBar {
            hitEscape()
        }
        
        ///
        /// Screenshot special views only accessible through the menuBar
        ///
        
        /// Find "activate" license menu item
        let macMouseFixMenuItem = menuBar.menuBarItems.allElementsBoundByIndex[1]
        macMouseFixMenuItem.click()
        let macMouseFixMenu = macMouseFixMenuItem.menus.firstMatch
        let activateLicenseItem = macMouseFixMenu.menuItems["axMenuItemActivateLicense"].firstMatch
        
        /// Click
        activateLicenseItem.click()
        
        /// Delete license key
        /// Delete license key from the textfield, so it's hidden in the screenshot, and the placeholder appears instead
        app?.typeKey(.delete, modifierFlags: [])
        
        /// Find sheet
        var sheet = window.sheets.firstMatch
        
        /// Sheenshot
        result.append(takeLocalizationScreenshot(of: sheet, name: "ActivateLicenseSheet"))
        
        /// Screenshot toasts
        result.append(contentsOf: takeToastScreenshots("licensesheet", "ActivateLicenseSheet Toast %d"))
        
        /// Cleanup licenseSheet
        hitEscape()
        
        ///
        /// Screenshot AboutTab
        ///
        
        toolbarButtons["about"].click()
        coolWait()
        result.append(takeLocalizationScreenshot(of: window, name: "AboutTab"))
        
        /// Screenshot alert
        
        /// Click
        window.staticTexts["axAboutSendEmailButton"].firstMatch.click()
        
        /// Get sheet
        sheet = window.sheets.firstMatch
        
        /// Screenshot
        result.append(takeLocalizationScreenshot(of: sheet, name: "AboutTab Email Alert"))
        
        /// Cleanup
        hitEscape()
        
        ///
        /// Screenshot ScrollingTab
        ///
        
        toolbarButtons["scrolling"].click()
        coolWait()
        
        /// Initialize state of tab
        let restoreDefaultModsButton = window.buttons["axScrollingRestoreDefaultModifiersButton"].firstMatch
        if restoreDefaultModsButton.exists {
            restoreDefaultModsButton.click()
        }
        
        /// Screenshot states
        for (i, popUpButton) in window.popUpButtons.allElementsBoundByIndex.enumerated() {
            
            /// Gather menu items
            popUpButton.click()
            let menuItems = popUpButton.menuItems.allElementsBoundByIndex.enumerated()
            hitEscape()
            
            for (j, menuItem) in menuItems {
                
                /// Click popUpButton
                popUpButton.click()
                if (!menuItem.isHittable || !menuItem.isEnabled) {
                    hitEscape()
                    continue
                }
                
                /// Click menu item
                menuItem.click()
                coolWait()
                
                /// Screenshot state of scrolling tab
                result.append(takeLocalizationScreenshot(of: window, name: "ScrollingTab State \(i)-\(j)"))
            }
        }
        
        /// Screenshot scrollingTab menus
        for (i, popUpButton) in window.popUpButtons.allElementsBoundByIndex.enumerated() {
            
            /// Click popup button
            popUpButton.click()
            let menu = popUpButton.menus.firstMatch
            
            /// Take screenshot
            result.append(takeLocalizationScreenshot(of: menu, name: "ScrollingTab Menu \(i)"))
            XCUIElement.perform(withKeyModifiers: .option) {
                if ((false)) { /// The menus on the scrolling tab don't have secret options, at least at the time of writing. NOTE: Update this if you add secret options.
                    result.append(takeLocalizationScreenshot(of: menu, name: "ScrollingTab Menu \(i) (Option)"))
                }
            }
            
            /// Cleanup
            hitEscape()
        }
        
        /// Screenshots ScrollingTab toasts
        result.append(contentsOf: takeToastScreenshots("scrolling", "ScrollingTab Toast %d"))
        
        ///
        /// Return
        ///
        
        return result
    }
    
    // --------------------------
    // MARK: Write results
    // --------------------------
    
    fileprivate func writeResults(_ screenshotsAndMetadata: [ScreenshotAndMetadata?], _ outputDirectory: URL) {
        
        /// Convert screenshotsAndMetadata to localizedStringData.plist structure
        var screenshotNameToScreenshotDataMap = [String: Data]()
        var localizedStringData: LocalizedStringData = []
        for scr in screenshotsAndMetadata {
            
            guard let scr = scr else { continue }
            
            var screenshotUsageCount = 0
            
            let screenshot = scr.screenshot
            let screenshotName = scr.metadata.name
            for fr in scr.metadata.frames {
                let stringFrame = fr.frame
                for str in fr.strings {
                    let localizedString = str.string
                    for k in str.keys {
                        let stringKey = k.key
                        var stringTable = k.table
                        
                        /// Map empty table to "Localizable"
                        ///     Otherwise the Xcode screenshot viewer breaks.
                        if stringTable == "" { stringTable = "Localizable" }
                        
                        /// Duplicate screenshot
                        ///     Each stringKey needs its own, unique screenshot file, otherwise the Xcode viewer breaks and shows the same frame for every string key. (Tested under Xcode 15 stable & Xcode 16 Beta)
                        screenshotUsageCount += 1
                        let screenshotName = "\(screenshotUsageCount). Copy - \(screenshotName).jpeg"
                        
                        /// Convert image
                        ///     In the WWDC demos they used jpeg, but .png is a bit higher res I think.
                        guard let bitmap = screenshot.image.representations.first as? NSBitmapImageRep else { fatalError() }
                        let imageData = bitmap.representation(using: .jpeg, properties: [:])
                        
                        /// Store name -> screenshot mapping
                        screenshotNameToScreenshotDataMap[screenshotName] = imageData
                        
                        /// Store the encodable data (everything except the screenshot itself) to the localizedStringData datastructure
                        var didAttachToExistingDatum = false
                        let newScreenshotData = LocalizedStringDatum.Screenshot(name: screenshotName, frame: NSStringFromRect(stringFrame))
                        for (i, var existingDatum) in localizedStringData.enumerated() {
                            if existingDatum.stringKey == stringKey && existingDatum.tableName == stringTable {
                                existingDatum.screenshots.append(newScreenshotData)
                                localizedStringData[i] = existingDatum /// Need to directly assign to index due to Swift value types
                                assert(!didAttachToExistingDatum)
                                didAttachToExistingDatum = true
                            }
                        }
                        if !didAttachToExistingDatum {
                            let newDatum = LocalizedStringDatum(stringKey: stringKey, screenshots: [newScreenshotData], tableName: stringTable, bundlePath: "some/path", bundleID: "some.id")
                            localizedStringData.append(newDatum)
                        }
                    }
                }
            }
        }
        
        /// Create the output directory
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: outputDirectory.path()) {
            do {
                try fileManager.createDirectory(atPath: outputDirectory.path(), withIntermediateDirectories: true, attributes: nil)
                DDLogInfo("Output directory created: \(outputDirectory)")
            } catch {
                XCTFail("Error creating output directory: \((error as NSError).code) : \((error as NSError).domain)") /// This is a weird attempt at getting a non-localized description of the string
                return
            }
        }
        
        /// Write metadata to file
        do {
            let plistFileName = xcode_screenshot_taker_outputted_metadata_filename
            let plistFilePath = (outputDirectory.path() as NSString).appendingPathComponent(plistFileName)
            let plistData = try PropertyListEncoder().encode(localizedStringData)
            try plistData.write(to: URL(fileURLWithPath: plistFilePath))
        } catch {
            XCTFail("Error: Failed to write screenshot metadata to file as json: \(error) \((error as NSError).code) : \((error as NSError).domain)")
        }
        
        /// Write screenshots to file
        for (screenshotName, screenshotData) in screenshotNameToScreenshotDataMap {
            let filePath = (outputDirectory.path() as NSString).appendingPathComponent(screenshotName)
            do {
                try screenshotData.write(to: URL(fileURLWithPath: filePath))
            } catch {
                XCTFail("Error: Failed to screenshot to file: \((error as NSError).code) : \((error as NSError).domain)")
            }
        }
        
        /// Log
        DDLogInfo("Wrote result to output directory \(outputDirectory.path())")
    }
    
    // --------------------------
    // MARK: Take Screenshot
    // --------------------------
    
    func takeLocalizationScreenshot(of element: XCUIElement, name screenshotBaseName: String) -> ScreenshotAndMetadata? {
        var result: ScreenshotAndMetadata? = nil
        do {
            result = try _takeLocalizationScreenshot(of: element, name: screenshotBaseName)
        } catch {
            DDLogInfo("Taking Localization screenshot threw error: \(error)")
        }
        return result
    }
    
    func _takeLocalizationScreenshot(of topLevelElement: XCUIElement, name screenshotBaseName: String) throws -> ScreenshotAndMetadata? {
            

        
        /// Windows and the menuBar are examples of topLevelElements
        ///     If we screenshot them separately we can screenshot all the UI our app is displaying without screenshotting the whole screen.
        
        /// Take screenshot
        let screenshot = topLevelElement.screenshot()
        
        /// Get screenshot frame
        var screenshotFrame = topLevelElement.screenshotFrame()
        
        /// Validate screenshot frame
        let displayBounds: CGRect = CGDisplayBounds(topLevelElement.screen().displayID()); /// Not sure if we should be flipping the coords
        let screenshotFrameOnScreenArea = screenshotFrame.intersection(displayBounds)
        if !screenshotFrame.equalTo(screenshotFrameOnScreenArea)  {
            if ((false)) { /// This check makes sense for menus inside the window, but for the menuBar menus this invevitably fails.
                XCTFail("Error: Screenshot would be cut off by the edge of the screen. Move the window to the center of the screen to prevent this.")
            } else {
                screenshotFrame = screenshotFrameOnScreenArea
            }
        }
        
        /// Get snapshot of ax hierarchy of topLevelElement
        let snapshot: XCUIElementSnapshot?
        do {
            snapshot = try topLevelElement.snapshot()
        } catch {
            snapshot = nil
        }
        
        /// Convert ax hierarchy to tree
        let tree = TreeNode<XCUIElementSnapshot>.tree(withKVCObject: snapshot!, childrenKey: "children")
        
        /// TEST
//        let treeDescription = tree.description()
//        DDLogInfo("The tree: \(treeDescription)")
        
        /// Find localizedStings
        ///     & their metadata
        var framesAndStringsAndKeys: [ScreenshotAndMetadata.Metadata.Frame] = []
        for nodeAsAny in tree.depthFirstEnumerator() {
            
            /// Unpack node
            let node = nodeAsAny as! TreeNode<XCUIElementSnapshot>
            let nodeSnapshot = node.representedObject!
                    
            /// Get the underlying AXUIElement
            ///     (since its strings dont have 512 character limit we see in the nodeSnapshot.dictionaryRepresentation())
            ///     (We made a bunch of other decisions based on the 512 character limit, such as using space-efficient quaternaryEncoding for the secretMessages, now the limit doesn't exist anymore.)
            let axuiElement = getAXUIElementForXCElementSnapshot(nodeSnapshot)!.takeUnretainedValue()
            
            /// Get all attr names
            var attrNames: CFArray?
            AXUIElementCopyAttributeNames(axuiElement, &attrNames)
            
            /// Iterate attr names and get their values + any secret messages
            var stringsAndSecretMessages: [String: [NSString]] = [:]
            for attrName in (attrNames! as NSArray) {
                
                /// Get axAttr value
                var attrValue: CFTypeRef?
                AXUIElementCopyAttributeValue(axuiElement, (attrName as! CFString), &attrValue)
                
                /// Check: Is it a string?
                guard let string = attrValue as? String else {
                    continue
                }
                
                /// Extract any secret messages
                let secretMessages = string.secretMessages() as! [NSString]
                
                /// Skip if no secret messages
                if secretMessages.count == 0 {
                    continue
                }
                
                /// Store secret mesages
                stringsAndSecretMessages[string] = secretMessages
            }
            
            /// Skip
            ///     If this node doesn't have secretMessages
            if stringsAndSecretMessages.count == 0 {
                continue
            }
            
            /// Extract localization key+table from each secret message
            var localizedStrings = [ScreenshotAndMetadata.Metadata.Frame.String_]()
            for (string, secretMessages) in stringsAndSecretMessages {
                var localizationKeys = [ScreenshotAndMetadata.Metadata.Frame.String_.KeyAndTable]()
                for secretMessage in secretMessages {
                    let secretMessage = secretMessage as String
                    let regex = try NSRegularExpression(pattern: localizedStringAnnotationRegexForScreenshottedApp, options: [])
                    let matches = regex.matches(in: secretMessage, options: [.anchored], range: .init(location: 0, length: secretMessage.utf16.count)) /// NSString and related objc classes are based on UTF16 so we should do .utf16 afaik
                    assert(matches.count <= 1)
                    var newLocalizationKey: ScreenshotAndMetadata.Metadata.Frame.String_.KeyAndTable? = nil
                    if let match = matches.first {
                        assert(match.numberOfRanges == 3) /// Full match + 2 capture groups
                        if let keyRange = Range(match.range(at: 1), in: secretMessage),
                           let tableRange = Range(match.range(at: 2), in: secretMessage) {
                            
                            newLocalizationKey = .init(key: String(secretMessage[keyRange]), table: String(secretMessage[tableRange]))
                        }
                    }
                    if let n = newLocalizationKey {
                        localizationKeys.append(n)
                    }
                }
                /// Append to result
                if localizationKeys.count > 0 {
                    localizedStrings.append(ScreenshotAndMetadata.Metadata.Frame.String_(string: string, keys: localizationKeys))
                }
                
            }
            
            /// Guard: No localizedStrings for this node
            guard !localizedStrings.isEmpty else {
                continue
            }
            
            /// Get frame for this node
            var frame = nodeSnapshot.frame
            guard frame != .zero else {
                assert(false)
                continue
            }
            
            /// Guard: hitTest
            ///     This slows down the screenshot-taking noticably, so we're trying to do this as late as possible (after all the other filters)
            ///     What we really want to know is whether the element will be visible in our screenshots, but hit-testing like this is the closest I can find.
            /// Discussion:
            ///     We call `AXUIElementCopyElementAtPosition()` with the hitPoint that the element represented by `node` reports to have, and see if it returns a different element. If so, we assume that the element is
            ///     invisible or covered up by another element.
            ///     This successfully filters out alternate NSMenuItems, collapsed and swapped out stackViews (See Collapse.swift), and perhaps more.
            ///     I'm not sure if there are any false positives. Update: There don't seem to be.
            /// Alternatives:
            ///     The core of this is `AXUIElementCopyElementAtPosition()`, which is a little slow.
            ///     We also tried to use `XCUIHitPointResult.isHittable()` but that still returns true for the hidden/obscured elements we want to filter out.
            ///     We also tried to use the private `-[XCElementSnapshot hitTest]:`, but I think I couldn't figure out how to use it correctly, before we found the `AXUIElementCopyElementAtPosition()` approach.
            var hittedAXUIElement: AXUIElement? = nil
            var idk: AnyObject? = nil
            let hitPoint: XCUIHitPointResult = hitPointForSnapshot_ForSwift(nodeSnapshot, &idk)!
            assert(idk == nil)
            let rawHitPoint: NSPoint = hitPoint.hitPoint()
            AXUIElementCopyElementAtPosition(appAXUIElement!, Float(rawHitPoint.x), Float(rawHitPoint.y), &hittedAXUIElement) /// This is a little slow
            if let hittedAXUIElement = hittedAXUIElement, hittedAXUIElement == axuiElement {
            } else {
                if !alreadyLoggedHitTestFailers.contains(axuiElement) {
                    print("HitTest Failed: Skipping annotation of element: \(nodeSnapshot) || Skipped keys: \(localizedStrings.flatMap { s in s.keys.map { k in k.key } })") /// If hitTest fails, the element is probably invisible or covered by another element.
                    alreadyLoggedHitTestFailers.append(axuiElement) /// We want to log all the elements that are filtered out due to failed hitTests - to check if there are any false positives. (Check if we still end up with correct annotations for those hitTestFailers in the resulting .xcloc file)
                }
                continue
            }
            
            /// Convert from screen coordinate system to screenshot's coordinate system
            ///     This is a few pixels off from what I measured with PixelSnap 2 and the values in Interface Builder, but that should be ok.
            frame = NSRect(x: frame.minX - screenshotFrame.minX,
                           y: frame.minY - screenshotFrame.minY,
                           width: frame.width,
                           height: frame.height)
            
            /// Scale to screenshot resolution
            ///     The screenshot will usually have double resolution compared the internal coordinate system. Retina stuff I think.
            let bsf = NSScreen.screens[0].backingScaleFactor /// Not sure it matters which screen we use.
            frame = NSRect(x: bsf*frame.minX,
                           y: bsf*frame.minY,
                           width: bsf*frame.width,
                           height: bsf*frame.height)
            
            /// Append to result
            framesAndStringsAndKeys.append(ScreenshotAndMetadata.Metadata.Frame(frame: frame, strings: localizedStrings))
        }
        
        /// Filter out invalid frames
        ///     - Hidden (zero-height) menu items show up with height 2 - want to filter them out
        ///     - Update: The hitTest already filters the zero-height elements out, so this is unnecessary now.
        let groupedFrames = Dictionary(grouping: framesAndStringsAndKeys) { frameAndStringAndKey in
            let isValidFrame = frameAndStringAndKey.frame.width >= 5 && frameAndStringAndKey.frame.height >= 5
            return isValidFrame
        }
        let validFramesAndStringsAndKeys = groupedFrames[true]
        
        /// Validate
        let invalidFramesAndStringsAndKeys = groupedFrames[false]
        if (invalidFramesAndStringsAndKeys != nil) {
            assert(topLevelElement.elementType == XCUIElement.ElementType.menuBar ||
                   topLevelElement.elementType == XCUIElement.ElementType.menu)
        }
        
        /// Store result
        if let f = validFramesAndStringsAndKeys {
            let thisResult = ScreenshotAndMetadata(screenshot: screenshot,
                                                   metadata: ScreenshotAndMetadata.Metadata(name: screenshotBaseName,
                                                                                            frames: f))
            return thisResult
        } else {
            return nil
        }
    }
    
    // --------------------------
    // MARK: Helper
    // --------------------------
    
    func hitEscape() {
        app?.typeKey(.escape, modifierFlags: [])
    }
    func hitReturn() {
        app?.typeKey(.return, modifierFlags: [])
    }
    func coolWait() {
        usleep(useconds_t(Double(USEC_PER_SEC) * 0.5))
        app?._waitForQuiescence()
    }
}
