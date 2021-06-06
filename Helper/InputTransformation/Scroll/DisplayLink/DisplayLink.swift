//
// --------------------------------------------------------------------------
// DisplayLink.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Cocoa

@objc class DisplayLinkSwift: NSObject {
    
    // Internal
    
    let displayLink: CVDisplayLink
    
    // Interface
    
    let callback: () -> ()
    
    func start() {
        
    }
    func stop() {
        
    }
    
    @objc init(callback: @escaping () -> ()) {
        
        // Assign callback
        
        self.callback = callback
        
        // Setup internal CVDisplayLink
        
//        CVDisplayLinkCreate);
//        CVDisplayLinkSetOutputCallback(_displayLink, displayLinkCallback, nil);
//        _displaysUnderMousePointer = malloc(sizeof(CGDirectDisplayID) * 3); // TODO: Why 3?
        
    }
    
}
