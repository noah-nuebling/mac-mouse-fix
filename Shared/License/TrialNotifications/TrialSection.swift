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

    private var _imageView: NSImageView?
    @IBOutlet var imageView: NSImageView? {
        get {
            return _imageView
        }
        set {
            if let newValue = newValue,
               let _imageView = _imageView {
                
                replaceViewTransferringConstraints(_imageView, replacement: newValue, transferSize: false)
            }
            _imageView = newValue
        }
    }
    
    private var _textField: NSTextField?
    @IBOutlet var textField: NSTextField? {
        get {
            return _textField
        }
        set {
            if let newValue = newValue,
               let _textField = _textField {
                
                replaceViewTransferringConstraints(_textField, replacement: newValue, transferSize: true)
            }
            _textField = newValue
        }
    }
    
    /// Archiving
    /// See: https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Archiving/Articles/codingobjects.html#//apple_ref/doc/uid/20000948-97234
    
    static var supportsSecureCoding: Bool = true
    
    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        
        coder.encode(_imageView, forKey: "trialImageView")
        coder.encode(_textField, forKey: "trialTextField")
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        _imageView = coder.decodeObject(forKey: "trialImageView") as! NSImageView?
        _textField = coder.decodeObject(forKey: "trialTextField") as! NSTextField?
    }
    
}
