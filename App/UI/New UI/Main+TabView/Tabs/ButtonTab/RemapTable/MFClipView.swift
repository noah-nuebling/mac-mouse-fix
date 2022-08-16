//
// --------------------------------------------------------------------------
// MFClipView.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Cocoa

class MFClipView: NSClipView {

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    
    override func viewBoundsChanged(_ notification: Notification) {
        self.translatesAutoresizingMaskIntoConstraints = false
        self.documentView?.translatesAutoresizingMaskIntoConstraints = false
        super.viewBoundsChanged(notification)
    }
    
    override func viewFrameChanged(_ notification: Notification) {
        self.translatesAutoresizingMaskIntoConstraints = false
        self.documentView?.translatesAutoresizingMaskIntoConstraints = false
        super.viewFrameChanged(notification)
    }
}
