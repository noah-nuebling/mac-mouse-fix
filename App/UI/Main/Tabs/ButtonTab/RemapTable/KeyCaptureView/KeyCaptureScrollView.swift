//
// --------------------------------------------------------------------------
// KeyCaptureScrollView.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Cocoa

@objc(KeyCaptureScrollView)
public class KeyCaptureScrollView: NSScrollView {
    
    public override var focusRingMaskBounds: NSRect {
        return self.bounds.insetBy(dx: 0, dy: 0)
    }
    
    public override func drawFocusRingMask() {
        let cornerRadius: CGFloat
        if #available(macOS 11.0, *) {
            cornerRadius = 4.0
        } else {
            cornerRadius = 3.0
        }
        
        let bounds = self.bounds.insetBy(dx: 0, dy: 0)
        let focusRingPath = NSBezierPath(roundedRect: bounds, xRadius: cornerRadius, yRadius: cornerRadius)
        focusRingPath.fill()
    }
    
    public override func becomeFirstResponder() -> Bool {
        DDLogInfo("SCROLLVIEW BECOME FIRST")
        return super.becomeFirstResponder()
    }
    
    public override func resignFirstResponder() -> Bool {
        DDLogInfo("SCROLLVIEW RESIGN FIRST")
        return super.resignFirstResponder()
    }
}
