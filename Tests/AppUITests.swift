//
// --------------------------------------------------------------------------
// AppUITests.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import XCTest

final class AppUITests: XCTestCase {
    
    ///
    /// Lifecycle
    ///
    
    override func setUpWithError() throws {
        /// Put setup code here. This method is called before the invocation of each test method in the class.
        
        /// In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        /// Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    /// 
    /// Screenshots
    ///
    
    
    struct StringAndKeys: Encodable {
        let string: String
        let keys: [String]
    }
    struct FrameAndStringsAndKeys: Encodable {
        let frame: NSRect
        let strings: [StringAndKeys]
    }
    struct ScreenshotMetadata : Encodable {
        let screenshotName: String
        let frames: [FrameAndStringsAndKeys]
    }
    struct ScreenshotAndMetadata {
        let screenshot: XCUIScreenshot
        let metadata: ScreenshotMetadata
    }
    
    var app: XCUIApplication? = nil
    var screenshotsAndMetadata = [ScreenshotAndMetadata]()
    
    func testTakeLocalizationScreenshots() throws {
        
        /// Get output folder
        /// Note:
        ///     Before calling xcodebuild, set the screnshot output dir using `TEST_RUNNER_MF_LOCALIZATION_SCREENSHOT_OUTPUT_DIR=<outputdir>`
        let outputDirectory = ProcessInfo.processInfo.environment["MF_LOCALIZATION_SCREENSHOT_OUTPUT_DIR"]
        
        /// Prepare app
        ///     Note: The "Arguments Passed On Launch" in the .xctestplan are passed to the test runner, not to the tested app.
        app = XCUIApplication()
        app?.launchArguments.append("-MF_ANNOTATE_LOCALIZED_STRINGS")
        
        /// Launch the app
        app!.launch()
        
        /// Find enable toggle
        let switcherino = app?.switches["enableToggle"]
        let switcherinoExists = switcherino?.waitForExistence(timeout: 10) ?? false
        XCTAssertTrue(switcherinoExists)
        
        /// Enable MMF (if necessary)
        let isEnabledPredicate = NSPredicate.init(format: "value == 1")
        if (isEnabledPredicate.evaluate(with: switcherino) == false) {
            switcherino?.click()
            let switchIsEnabled = expectation(for: isEnabledPredicate, evaluatedWith: switcherino)
            XCTWaiter().wait(for: [switchIsEnabled], timeout: 10.0)
        }
        
        /// Capture MainTab
        takeLocalizationScreenshot(withName: "MainTab")
        
        /// Create the output directory if it doesn't exist
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: outputDirectory!) {
            do {
                try fileManager.createDirectory(atPath: outputDirectory!, withIntermediateDirectories: true, attributes: nil)
                print("Output directory created: \(outputDirectory!)")
            } catch {
                print("Error creating output directory: \(error.localizedDescription)")
                return
            }
        }
        
        /// Write to file
        do {
            let jsonFileName = "Metadata.json"
            let jsonFilePath = (outputDirectory! as NSString).appendingPathComponent(jsonFileName)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData: Data = try encoder.encode(screenshotsAndMetadata.map({ $0.metadata }))
            try jsonData.write(to: URL(fileURLWithPath: jsonFilePath))
        } catch {
            print("Error: Failed to write screenshot metadata to file as json: \(error)")
        }
        
        /// Write screenshots to file
        for screenshotAndMetadata in screenshotsAndMetadata {
            let fileName = "\(screenshotAndMetadata.metadata.screenshotName).png"
            let filePath = (outputDirectory! as NSString).appendingPathComponent(fileName)
            do {
                try screenshotAndMetadata.screenshot.pngRepresentation.write(to: URL(fileURLWithPath: filePath))
            } catch {
                print("Error: Failed to screenshot to file: \(error)")
            }
        }
    }
    

