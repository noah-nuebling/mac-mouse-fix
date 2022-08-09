//
// --------------------------------------------------------------------------
// ReactiveConfig.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Foundation
import ReactiveSwift
import ReactiveCocoa

// MARK: Signal for when config changes

@objc class ReactiveConfig: NSObject, BindingSource {
    
    /// Singleton
    @objc static let shared = ReactiveConfig()
    
    /// Create producer
    ///  + Binding Source protocol implementation
    
    typealias Value = NSDictionary
    typealias Error = Never
    var producer: ReactiveSwift.SignalProducer<NSDictionary, Never> {
        let currentConfig = ConfigInterface_App.config
        return signal.producer.prefix(value: currentConfig)
    }
    
    /// Create signal
    ///     `input.send()` should be called by `ConfigInterface_App`, whenever the config changes. Then you can observe changes to the config using `signal`.
    
    let input: Signal<NSDictionary, Never>.Observer
    let signal: Signal<NSDictionary, Never>
    
    override init() {
        let (s, o) = Signal<NSDictionary, Never>.pipe()
        input = o
        signal = s
    }
    
    /// Objc interface
    
    @objc func react(newConfig: NSDictionary) {
        self.input.send(value: newConfig)
    }
    
}

// MARK: Config values
/// Reactive interface for interacting with certain values in the config dict

class ConfigValue<T: NSObject>: NSObject, BindingTargetProvider, BindingSource {
    
    /// Reactive
    
    typealias Value = T
    var bindingTarget: ReactiveSwift.BindingTarget<T> {
        return BindingTarget(lifetime: self.reactive.lifetime) { self.set($0) }
    }
    var producer: ReactiveSwift.SignalProducer<T, Never>
    
    /// Storage
    var keyPath: String
    
    /// init
    required init(configPath: String) {
        
        /// Set dummy values so that you can super.init()
        keyPath = ""
        producer = SignalProducer<T, Never>.init(value: T())
        
        /// Init super
        super.init()
        
        /// Do real init
        
        keyPath = configPath
        
        /// Create signalProducer
        ///     Will send a signal whenever the value at `keyPath` in the config changes
        let p1 = ReactiveConfig.shared.producer.map({ (newConfig: NSDictionary) -> T? in
            newConfig.object(forCoolKeyPath: configPath) as? T /// Notice that we're using coolKeyPaths
        })
        producer = p1.skipNil().skipRepeats()
        

    }
    /// Core functions
    
    func set(_ value: T) {
        setConfig(keyPath, value)
        commitConfig()
    }
    func get() -> T? {
        return config(keyPath) as? T
    }

}
