//
// --------------------------------------------------------------------------
// NSString+Extensions.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Foundation

@objc extension NSString {
    
    @objc func attributed() -> NSAttributedString {
        return NSAttributedString(string: self as String)
    }
}
