//
// --------------------------------------------------------------------------
// PrefixSwift.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

import Foundation
import CocoaLumberjackSwift

@objc class PrefixSwift: NSObject {

    @objc static func initGlobalStuff() {
        /// ^ This is called at program start and should set global Swfft variables
        ///     We'll probably only ever use it for CocoaLumberjack log levels, just like our WannabePrefixHeader
        
        /// Set Log level for CocoaLumberjack in Swift
        ///     Separate from objc log level
        
        #if DEBUG
        dynamicLogLevel = .debug
        #else
        dynamicLogLevel = .info
//        dynamicLogLevel = .off /// Override for testing
        #endif
        
    }
    
}
