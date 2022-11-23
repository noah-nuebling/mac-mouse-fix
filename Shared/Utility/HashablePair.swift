//
// --------------------------------------------------------------------------
// HashablePair.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

import Foundation

typealias _HP = HashablePair

struct HashablePair<X, Y>: Hashable where X: Hashable, Y: Hashable {
    /// Tuple isn't hashable so we use this instead
    
    let a: X
    let b: Y
    
    init(a: X, b: Y) {
        self.a = a
        self.b = b
    }
}