    func takeLocalizationScreenshot(withName screenshotBaseName: String) {
        
        XCTContext.runActivity(named: "print app dict") { activity in
            
            for (i, topLevelElement) in app!.children(matching: .any).allElementsBoundByAccessibilityElement.enumerated() {
             
                /// Windows and the menuBar are examples of topLevelElements
                ///     If we screenshot them separately we can screenshot all the UI our app is displaying without screenshotting the whole screen.
                
                /// Take screenshot
                let screenshot = topLevelElement.screenshot()
//                let screenshotAttachment = XCTAttachment(screenshot: screenshot, quality: .original) /// .medium turns this into a .jpeg which matches autogenerated loc screenshots on iOS project.
//                screenshotAttachment.name = "Localization screenshot" /// Autogenerated loc screenshots on my iOS projects have this name it seems.
//                screenshotAttachment.lifetime = .keepAlways
//                add(screenshotAttachment)
                
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
                let treeDescription = tree.description()
                print("The tree: \(treeDescription)")
                
                
                /// Find localizedStings
                ///     & their metadata
                var framesAndStringsAndKeys: [FrameAndStringsAndKeys] = []
                for nodeAsAny in tree.depthFirstEnumerator() {
                    
                    /// Unpack node
                    let node = nodeAsAny as! TreeNode<XCUIElementSnapshot>
                    let nodeSnapshot = node.representedObject!
                    
                    /// Get secret messages
                    var localizedStrings = [StringAndKeys]()
                    for value in nodeSnapshot.dictionaryRepresentation.values {
                        
                        /// Check: Is it a string?
                        guard let string = value as? String else {
                            continue
                        }
                        /// Extract secret messages
                        let secretMessages = string.secretMessages() as! [NSString]
                        
                        /// Extract localization keys from secret messages
                        var localizationKeys = [String]()
                        for secretMessage in secretMessages {
                            let localizationKeyPrefix = "mf-secret-localization-key:"
                            guard secretMessage.hasPrefix(localizationKeyPrefix) else {
                                assert(false)
                                continue
                            }
                            let localizationKey = String(String(secretMessage).dropFirst(localizationKeyPrefix.count))
                            assert(localizationKey.count > 0)
                            localizationKeys.append(localizationKey)
                        }
             
                        /// Append to result
                        if localizationKeys.count > 0 {
                            localizedStrings.append(StringAndKeys(string: string, keys: localizationKeys))
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
                    
                    /// Transform frame to the screenshotted element's coordinate system
                    ///     This is a few pixels off from what I measured with PixelSnap 2 and the values in Interface Builder, 
                    ///         but that should be ok. 
                    frame = NSRect(x: frame.minX - topLevelElement.frame.minX, y: frame.minY - topLevelElement.frame.minY, width: frame.width, height: frame.height)
                    
                    /// Append to result
                    framesAndStringsAndKeys.append(FrameAndStringsAndKeys(frame: frame, strings: localizedStrings))
                }
                                        
                /// TEST
                let logString = framesAndStringsAndKeys.map({ element in String(describing: element) }).joined(separator: "\n")
                print("\(logString)")
                
                /// Filter out invalid frames
                let isValidFrame = { (frame: NSRect) in frame.width != 0 && frame.height != 0 }
                let groupedFrames = Dictionary(grouping: framesAndStringsAndKeys) { frameAndStringAndKey in
                    isValidFrame(frameAndStringAndKey.frame)
                }
                let validFramesAndStringsAndKeys = groupedFrames[true]
                let invalidFramesAndStringsAndKeys = groupedFrames[false]
                
                /// Store result
                if let f = validFramesAndStringsAndKeys {
                    let screenshotName = String(format: "%@.%d", screenshotBaseName, i)
                    screenshotsAndMetadata.append(ScreenshotAndMetadata(screenshot: screenshot,
                                                                        metadata: ScreenshotMetadata(screenshotName: screenshotName,
                                                                                                     frames: f)))
                }
                
            }
        }
        
//        for text in app.staticTexts.allElementsBoundByAccessibilityElement {
//        
//            
//            let axTitle = text.title
//            let axValue = text.value
//            let axPlaceholder = text.placeholderValue
//            let tooltip = ""
//            var axHelp = [String]()
//            for helpTag in text.helpTags.allElementsBoundByAccessibilityElement {
//                axHelp.append(helpTag.debugDescription)
//            }
//            let axLabel = text.label
//            
//            let axDescription = text.description
//            let axValueDescription = ""
//            let axRoleDescription = ""
//            let axHorizontalUnitDescription = ""
//            let axVerticalUnitDescription = ""
//            let axMarkerTypeDescription = ""
//            let axUnitDescription = ""
//            
//            var dict: Dictionary<XCUIElement.AttributeName, Any> = [:]
//            do {
//                dict = try text.snapshot().dictionaryRepresentation
//            } catch {
//                NSLog("Error getting snapshot dict: \(error)")
//            }
//            
//            XCTContext.runActivity(named: "printUIString") { activity in
//                
//                let printString = "The label is \([axTitle, axValue, axPlaceholder, tooltip, axHelp, axLabel, axDescription, axValueDescription, axRoleDescription, axHorizontalUnitDescription, axVerticalUnitDescription, axMarkerTypeDescription, axUnitDescription])\ndict:\n\(dict)"
//        
//                print(printString)
//                
//            }
//        }

    }
    
}
