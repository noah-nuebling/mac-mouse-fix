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
    
    @objc static func showSimpleToast(name: String) {
        
        /// Define map
        let map = [
            "k-forbidden-capture-toast.1": {
                let messageRaw = NSLocalizedString("forbidden-capture-toast.1", comment: "First draft: **Primary Mouse Button** can't be used\nPlease try another button")
                let message = NSAttributedString(coolMarkdown: messageRaw)!;
                ToastController.attachNotification(withMessage: message, to: MainAppState.shared.window!, forDuration: kMFToastDurationAutomatic)
            },
            "k-forbidden-capture-toast.2": {
                let messageRaw = NSLocalizedString("forbidden-capture-toast.2", comment: "First draft: **Secondary Mouse Button** can't be used\nPlease try another button")
                let message = NSAttributedString(coolMarkdown: messageRaw)!;
                ToastController.attachNotification(withMessage: message, to: MainAppState.shared.window!, forDuration: kMFToastDurationAutomatic)
            },
            "k-already-using-defaults-toast.3": {
                let messageRaw = NSLocalizedString("already-using-defaults-toast.3", comment: "First draft: You're __already using__ the default setting for mice with __3 buttons__")
                let message = NSAttributedString(coolMarkdown: messageRaw)!
                DispatchQueue.main.async {
                    ToastController.attachNotification(withMessage: message, to: MainAppState.shared.window!, forDuration: kMFToastDurationAutomatic)
                }
            }, 
            "k-already-using-defaults-toast.5": {
                let messageRaw = NSLocalizedString("already-using-defaults-toast.5", comment: "First draft: You're __already using__ the default setting for mice with __5 buttons__")
                let message = NSAttributedString(coolMarkdown: messageRaw)!
                DispatchQueue.main.async {
                    ToastController.attachNotification(withMessage: message, to: MainAppState.shared.window!, forDuration: kMFToastDurationAutomatic)
                }
            },
            "k-enable-timeout-toast": {
                
                /// Notes:
                /// - We put a period at the end of this UI string. Usually we don't put periods for short UI strings, but it just feels wrong in this case?
                /// - The default duration `kMFToastDurationAutomatic` felt too short in this case. I wonder why that is? I think this toast is one of, if not the shortest toasts - maybe it has to do with that? Maybe it feels like it should display longer, because there's a delay until it shows up so it's harder to get back to? Maybe our tastes for how long the toasts should be changed? Maybe we should adjust the formula for `kMFToastDurationAutomatic`?
                /// - Is there a reason we use NSApp.mainWindow and if let here? We wrote this much later than the other toasts so maybe I just changed my style?
                /// - Why are we dispatching `k-is-disabled-toast` to the main thread by not this? (They are called from almost the same place)
                
                if let window = NSApp.mainWindow {
                    let rawMessage = NSLocalizedString("enable-timeout-toast", comment: "First draft: If you have **problems enabling** the app, click&nbsp;[here](https://github.com/noah-nuebling/mac-mouse-fix/discussions/861).")
                    ToastController.attachNotification(withMessage: NSMutableAttributedString(coolMarkdown: rawMessage)!, to: window, forDuration: 10.0)
                    
                }
            },
            "k-is-disabled-toast": {
                let messageRaw = NSLocalizedString("is-disabled-toast", comment: "First draft: Mac Mouse Fix was **disabled** in System Settings\n\nTo enable Mac Mouse Fix:\n\n1. Go to [Login Items Settings](x-apple.systempreferences:com.apple.LoginItems-Settings.extension)\n2. Switch on \'Mac Mouse Fix.app\'")
                
                let message = NSMutableAttributedString(coolMarkdown: messageRaw)
                DispatchQueue.main.async { /// UI stuff needs to be called from the main thread
                    if let window = NSApp.mainWindow, let message = message {
                        ToastController.attachNotification(withMessage: message, to: window, forDuration: kMFToastDurationAutomatic)
                    }
                }
            },
            
        ]
        
        /// Extract workload
        let workload = map[name]
        
        /// Validate
        if (workload == nil) {
            DDLogError("Can't show toast with unknown name \(name). Known toast names: \(map.keys)")
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
            revivedFeaturesList.append(NSLocalizedString("revive-toast.feature-buttons", comment: "First draft: __Buttons__"))
        }
        if showScroll {
            revivedFeaturesList.append(NSLocalizedString("revive-toast.feature-scrolling", comment: "First draft: __Scrolling__"))
        }
        let revivedFeatures = UIStrings.naturalLanguageList(fromStringArray: revivedFeaturesList)
        
        /// Build message string
        let messageRaw = String(format: NSLocalizedString("revive-toast", comment: "First draft: __Enabled__ Mac Mouse Fix for %1@\nIt had been disabled from the Menu Bar %2@ || Note: %1@ will be replaced by the list of enabled features, %2@ will be replaced by the menubar icon"), revivedFeatures, "%@")
        var message = NSAttributedString(coolMarkdown: messageRaw)!
        let symbolString = Symbols.string(withSymbolName: "CoolMenuBarIcon", stringFallback: "<Mac Mouse Fix Menu Bar Item>", font: ToastController.defaultFont()) ///NSAttributedString(symbol: "CoolMenuBarIcon", hPadding: 0.0, vOffset: -6, fallback: "<Mac Mouse Fix Menu Bar Item>")
        message = NSAttributedString(attributedFormat: message, args: [symbolString])
        
        /// Show message
        ToastController.attachNotification(withMessage: message, to: MainAppState.shared.window!, forDuration: kMFToastDurationAutomatic)
    }
}
