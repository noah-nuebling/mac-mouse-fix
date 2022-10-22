//
//  ReactiveFlags.swift
//  tabTestStoryboards
//
//  Created by Noah Nübling on 20.06.22.
//

/// Works like `MutableProperty<NSevent.ModifierFlags>` but better.
/// Reactive Swift's MutableProperty doesn't work properly with NSEvent.ModifierFlags. It seems to always send events to its signal even when a new value is assigned. Even if the new value is the same as the old value (or maybe that's just how MutableProperty works?) Either way this leads to weird recursive lock acquisition errors deep within Reactive Swift when using `MutableProperty<NSevent.ModifierFlags>` to manage the ModCaptureViews in ScrollTabController.swift.

import Foundation
import ReactiveSwift
import AppKit

class ReactiveFlags: NSObject, BindingSource, BindingTargetProvider {
    
    /// BindingTargetProvider protocol implemenation
    
    var bindingTarget: BindingTarget<NSEvent.ModifierFlags> { flags }
    
    /// BindingSouce protocol implemenation
    
    typealias Value = NSEvent.ModifierFlags
    typealias Error = Never
    var producer: SignalProducer<NSEvent.ModifierFlags, Never> { flagss }
    
    /// Other interface
    var signal: Signal<NSEvent.ModifierFlags, Never> { _signal }
    
    /// Wrapped value
    
    private var _rawValue: NSEvent.ModifierFlags
    
    var value: NSEvent.ModifierFlags {
        get {
            _rawValue
        } set {
            
            if _rawValue != newValue {
                _rawValue = newValue
                _observer.send(value: newValue)
            }
        }
    }
    
    /// Signal and binding target
    
    private var _signal: Signal<NSEvent.ModifierFlags, Never>
    private var _observer: Signal<NSEvent.ModifierFlags, Never>.Observer
    
    var flagss: SignalProducer<NSEvent.ModifierFlags, Never> {
        return _signal.producer.prefix(value: value)
    }
    var flags: BindingTarget<NSEvent.ModifierFlags> {
        return BindingTarget(lifetime: self.reactive.lifetime) { flags in
            self.value = flags
        }
    }
    
    /// Init
    init(_ value: NSEvent.ModifierFlags) {
        _rawValue = value
        let (s, o) = Signal<NSEvent.ModifierFlags, Never>.pipe()
        _signal = s
        _observer = o
        super.init()
    }
}
