//
// --------------------------------------------------------------------------
// MessagePortUtility.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Foundation
import CocoaLumberjackSwift
import ReactiveSwift

@objc class MessagePortUtility: NSObject {
    
    @objc static let shared = MessagePortUtility()
    
#if IS_MAIN_APP
    
    override init() {
        
        let (output, input) = Signal<String, Never>.pipe()
        strangeHelperDetected = output
        strangeHelperDetectedInput = input
    
        super.init()
    }
    
    let strangeHelperDetected: Signal<String, Never>
    private let strangeHelperDetectedInput: Signal<String, Never>.Observer
    
    @available(macOS, introduced: 13.0, deprecated: 15.0, message: "Strange-helper-checks should only be necessary on macOS 13 and 14.")
    @objc func checkHelperStrangenessReact(payload: NSObject) -> Bool {
        
        /// Handle enabling of strange helper under Ventura
        
        /// Explanation:
        /// The `helperEnabled` message is sent by the helper right after the enableCheckbox is clicked and the helper is subsequently launched
        /// On older macOS versions we can just kill / unregister strange helpers before registering the new helper and go about our day. But under Ventura using SMAppService there's a problem where the strange helper keeps getting registered instead of the right one until we completely uninstall the strange helper and restart the computer.
        /// What we do here is catch that case of the strange helper getting registered. Then we unregister the strange helper and show the user a toast about what to do.
        ///
        /// Notes:
        /// - Checking for strange helper also makes sense pre-Ventura. But strange helper stuff shouldn't  ever be a problem preVentura. The reaction doesn't make any sense pre-Ventura. (Because we show step-by-step instructions that only apply to Ventura)
        /// - Unregistering the helper doesn't work immediately. Takes like 5 seconds. Not sure why. When debugging it doesn't happen. Might be some timeout in the API.
        /// - Not sure if just using `enableHelperAsUserAgent:` is enough. Does this call `launchctl remove`? Does it kill strange helpers that weren't started by launchd? That might be necessary in some situations. Edit: pretty sure it's good enough. It will simply unregister the strange helper that was just registered and sent this message. We don't need to do anything else.
        /// - Logically, the `is-disabled-toast` and the `is-strange-helper-toast` belong together since they both give UI feedback about a failure to enable the helper. It would be nice if they were in the same place in code as well
        
        
        /// Update: [Jul 13 2025] Disable if not running macOS 13 Ventura or 14 Sonoma
        ///     On other versions, macOS should automatically switch to launching the right helper version, and no uninstall-and-restart should be required. (Giving users instructions to uninstall-and-restart was the main purpose of this.)
        ///     Perhaps there's still some utility in detecting strange helpers to improve edge-cases, but I'm not sure of that, so I'll disable this code now for other macOS versions [Jul 2025]
        ///     Also see `enable-timeout-toast` discussion in `GeneralTabController.swift` where the alert we're creating here is referred to as `is-strange-helper-alert` [Jul 2025]
        ///         Uncertainty: I'm pretty sure that the issue that the `is-strange-helper-alert` was addressing went away at the same time as the issue that the `enable-timeout-toast` was addressing – in macOS 15 Sequoia. But not 100% sure.
        /// Update: [Jul 17 2025] This issue (https://github.com/noah-nuebling/mac-mouse-fix/issues/1464) in 3.0.5 might have been prevented by disabling strange helpers! Perhaps we should re-enable that feature without calling `AlertCreator.showStrangeHelperMessage()`
        
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        if osVersion < 13 || 14 < osVersion {
            assert(false);
            return false;
        }
        
        /// Determine strangeness
        
        var isStrange = true
        
        let dict = payload as? NSDictionary
        if let dict = dict,
           let helperVersion = (dict["bundleVersion"] as? NSNumber)?.intValue,
           (dict["mainAppURL"] as? NSURL) != nil {
            
            let mainAppVersion = Locator.bundleVersion();
            
            if mainAppVersion == helperVersion {
                isStrange = false;
            }
        }
        
        if isStrange {
            
            /// Log
            DDLogError("Received enabled message from strange helper. Disabling it");
            
            /// Disable helper
            HelperServices.enableHelperAsUserAgent(false)
            
            /// Find strangeHelper URL
            
            var strangeURL = (dict?["mainAppURL"] as? NSURL)?.absoluteString ?? ""
            
            if strangeURL == "" {
                /// Try alternative method for finding URL
                if #available(macOS 12.0, *) {
                    for appURL in NSWorkspace.shared.urlsForApplications(withBundleIdentifier: kMFBundleIDApp) {
                        if appURL != Locator.mainAppBundle().bundleURL {
                            strangeURL = appURL.absoluteString
                        }
                    }
                } else {
                    let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: kMFBundleIDApp)
                    if let appURL = appURL, appURL != Locator.mainAppBundle().bundleURL {
                        strangeURL = appURL.absoluteString
                    }
                }
            }
            
            /// Notify other parts of app
            strangeHelperDetectedInput.send(value: strangeURL)
            
            /// Notify user
            AlertCreator.showStrangeHelperMessage(withStrangeURL: strangeURL)
        }
        
        /// Return
        return isStrange;
    }
    
    func getActiveDeviceInfo() -> (name: NSString, nOfButtons: Int, bestPresetMatch: Int)? {
        
        /// The syntax for using this is kind of complicated. Copy-paste this:
        ///     `let (deviceName, deviceManufacturer, deviceButtons, bestPresetMatch) = MessagePortUtility_App.getActiveDeviceInfo() ?? (nil, nil, nil, nil)`
        
        /// This functnion doesn't really belong into `ButtonTabController`
        
        var result = (name: ("" as NSString), nOfButtons: (-1 as Int), bestPresetMatch: (-1 as Int))
        
        if let info = MFMessagePort.sendMessage("getActiveDeviceInfo", withPayload: nil, waitForReply: true) as! NSDictionary? {
            
            let deviceManufacturer = info["manufacturer"] as! NSString
            var deviceName = info["name"] as! NSString
            
            if deviceName.hasPrefix(deviceManufacturer as String) {
                deviceName = deviceName.substring(from: deviceManufacturer.length) as NSString
            }
            
            result.name = (String(format: "%@ %@", deviceManufacturer, deviceName) as NSString).stringByTrimmingWhiteSpace()
            
            result.nOfButtons = (info["nOfButtons"] as! NSNumber).intValue
            
            if result.nOfButtons == 0 { /// If there is no active device, use 5 button preset as default
                result.bestPresetMatch = 5
            } else if result.nOfButtons == 3 {
                result.bestPresetMatch = 3
            } else {
                result.bestPresetMatch = 5
            }
            
            return result
            
        } else {
            return nil
        }
    }
    
#endif
    
}
