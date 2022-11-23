//
// --------------------------------------------------------------------------
// ReactiveModifiers.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

import Foundation
import ReactiveSwift

@objc class ReactiveModifiers: NSObject {
    
    /// Singleton
    @objc static let shared = ReactiveModifiers()
    
    /// Reactive Core
    private var signal: Signal<NSDictionary, Never>
    private var observer: Signal<NSDictionary, Never>.Observer
    
    /// Init
    override init() {
        (signal, observer) = Signal<NSDictionary, Never>.pipe()
    }
/// Main interface
    var modifiers: SignalProducer<NSDictionary, Never> {
        return signal.producer.prefix(value: Modifiers.modifiers(with: nil)) // .skipRepeats()
    }
    
    /// ObjC Interface
    @objc func handleModifiersDidChange(to newModifiers: NSDictionary) {
        observer.send(value: newModifiers)
    }
    
}
