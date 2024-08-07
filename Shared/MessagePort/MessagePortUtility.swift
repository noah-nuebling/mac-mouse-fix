//
// --------------------------------------------------------------------------
// MessagePortUtility.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Foundation
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
    
    @available(macOS 13, *)
    @objc func checkHelperStrangenessReact(payload: NSObject) -> Bool {
        
        /// Handle enabling of strange helper under Ventura
        
        /// Explanation:
        /// The `helperEnabled` message is sent by the helper right after the enableCheckbox is clicked and the helper is subsequently launched
        /// On older macOS versions we can just kill / unregister strange helpers before registering the new helper and go about our day. But under Ventura using SMAppService there's a problem where the strange helper keeps getting registered instead of the right one until we completely uninstall the strange helper and restart the computer.
        /// What we do here is catch that case of the strange helper getting registered. Then we unregister the strange helper and show the user a toast about what to do.
        ///
        /// Notes:
        /// - Checking for strange helper also makes sense pre-Ventura. But strange helper stuff shouldn't  ever be a problem preVentura. The reaction doesn't make any sense pre-Ventura. (Because we show step-by-step instructions that only apply to Ventura)
        /// - The payload needs to have values for keys "bundleVersion" and "mainAppURL", otherwise crash
        /// - Unregistering the helper doesn't work immediately. Takes like 5 seconds. Not sure why. When debugging it doesn't happen. Might be some timeout in the API.
        /// - Not sure if just using `enableHelperAsUserAgent:` is enough. Does this call `launchctl remove`? Does it kill strange helpers that weren't started by launchd? That might be necessary in some situations. Edit: pretty sure it's good enough. It will simply unregister the strange helper that was just registered and sent this message. We don't need to do anything else.
        /// - Logically, the `k-is-disabled-toast` and the `is-strange-helper-alert` belong together since they both give UI feedback about a failure to enable the helper. It would be nice if they were in the same place in code as well
        ///
        /// Update:
        ///     Under the macOS 15 Sequoia Beta, I've seen strange helper popup, but then after restarting the app, it did enable properly! So Apple must have change the way this works.
        ///     TODO: Update the instructions that we show to users under macOS Sequoia.
        ///
        ///     TODO: The link doesn't work properly under Sequioa. (Only the first time you click it) Fix that.
        ///
        
        
        /// Guard running Ventura
        
//        if #available(macOS 13.0, *) {} else { return false }
        
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
            Alerts.showStrangeHelperMessage(withStrangeURL: strangeURL)
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
