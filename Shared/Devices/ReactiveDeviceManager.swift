//
// --------------------------------------------------------------------------
// DeviceSwift.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

import Foundation
import ReactiveCocoa
import ReactiveSwift

//extension DeviceManager: ReactiveExtensionsProvider { }

@objc class ReactiveDeviceManager: NSObject {
    
    // MARK: Singleton
    @objc static var shared = ReactiveDeviceManager()
    
    // MARK: Main interface
    var attachedDevices: SignalProducer<NSArray, Never> {
        return attachedDevicesSignal.producer.prefix(value: DeviceManager.attachedDevices) // .skipRepeats() // SkipRepeats doesn't work on reference types, it just kills the signal!
    }
    
    // MARK: Reactive core
    private var attachedDevicesObserver: Signal<NSArray, Never>.Observer
    private var attachedDevicesSignal: Signal<NSArray, Never>
    
    // MARK: Init
    private override init() {
        let (o, i) = ReactiveSwift.Signal<NSArray, Never>.pipe()
        attachedDevicesObserver = i
        attachedDevicesSignal = o
    }
    
    // MARK: ObjC interface
    @objc func handleAttachedDevicesDidChange() {
        attachedDevicesObserver.send(value: DeviceManager.attachedDevices)
    }
}
