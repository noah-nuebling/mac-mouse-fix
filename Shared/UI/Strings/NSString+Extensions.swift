//
// --------------------------------------------------------------------------
// NSString+Extensions.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

import Foundation

@objc extension NSString {
    
    @objc func attributed() -> NSAttributedString {
        return NSAttributedString(string: self as String)
    }
    
    @objc func firstCapitalized() -> NSString {
        let firstChar = self.substring(to: 1)
        let rest = self.substring(from: 1)
        
        return firstChar.localizedCapitalized.appending(rest) as NSString
    }
}
