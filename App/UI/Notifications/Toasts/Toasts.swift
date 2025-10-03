//
// --------------------------------------------------------------------------
// Toasts.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Foundation

@objc class Toasts: NSObject {
    
    /// Define map
    ///     Maps are split up by tab for localization screenshot automation
    ///     Having 2 string constants to take care of per toast (e.g. "k-enable-timeout-toast" and "enable-timeout-toast") is a bit annoying. At least we have an error message we try to pass in an unknown `k-...` string.
    
    static let simpleToastMap_General = [
        "k-enable-timeout-toast": {
            
            /// Notes:
            /// - We put a period at the end of this UI string. Usually we don't put periods for short UI strings, but it just feels wrong in this case?
            /// - The default duration `kMFToastDurationAutomatic` felt too short in this case. I wonder why that is? I think this toast is one of, if not the shortest toasts - maybe it has to do with that? Maybe it feels like it should display longer, because there's a delay until it shows up so it's harder to get back to? Maybe our tastes for how long the toasts should be changed? Maybe we should adjust the formula for `kMFToastDurationAutomatic`?
            /// - Why are we dispatching `k-is-disabled-toast` to the main thread by not this? (They are called from almost the same place)
            
            var rawMessage = NSLocalizedString("enable-timeout-toast", comment: "Note: The \"&nbsp;\" part inserts a non-breaking-space character, which looks like a normal space, but it prevents linebreaks. We're using this to prevent the last word from being orphaned on the last line. \"&nbsp;\" is also called a \"HTML Character Entity\" if you wanna look it up.") /// [Oct 2025] Actually, we're using `NSLineBreakStrategyPushOut` now, so the manual &nbsp; may not be necessary anymore.
            rawMessage = String(format: rawMessage, Links.link(kMFLinkID_VenturaEnablingGuide) ?? "")
            ToastController.attachNotification(withMessage: NSMutableAttributedString(coolMarkdown: rawMessage, fillOutBase: false)!, forDuration: 10.0)
        },
        "k-is-disabled-toast": {
            var messageRaw = NSLocalizedString("is-disabled-toast", comment: "Note: The \"Login Items Settings\" can be found at \"System Settings > General > Login Items & Extensions\" under macOS 13 Ventura and later. You should probably use the same terminology that is used inside macOS' System Settings here.")
            messageRaw = String(format: messageRaw, Links.link(kMFLinkID_MacOSSettingsLoginItems) ?? "")
            
            let message = NSMutableAttributedString(coolMarkdown: messageRaw, fillOutBase: false)
            DispatchQueue.main.async { /// UI stuff needs to be called from the main thread
                if let window = NSApp.mainWindow, let message = message {
                    ToastController.attachNotification(withMessage: message, forDuration: kMFToastDurationAutomatic)
                }
            }
        },
    ]
    static let simpleToastMap_Buttons = [
        "k-forbidden-capture-toast.1": {
            let messageRaw = NSLocalizedString("forbidden-capture-toast.1", comment: "Note: This message shows when the user tries to assign an action to the primary mouse button (aka left click) inside Mac Mouse Fix.")
            let message = NSAttributedString(coolMarkdown: messageRaw, fillOutBase: false)!;
            ToastController.attachNotification(withMessage: message, forDuration: kMFToastDurationAutomatic)
        },
        "k-forbidden-capture-toast.2": {
            let messageRaw = NSLocalizedString("forbidden-capture-toast.2", comment: "")
            let message = NSAttributedString(coolMarkdown: messageRaw, fillOutBase: false)!;
            ToastController.attachNotification(withMessage: message, forDuration: kMFToastDurationAutomatic)
        },
        "k-already-using-defaults-toast.3": {
            let messageRaw = NSLocalizedString("already-using-defaults-toast.3", comment: "") /// Old note: (Removed because doesn't help localizers I think. We dont' wanna train localizers to ignore comments, so we don't want useless ones.) "Note: This text is displayed in a notification after the user tries to load the default settings for mice with 3 buttons on the Buttons Tab.")
            let message = NSAttributedString(coolMarkdown: messageRaw, fillOutBase: false)!
            DispatchQueue.main.async {
                ToastController.attachNotification(withMessage: message, forDuration: kMFToastDurationAutomatic)
            }
        },
        "k-already-using-defaults-toast.5": {
            let messageRaw = NSLocalizedString("already-using-defaults-toast.5", comment: "")
            let message = NSAttributedString(coolMarkdown: messageRaw, fillOutBase: false)!
            DispatchQueue.main.async {
                ToastController.attachNotification(withMessage: message, forDuration: kMFToastDurationAutomatic)
            }
        },
    ]
    static let simpleToastMap_Scrolling: [String: () -> ()] = [:]
    static let simpleToastMap_About: [String: () -> ()] = [:]
    static let simpleToastMap_LicenseSheet: [String: () -> ()] = [:]
    
