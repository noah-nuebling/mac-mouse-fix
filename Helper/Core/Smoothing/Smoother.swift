//
// --------------------------------------------------------------------------
// Smoother.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

import Foundation

@objc protocol Smoother {
    
    @objc func smooth(value: Double) -> Double
    @objc func reset()
    
}
