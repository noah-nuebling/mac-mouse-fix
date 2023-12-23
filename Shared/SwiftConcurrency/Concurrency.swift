//
// --------------------------------------------------------------------------
// Concurrency.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Foundation

@discardableResult public func synchronized<T>(_ lock: AnyObject, closure: () throws -> T) rethrows -> T {
    /// Source https://stackoverflow.com/questions/24045895/what-is-the-swift-equivalent-to-objective-cs-synchronized
    
    objc_sync_enter(lock)
    defer { objc_sync_exit(lock) }

    return try closure()
}

public class Mutex {
    
    func with<T>(closure: () throws -> T) rethrows -> T {
        return try synchronized(self, closure: closure)
    }
    
}

@propertyWrapper public class Atomic<T> {
    /// Source https://jackmorris.xyz/2020/atomic-property-wrapper-considered-harmful/
    /// This is apparently harmful and terrible, because it'll sometimes not behave as expected. But I think it'll just work fine for our purposes.
    
    private let mutex = Mutex()
    private var internalValue: T
    
    public init(wrappedValue: T) {
        self.internalValue = wrappedValue
    }
    
    public var wrappedValue: T {
        get { mutex.with { return internalValue } }
        set { mutex.with { internalValue = newValue } }
    }
    
    public func with<R>(_ body: (inout T) throws -> R) rethrows -> R {
      return try mutex.with { try body(&internalValue) }
    }
}
