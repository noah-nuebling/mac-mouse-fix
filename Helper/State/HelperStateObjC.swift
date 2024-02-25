//
// --------------------------------------------------------------------------
// HelperStateObjC.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Foundation

extension HelperStateObjC {
    static func serializeApp(_ app: NSRunningApplication) -> NSString? {
        return self.__SWIFT_UNBRIDGED_serializeApp(app) as! NSString?
    }
}
