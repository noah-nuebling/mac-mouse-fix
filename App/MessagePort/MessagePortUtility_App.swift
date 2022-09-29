//
// --------------------------------------------------------------------------
// MessagePortUtility_App.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Foundation

@objc class MessagePortUtility_App: NSObject {
    
    static func getActiveDeviceInfo() -> (deviceName: NSString, deviceManufacturer: NSString, deviceButtons: Int, bestPresetMatch: Int)? {
        
        /// This functnion doesn't really belong into `ButtonTabController`
        
        var result = (deviceName: ("" as NSString), deviceManufacturer: ("" as NSString), deviceButtons: (-1 as Int), bestPresetMatch: (-1 as Int))
        
        if let info = SharedMessagePort.sendMessage("getActiveDeviceInfo", withPayload: nil, expectingReply: true) as! NSDictionary? {
            
            result.deviceName = info["name"] as! NSString
            result.deviceManufacturer = info["manufacturer"] as! NSString
            result.deviceButtons = (info["nOfButtons"] as! NSNumber).intValue
            
            if result.deviceButtons == 0 { /// If there is no active device, use 5 button preset as default
                result.bestPresetMatch = 5
            } else if result.deviceButtons == 3 {
                result.bestPresetMatch = 3
            } else {
                result.bestPresetMatch = 5
            }
            
            return result
            
        } else {
            return nil
        }
    }

}
