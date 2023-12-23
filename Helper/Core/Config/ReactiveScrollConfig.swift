//
// --------------------------------------------------------------------------
// ReactiveScrollConfig.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Foundation
import ReactiveSwift

class ReactiveScrollConfig {
    
    /// Singleton
    static let shared = ReactiveScrollConfig()
    
    /// Main Interface
    
    var scrollConfig: SignalProducer<ScrollConfig, Never> {
        return signal.producer.prefix(value: ScrollConfig.shared)
    }
    
    /// Reactive Core + Init
    let signal: Signal<ScrollConfig, Never>
    let observer: Signal<ScrollConfig, Never>.Observer
    
    init() {
        (signal, observer) = Signal<ScrollConfig, Never>.pipe()
    }
    
    /// Updater
    func handleScrollConfigChanged(newValue: ScrollConfig) {
//        observer.send(value: newValue)
        SwitchMaster.shared.scrollConfigChanged(scrollConfig: newValue)
    }
}
