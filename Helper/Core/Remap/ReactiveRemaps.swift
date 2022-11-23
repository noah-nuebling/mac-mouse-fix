//
// --------------------------------------------------------------------------
// ReactiveRemaps.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

import Foundation
import ReactiveSwift

@objc class ReactiveRemaps: NSObject {
    
    /// Singleton
    @objc static let shared = ReactiveRemaps()
    
    /// Reactive core
    private var signal: Signal<NSDictionary, Never>
    private var observer: Signal<NSDictionary, Never>.Observer
    
    /// Init
    override init() {
        let (o, i) = Signal<NSDictionary, Never>.pipe()
        signal = o
        observer = i
    }
    
    /// Main interface
    var remaps: SignalProducer<NSDictionary, Never> {
        return signal.producer.prefix(value: Remap.remaps) // .skipRepeats()
    }
    
    /// ObjC interface
    @objc func handleRemapsDidChange() {
        observer.send(value: Remap.remaps)
    }
}

