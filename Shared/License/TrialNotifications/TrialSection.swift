//
// --------------------------------------------------------------------------
// TrialSection.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Cocoa

class TrialSection: NSView, NSSecureCoding {
    
    /// Vars

    @IBOutlet var imageView: NSImageView?
    @IBOutlet var textField: NSTextField?
    
    /// Archiving
    /// See: https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Archiving/Articles/codingobjects.html#//apple_ref/doc/uid/20000948-97234
    
    static var supportsSecureCoding: Bool = true
    
    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        
        coder.encode(imageView, forKey: "trialImageView")
        coder.encode(textField, forKey: "trialTextField")
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        imageView = coder.decodeObject(forKey: "trialImageView") as! NSImageView?
        textField = coder.decodeObject(forKey: "trialTextField") as! NSTextField?
    }
    
}
