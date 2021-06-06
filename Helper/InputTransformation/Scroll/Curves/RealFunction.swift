//
// --------------------------------------------------------------------------
// Curve.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Cocoa

@objc protocol RealFunction {

    @objc func evaluate(at x: Double) -> Double
}
