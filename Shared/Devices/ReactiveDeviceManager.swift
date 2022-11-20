//
// --------------------------------------------------------------------------
// DeviceSwift.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
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
    var attachedDevices: SignalProducer<[Device], Never> {
        return attachedDevicesSignal.producer.prefix(value: DeviceManager.attachedDevices())
    }
    
    // MARK: Reactive core
    private var attachedDevicesObserver: Signal<[Device], Never>.Observer
    private var attachedDevicesSignal: Signal<[Device], Never>
    
    // MARK: Init
    private override init() {
        let (o, i) = ReactiveSwift.Signal<[Device], Never>.pipe()
        attachedDevicesObserver = i
        attachedDevicesSignal = o
    }
    
    // MARK: ObjC interface
    @objc func handleAttachedDevicesDidChange() {
        attachedDevicesObserver.send(value: DeviceManager.attachedDevices())
    }
}
