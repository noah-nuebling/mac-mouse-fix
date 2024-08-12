//
// --------------------------------------------------------------------------
// NotificationTests.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Foundation

@objc class ToastAndSheetTests: NSObject {
    
    /// This file opens up toast, sheets, and perhaps at some pointer other places in the UI, which are not otherwise easily reachable for the localizationScreenshot testRunner.
    ///     The testRunner can send a message to the mainApp process, and then we open up the toast/sheet/etc in response.
    
    static var testIndexes = [
        "general": 0,
        "buttons": 0,
        "scrolling": 0,
        "about": 0,
        "licensesheet": 0,
    ]
    
    static let testLists: [String: Array<() -> ()>] = [
     
        "general": Toasts.simpleToastMap_General.values + [
            { AuthorizeAccessibilityView.add() }
        ],
        "buttons": Toasts.simpleToastMap_Buttons.values + [
            
            { Toasts.showReviveToast(showButtons: true, showScroll: false) },
            { CaptureToasts.showButtonCaptureToastWith(before: [], after: [3]) },
            { CaptureToasts.showButtonCaptureToastWith(before: [5], after: []) },
            { () -> () in MainAppState.shared.buttonTabController?.showRestoreDefaultPopover(deviceName: "Tecknet 2.4G Wireless", nOfButtons: 3, usedButtons: Set([4, 5])); return },
            { () -> () in MainAppState.shared.buttonTabController?.showRestoreDefaultPopover(deviceName: "Dierya Falcon M1SE Honeycomb", nOfButtons: 5, usedButtons: Set([3])); return },
        ],
        "scrolling": Toasts.simpleToastMap_Scrolling.values + [
            
            { Toasts.showReviveToast(showButtons: false, showScroll: true) },
            { CaptureToasts.showScrollWheelCaptureToast(false) },
            { CaptureToasts.showScrollWheelCaptureToast(true) },
        ],
        "about": Toasts.simpleToastMap_About.values + [
            
        ],
        "licensesheet": Toasts.simpleToastMap_LicenseSheet.values + [
            
            { LicenseToasts.showDeactivationToast() },
            /*{  LicenseToasts.showErrorToast(<#T##NSError?#>, <#T##String#>) Not sure how to create a mock error   }, */
            { LicenseToasts.showSuccessToast(kMFLicenseReasonValidLicense, true) },
            { LicenseToasts.showSuccessToast(kMFLicenseReasonValidLicense, false) }
        ],
    ]
    
    @objc class func showNextTest(section: String) -> Bool {
        
        /// Extract
        let testList = testLists[section]!
        var testIndex = testIndexes[section]!
        
        /// Execute test
        if testIndex < testList.count {
            let test = testList[testIndex]
            test()
        }
        
        /// Increment
        testIndex += 1
        
        /// Store new index
        testIndexes[section]! = testIndex
        
        /// Determine return
        let moreToastsToGo = testIndex <= testList.count - 1
        
        /// Return
        return moreToastsToGo
    }
    
    @objc class func didShowAllToastsAndSheets() -> Bool {
        
        var result = true
        
        for (section, tests) in testLists {
            
            let allTestsForThisSectionRan = testIndexes[section] == tests.count;
            if !allTestsForThisSectionRan {
                result = false
                break
            }
        }
        
        return result
    }
}
