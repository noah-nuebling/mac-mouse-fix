//
// --------------------------------------------------------------------------
// NSImageView+Extensions.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Cocoa

@objc extension NSImageView {

    @objc func enableAntiAliasing() {
        
        /// The minification filter and rasterization turn on anti aliasing.
        /// Setting minificationFilterBias to -1 is placebo I'm pretty sure.
        
        self.wantsLayer = true
        self.layer!.minificationFilter = .trilinear
        self.layer!.minificationFilterBias = -1
        self.layer!.shouldRasterize = true
        self.layer!.rasterizationScale = 4.0
    }
    
}
