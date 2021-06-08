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

// MARK: Base functions

fileprivate func allHashable(values: [Any]) -> Bool {
    /// Check if all values are hashable
    
    for value in values {
        if !(value is AnyHashable) {
            return false
        }
    }
    
    return true
}

fileprivate func hashOfArray(_ values: [AnyHashable]) -> Int {
    /// Needs to have long `withArray` name to avoid naming conflicts in the closure below
    
    var hasher = Hasher()
    
    for value in values {
        value.hash(into: &hasher)
    }
    
    return hasher.finalize()
}

fileprivate func getProperties<S>(on owner: S, at keyPaths: [PartialKeyPath<S>]) -> [AnyHashable] {
    return keyPaths.map({ (keyPath) -> AnyHashable in
        owner[keyPath: keyPath] as! AnyHashable
    })
}

/// I don't know how to cast the ObjC-compatible, String-based keyPaths to Swifts PartialKeyPaths which we use in the other `getProperties` implementation. So we just implement it twice.
fileprivate func getProperties(on owner: NSObject, at keyPaths: [String]) -> [AnyHashable] {
    
    return keyPaths.map({ (keyPath) -> AnyHashable in
        return owner.value(forKeyPath: keyPath) as! AnyHashable
    })
}

fileprivate func getDerivedValue<S, T>(owner: S, givenProperties: [AnyHashable], compute: () -> T, lastHash: inout Int, lastValue: inout T?) -> T {
    
    #if DEBUG
    print("Getting derived value...")
    #endif
    
    /// Get hash of current property values
    
    let hash = hashOfArray(givenProperties)
    
    /// Return cached value if hash hasn't changed
    
    if (hash == lastHash) {
        
        #if DEBUG
        print("Given properties haven't changed. Reusing previous value \(String(describing: lastValue))")
        #endif
        
        return lastValue!
    }
    
    /// Calculated new derivedValue if givenProperties have changed
    
    let derivedValue = compute() /// Passing in an argument here is sort of unnecessary
    
    /// Update cached values
    
    lastHash = hash
    lastValue = derivedValue
    
    #if DEBUG
    print("Given properties did change. Recalculated derived value: \(derivedValue)")
    #endif
    
    /// Return new value
    
    return derivedValue
}



// MARK: Protocol implementation
/// Use this to create derived properties on value types. The class based implementation doesn't work with value types.
/// I think that, when this is used on a reference type, it will cause a retain cycle if the derived property obtained through `derivedProperty()` is stored as an instance property on that reference type. That's because we're not using `[weak self]` in the closure. If we used `[weak self]` it would be incompatible with value types, which is the puropose of the Protocol implementation to begin with
///     -> So the gist is: Only use the `Protocol implementation` for value types, and use the `Class implementation` for reference types.

protocol DerivedPropertyCreator : Any { }

extension DerivedPropertyCreator {
    
    func derivedProperty<T>(given keyPaths: [PartialKeyPath<Self>], compute: @escaping () -> T) -> () -> T {
        
        /// Guard hashable
        
        let givenProperties: [AnyHashable] = getProperties(on: self, at: keyPaths)
        assert(allHashable(values: givenProperties), "All given properties need to be Hashable")
        
        /// Create values to persist between closure invocations
        
        var lastHash: Int = 0
        var lastValue: T?
        
        /// Return closure
        
        return { () -> T in
            
            /// Get current property values at givenPropertyKeyPaths
            
            let givenProperties: [AnyHashable] = getProperties(on: self, at: keyPaths)
            
            return getDerivedValue(owner: self, givenProperties: givenProperties, compute: compute, lastHash: &lastHash, lastValue: &lastValue)
            
        }
    }
    
}

// MARK: Class implementation
/// Use this to create static derived properties. The protocol extension won't work with static properties.

@objc class DerivedProperty: NSObject {
    
    /// ObjC
    
