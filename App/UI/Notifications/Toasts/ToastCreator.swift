//
// --------------------------------------------------------------------------
// ToastNotificationCreator.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Foundation

@objc class ToastCreator: NSObject {
    
    @objc static func showReviveToast(showButtons: Bool, showScroll: Bool) {
        
        /// Validate
        assert(showButtons || showScroll)
        
        /// Get revived-features string
        var revivedFeaturesList: [String] = []
        if showButtons {
            revivedFeaturesList.append(NSLocalizedString("revive-toast.feature-buttons", comment: "First draft: __Buttons__"))
        }
        if showScroll {
            revivedFeaturesList.append(NSLocalizedString("revive-toast.feature-scrolling", comment: "First draft: __Scrolling__"))
        }
        let revivedFeatures = UIStrings.naturalLanguageList(fromStringArray: revivedFeaturesList)
        
        /// Build message string
        let messageRaw = String(format: NSLocalizedString("revive-toast", comment: "First draft: __Enabled__ Mac Mouse Fix for %1@\nIt had been disabled from the Menu Bar %2@ || Note: %1@ will be replaced by the list of enabled features, %2@ will be replaced by the menubar icon"), revivedFeatures, "%@")
        var message = NSAttributedString(coolMarkdown: messageRaw)!
        let symbolString = Symbols.string(withSymbolName: "CoolMenuBarIcon", stringFallback: "<Mac Mouse Fix Menu Bar Item>", font: ToastNotificationController.defaultFont()) ///NSAttributedString(symbol: "CoolMenuBarIcon", hPadding: 0.0, vOffset: -6, fallback: "<Mac Mouse Fix Menu Bar Item>")
        message = NSAttributedString(attributedFormat: message, args: [symbolString])
        
        /// Show message
        ToastNotificationController.attachNotification(withMessage: message, to: MainAppState.shared.window!, forDuration: -1, alignment: kToastNotificationAlignmentTopMiddle)
    }
}
