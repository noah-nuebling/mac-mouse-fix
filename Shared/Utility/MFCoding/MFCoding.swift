//
// --------------------------------------------------------------------------
// MFCoding.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// Wrappers for the `MFCoding` c functions,
//
// TODO: Delete this file, use `MF_SWIFT_UNBRIDGED` to type-erase the objc implementations for swift,
//      so we don't have to keep casting back and forth between Swift types and ObjC types due to forced Swift auto-bridging.

import Foundation

func MFEncode(_ codable: NSObject & NSCoding, requireSecureCoding: Bool, encoding: MFEncoding) -> Any? {
    let result = __MFEncode(codable,
                            requireSecureCoding,
                            encoding)
                            as Any?
    return result
}
func MFDecode(_ data: NSData, requireSecureCoding: Bool, expectedClasses: [AnyClass]?, encoding: MFEncoding) -> (NSObject & NSCoding)? {
    let result = __MFDecode(data as Data,
                            requireSecureCoding,
                            expectedClasses == nil ? nil : Set(expectedClasses as! [AnyHashable]), /// Make sure to only pass in objc `Class` objects, otherwise this might crash I think.
                            encoding)
                            as! (NSObject & NSCoding)?

    return result
}
