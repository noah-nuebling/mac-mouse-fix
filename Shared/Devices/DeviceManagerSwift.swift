//
// --------------------------------------------------------------------------
// DeviceManagerSwift.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Foundation

extension DeviceManager {
    
    static var attachedDevices: NSArray {
        return __SWIFT_UNBRIDGED_attachedDevices() as! NSArray
    }
}
