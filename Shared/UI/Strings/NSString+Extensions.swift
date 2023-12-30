//
// --------------------------------------------------------------------------
// NSString+Extensions.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Foundation

@objc extension NSString {
    
    @objc func substring(regex: String) -> String? {
        
        let range = self.range(of: regex, options: .regularExpression)
        
        let result: String?
        if range.location == NSNotFound {
            result = nil
        } else {
            result = self.substring(with: range)
        }
        
        return result
    }
    
    @objc func attributed() -> NSAttributedString {
        return NSAttributedString(string: self as String)
    }
    
    @objc func firstCapitalized() -> NSString {
        let firstChar = self.substring(to: 1)
        let rest = self.substring(from: 1)
        
        return firstChar.localizedCapitalized.appending(rest) as NSString
    }
    
    @objc func stringByTrimmingWhiteSpace() -> NSString {
        return self.attributed().trimmingWhitespace().string as NSString /// This is pretty inefficient but probably doesn't matter
    }
}
