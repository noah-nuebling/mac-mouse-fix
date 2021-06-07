//
// --------------------------------------------------------------------------
// CachedComputedProperty.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Foundation

class tester: NSObject, CachedComputedProperties {
    
    var givenPropertyA = 4
    var givenPropertyB = 3
    
    var derivedProperty: () -> Int
    
    override init() {
        
        derivedProperty = createCachedComputedProperty(given: [\Self.givenPropertyA, \Self.givenPropertyB], derivationFunction: { (properties) -> Int in
            let propA = properties[0] as! Int
            let propB = properties[1] as! Int
            
            print("Deriving property")
            
            return propA + propB
        })
        
        
        print(derivedProperty())
        
        print(derivedProperty())
        
        givenPropertyB += 1
        
        print(derivedProperty())
        
    }
    
}

protocol CachedComputedProperties : AnyObject {
    
}

extension CachedComputedProperties {
    
    private func hash(_ values: [AnyHashable]) -> Int {
        
        var hasher = Hasher()
        
        for value in values {
            value.hash(into: &hasher)
        }
        
        return hasher.finalize()
    }
    
    func createCachedComputedProperty<T>(given givenPropertyKeyPaths: [PartialKeyPath<Self>], derivationFunction derive: @escaping ([AnyHashable]) -> T) -> () -> T {
        
        /// Check if all properties are hashable
        
        for keyPath in givenPropertyKeyPaths {
            if !(self[keyPath: keyPath] is AnyHashable) {
                assert(false, "All given properties need to be Hashable")
            }
        }
        
        /// Create values to persist across closure invocations
        
        var lastHash: Int = 0
        var lastValue: T?
        let deriveForClosure = derive
        
        /// Return closure
        
        return { [unowned self] () -> T in
         
            /// Get current property values at givenPropertyKeyPaths
            
            let givenProperties = givenPropertyKeyPaths.map({ (keyPath) -> AnyHashable in
                self[keyPath: keyPath] as! AnyHashable
            })
            
            /// Get hash of current property values
            
            let hash = self.hash(givenProperties)
            
            /// Return cached value if hash hasn't changed
            
            if (hash == lastHash) {
                return lastValue!
            }
            
            /// Calculated new derivedValue if givenProperties have changed
            
            let derivedValue = deriveForClosure(givenProperties)
            
            /// Update cached values
            
            lastHash = hash
            lastValue = derivedValue
            
            /// Return new value
            
            return derivedValue
        }
    }
}
