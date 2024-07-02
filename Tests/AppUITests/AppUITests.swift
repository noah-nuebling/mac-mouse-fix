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
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    ///
    /// Performance
    ///
    
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }

    /// Screenshots
    
    var app: XCUIApplication? = nil
    func testTakeLocalizationScreenshots() throws {
        
        /// Launch the app
        app = XCUIApplication()
        app!.launch()

        /// Capture MainTab
        takeScreenshot(of: "MainTab")
        
        /// Buttons Tab
        print(app?.toolbarButtons)
        
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    ///
    /// Helper
    ///
    
    func takeScreenshot(of identifier: String) {
        
        let screenshot = app!.windows.firstMatch.screenshot()
        let screenshotAttachment = XCTAttachment(screenshot: screenshot)
        screenshotAttachment.name = identifier
        screenshotAttachment.lifetime = .keepAlways
        add(screenshotAttachment)
    }
    
}
