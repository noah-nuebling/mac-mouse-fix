//
// --------------------------------------------------------------------------
// Bool+Extensions.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Foundation

extension Bool {
    init<T: Numeric>(_ number: T) {
        if number == T.zero {
            self.init(false)
        }
        self.init(true)
    }
}
