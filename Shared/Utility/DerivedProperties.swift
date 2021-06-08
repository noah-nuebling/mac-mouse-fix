//
// --------------------------------------------------------------------------
// CachedComputedProperty.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

/// A derived property is a block that takes no arguments and returns a value when called
/// The returned value is calculated based on other values
/// Here's the useful bit: The block will only re-calculate its value if any of the base values have changed since the last invocation. Otherwise it will return a cached value
/// That way you can have computed properties that are only caculated when necessary, so you don't have to worry about efficiency
///
/// We need to access the current values of the base values whenever a derived property block is called. That' impossible with Swifts copy-on-write mechanics as far as I understand.
/// I tried to make the derived property blocks store references to their base values. I could not find any way.
/// So we defined this as a protocol extension instead. That way we have a reference to self available and can then get references to its current property values through keypaths.
///
/// Also see:
/// Sample code on how to mutate Array values from within a function: https://stackoverflow.com/questions/45109161/is-there-a-way-to-override-the-copy-on-write-behavior-for-swift-arrays
/// Also see CachedComputedPropertiesTests.xcodeproj

import Foundation


class DerivedProperties {
    
    private class func hash(_ values: [AnyHashable]) -> Int {
        
        var hasher = Hasher()
        
        for value in values {
            value.hash(into: &hasher)
        }
        
        return hasher.finalize()
    }
    
    /// `given` should be `KeyPath<Self, Hashable>` but that doesn't work because Swift is weird.
    /// - Parameters:
    ///   - given: KeyPaths to the properties which the derived property is based on. Relative to the calling class.
    ///   - compute: Closure taking the properties described by given as input and returning the derived property.
    /// - Returns: A block which returns the derived property when invoked. Will use a cached value if the `given` properties haven't changed since the last invocation.
    /// - Derived property block holds a weak reference to self. So be careful passing the it around. It's intended to be assigned to a property of the caller.
    /// If we pass in a reference type for S, we should use `weak`  to caputure it in the closure. Otherwise there'll likely be a reference cycle. But in order to use weak, we need to __force__ S to be a reference type (with  `AnyObject`). Ugh.
    class func derivedProperty<S:AnyObject, T>(on owner: S, given: [PartialKeyPath<S>], compute: @escaping ([AnyHashable]) -> T) -> () -> T {
        
        /// Check if all properties are hashable
        
        for keyPath in given {
            if !(owner[keyPath: keyPath] is AnyHashable) {
                assert(false, "All given properties need to be Hashable")
            }
        }
        
        /// Create values to persist across closure invocations
        
        var lastHash: Int = 0
        var lastValue: T?
        
        /// Return closure
        
        return { [weak owner] () -> T in
         
            guard let owner = owner else {
                print("Self is nil. Something went wrong. Crashing the program.")
                assert(false)
            }
            
            /// Get current property values at givenPropertyKeyPaths
            
            let givenProperties: [AnyHashable] = given.map({ (keyPath) -> AnyHashable in
                owner[keyPath: keyPath] as! AnyHashable
            })
            
            /// Get hash of current property values
            
            let hash = owner.hash(givenProperties)
            
            /// Return cached value if hash hasn't changed
            
            if (hash == lastHash) {
                return lastValue!
            }
            
            /// Calculated new derivedValue if givenProperties have changed
            
            let derivedValue = compute(givenProperties) /// Passing in an argument here is sort of unnecessary
            
            /// Update cached values
            
            lastHash = hash
            lastValue = derivedValue
            
            /// Return new value
            
            return derivedValue
        }
    }
}
