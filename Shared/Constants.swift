//
// --------------------------------------------------------------------------
// Constants.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Foundation

extension MFAxis: Hashable { /// So we can use this as dict key
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.rawValue)
    }
}
