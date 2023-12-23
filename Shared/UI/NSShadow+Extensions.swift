//
// --------------------------------------------------------------------------
// NSShadow+Extensions.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Foundation

extension NSShadow {
    
    static var clearShadow: NSShadow {
        let s = NSShadow()
        s.shadowColor = .clear
        s.shadowOffset = .zero
        s.shadowBlurRadius = 0.0
        return s
    }
}
