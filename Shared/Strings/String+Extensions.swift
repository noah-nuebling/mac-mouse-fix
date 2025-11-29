//
// --------------------------------------------------------------------------
// String+Extensions.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Foundation
import Cocoa

extension String {
    
    func image(fontSize: Double? = nil) -> NSImage {
        /// Also found https://stackoverflow.com/a/38809531/10601702 but it's iOS only
        
        if fontSize == nil {
            return NSAttributedString(string: self).image()
        } else {
            var s = NSAttributedString(string: self)
            s = s.settingFontSize(fontSize!)
            return s.image()
        }
    }
    
}
