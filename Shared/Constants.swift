//
// --------------------------------------------------------------------------
// Constants.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Foundation

extension MFAxis: Hashable { /// So we can use this as dict key
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.rawValue)
    }
}