    @objc class func create(on owner: NSObject, given keyPaths: [String], compute: @escaping () -> Any) -> () -> Any {
        /// ObjC compatible version of `create()`, but without Swifts neat keyPaths or generics
        /// Since we can only convert Swift keyPaths to string-based, ObjC compatible keyPaths, and not the other way around, we might make this ObjC compatible version of the create function the base implementation, and have the normal Swift version call it. Otherwise there'd have to be either a lot of code duplication or another layer of closure nesting / passing them as arguments making everything confusing.
        /// Edit: But then we'd have to expose all properties we pass to the Swift function via @objc, so that's not a solution, either.
        ///     See https://stackoverflow.com/questions/46529015/getting-string-from-swift-4-new-key-path-syntax
        ///     We'll just implement it twice then...
        
        /// Guard hashable
        
        let givenProperties = getProperties(on: owner, at: keyPaths)
        assert(allHashable(values: givenProperties), "All given properties need to be Hashable")
        
        var lastHash: Int = 0
        var lastValue: Any?
        
        /// Return closure
        
        return { [weak owner] () -> Any in
            
            guard let owner = owner else {
                print("Self is nil. Something went wrong. Crashing the program.")
                assert(false)
            }
            
            let givenProperties: [AnyHashable] = getProperties(on: owner, at: keyPaths)
            return getDerivedValue(owner: owner, givenProperties:givenProperties, compute: compute, lastHash: &lastHash, lastValue: &lastValue)
        }
    }
    
    /// Swift
    
    class func create<S:AnyObject, T>(on owner: S, given keyPaths: [PartialKeyPath<S>], compute: @escaping () -> T) -> () -> T {
        /// - Parameters:
        ///   - given: KeyPaths to the properties which the derived property is based on. Relative to the `owner` object. `given` should be `KeyPath<S, Hashable>` but that doesn't work because Swift is weird.
        ///   - compute: Closure that calculates the derived property.
        ///         You should only use other mutable instance properties in the closure by referencing them via the keyPaths specified in `given`. You shoudn't access the other properties directly, because then they will get captured by the closure and won't update to their real value on successive closure invocations. If you don't specify a mutable properties you use in the closure by adding its keyPath to `given`, then the closure won't be recalculated when invoked that property changed.
        ///             -> So the gist is: 1. Specify all mutable values from outside the closures scope in the `given` array. 2. Only access them by reference (via keyPath) in the closure, so you don't accidentally capture them.
        ///             -> Edit: Actually this is BS. See here for a great article on how capturing works. https://marcosantadev.com/capturing-values-swift-closures/
///                         In reality, even value types, when used in a closure, will see outside changes. So the value types will be references. Which is super confusing. The only way to get an immutable copy of a value in the closure is using capture lists on value types as far as I understood. (But what happens when the value types which are used in the closure are deallocated? For reference types you can control this using weak, strong, unowned in the capture list, but what about value types?)
///                     -> Something else we should make sure when calling this is to only capture self weakly in the `compute` closure, if we want to assgn the result of this function method call to a property of self. Otherwise that will be a strong ref cycle. Even though we already specified weak in the return closure. Ughh this is a lot.
        /// - Returns: A block which returns the derived property when invoked. The derived property can be invoked to retrieve its value. It will use a cached value if the `given` properties haven't changed since the last invocation.
        /// - Discussion: Derived property block holds a weak reference to self. So be careful passing the it around. It's intended to be assigned to a property of the caller.
        ///     If we pass in a reference type for S, we should use `weak`  to caputure it in the closure. Otherwise there'll likely be a reference cycle. But in order to use weak, we need to S to be a reference type (with  `AnyObject`).
        
        /// Guard hashable
        
        let givenProperties: [AnyHashable] = getProperties(on: owner, at: keyPaths)
        assert(allHashable(values: givenProperties), "All given properties need to be Hashable")
        
        /// Create values to persist across closure invocations
        
        var lastHash: Int = 0
        var lastValue: T?
        
        /// Return closure
        
        return { [weak owner] () -> T in
            
            guard let owner = owner else {
                print("Self is nil. Something went wrong. Crashing the program.")
                assert(false)
            }
            
            let givenProperties: [AnyHashable] = getProperties(on: owner, at: keyPaths)
            return getDerivedValue(owner: owner, givenProperties:givenProperties, compute: compute, lastHash: &lastHash, lastValue: &lastValue)
        }
    }
}
