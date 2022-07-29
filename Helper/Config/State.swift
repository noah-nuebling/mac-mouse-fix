//
// --------------------------------------------------------------------------
// State.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Foundation

@objc class State: NSObject {
    
    @objc var activeDevice: Device? = nil
    
//    @objc func updateActiveDeviceWithEvent(event: CGEvent) {
//        activeDevice = CGEventGetSendingDevice(event);
//    }
}
