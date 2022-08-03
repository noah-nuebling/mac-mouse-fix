//
// --------------------------------------------------------------------------
// SharedUtilitySwift.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Cocoa
import CocoaLumberjackSwift

@objc class SharedUtilitySwift: NSObject {

    @objc static func doOnMain(_ block: () -> ()) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.sync {
                block()
            }
        }
    }
    
    static func clip<T: Comparable>(_ value: T, betweenLow low: T, high: T) -> T { /// Might want to move this to Math.swift
        if value < low { return low }
        if value > high { return high }
        return value
    }
    
    @objc static func shallowCopy(of object: NSObject) -> NSObject {
        /// Why is there no default "shallowCopy" method for objects?? Is this bad?
        /// Be careful not to mutate any properties in the copy because it's shallow (holds new references to the same old objects as the original)
        /// Reference on property attributes: https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtPropertyIntrospection.html
        
        /// Get reference to class of object
        let type = type(of: object)
        
        /// Create new instance of the same type
        let copy = type.init()
        
        /// Iterate properties
        ///     And copy the values over to the new instance
        
        var numberOfProperties: UInt32 = 0
        let propertyList = class_copyPropertyList(type, &numberOfProperties)
        
        guard let propertyList = propertyList else { fatalError() }
        
        for i in 0..<(Int(numberOfProperties)) {
            
            let property = propertyList[i]
            
            /// Get property name
            let propertyNameC = property_getName(property)
            let propertyName = String(cString: propertyNameC)
            
            /// Skip copying if readonly
            let readOnlyAttributeValue = property_copyAttributeValue(property, "R".cString(using: .utf8)!)
            let isReadOnly = readOnlyAttributeValue != nil
            if isReadOnly { continue }
            
            /// Get reference to original value
            let oldValue = object.value(forKey: propertyName)
            
            /// Skip copying if nil
            if oldValue == nil { continue }
        
            /// Assign oldValue to the copy
            copy.setValue(oldValue, forKey: propertyName)
        }
        
        free(propertyList)
        
        return copy;
    }
    
}