    static let simpleToastMap = [simpleToastMap_General, simpleToastMap_Buttons, simpleToastMap_Scrolling, simpleToastMap_About, simpleToastMap_LicenseSheet]
        .reduce([:], { (partialResult: [String: () -> ()], nextElement: [String: () -> ()]) in
            
            return partialResult.merging(nextElement, uniquingKeysWith: { (first, _) in first })
    })
    
    @objc static func showSimpleToast(name: String) {
        
        /// Extract workload
        let workload = simpleToastMap[name]
        
        /// Validate
        if (workload == nil) {
            DDLogError("Can't show toast with unknown name \(name). Known toast names: \(simpleToastMap.keys)")
            assert(false)
        }
        
        /// Do workload
        workload!()
    }
    
    @objc static func showReviveToast(showButtons: Bool, showScroll: Bool) {
        
        /// Validate
        assert(showButtons || showScroll)
        
        /// Get revived-features string
        var revivedFeaturesList: [String] = []
        if showButtons {
            revivedFeaturesList.append(NSLocalizedString(
                "revive-toast.feature-buttons",
                comment: """
                Note: This string will be inserted into the \"revive-toast\" message
                Note 2: These 'feature names' should match the tabs seen in the MMF UI. To find the strings used for the tabs, search for localized strings with a comment containing "Tab Title" e.g. "Buttons Tab Title".
                """
            ))
        }
        if showScroll {
            revivedFeaturesList.append(NSLocalizedString("revive-toast.feature-scrolling", comment: ""))
        }
        let revivedFeatures = UIStrings.naturalLanguageList(fromStringArray: revivedFeaturesList)
        
        /// Build message string
        let messageRaw = String(
            format: NSLocalizedString(
                "revive-toast",
                comment: """
                Note: "%1$@" will be a list of mouse features like "Scrolling" or "Buttons" for which Mac Mouse Fix was enabled. "%2$@" will be the menu bar icon.
                
                Note 2: "&nbsp;" Creates a "non-breaking space" character which prevents the menu bar icon from ending up on a separate line from the text "Menu Bar". 
                
                Note 3: The mentioned feature in the menu bar lets you disable Mac Mouse Fix's effect on your mouse-buttons/scroll-wheel directly from the menubar. This is to help people use apps that are incompatible with Mac Mouse Fix. In your language, it may make sense to use a different translation for 'enable' in this context than in the context of the 'Enable Mac Mouse Fix' switch.
                """
            ),
            revivedFeatures, "%@") /// Note on `&nbsp;`: [Sep 2025] We're already using `NSLineBreakStrategyPushOut` to prevent orphaned words, but it doesn't seem to work for the CoolMenuBarIcon.
        var message = NSAttributedString(coolMarkdown: messageRaw, fillOutBase: false)!
        let symbolString = SFSymbolStrings.string(withSymbolName: "CoolMenuBarIcon", stringFallback: "<Mac Mouse Fix Menu Bar Item>", font: ToastController.defaultFont()) ///NSAttributedString(symbol: "CoolMenuBarIcon", hPadding: 0.0, vOffset: -6, fallback: "<Mac Mouse Fix Menu Bar Item>")
        var args: [NSAttributedString?] = [symbolString]
        message = NSAttributedString(attributedFormat: message, args: &args, argcount: Int32(args.count))
        
        /// Show message
        ToastController.attachNotification(withMessage: message, forDuration: kMFToastDurationAutomatic)
    }
}
