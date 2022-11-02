//
// --------------------------------------------------------------------------
// MessagePortUtility.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Foundation

@objc class MessagePortUtility: NSObject {
    
#if IS_MAIN_APP
    
    static func getActiveDeviceInfo() -> (name: NSString, nOfButtons: Int, bestPresetMatch: Int)? {
        
        /// The syntax for using this is kind of complicated. Copy-paste this:
        ///     `let (deviceName, deviceManufacturer, deviceButtons, bestPresetMatch) = MessagePortUtility_App.getActiveDeviceInfo() ?? (nil, nil, nil, nil)`
        
        /// This functnion doesn't really belong into `ButtonTabController`
        
        var result = (name: ("" as NSString), nOfButtons: (-1 as Int), bestPresetMatch: (-1 as Int))
        
        if let info = MessagePort.sendMessage("getActiveDeviceInfo", withPayload: nil, expectingReply: true) as! NSDictionary? {
            
            let deviceName = info["name"] as! NSString
            let deviceManufacturer = info["manufacturer"] as! NSString
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
