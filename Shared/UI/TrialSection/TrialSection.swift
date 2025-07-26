//
// --------------------------------------------------------------------------
// TrialSection.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// History:
///     - [Jul 2025] Turned this from a NSView subclass to an NSStackView subclass. This simplifies the constraints in Interface Builder, and allows us to remove the `imageView` without leaving a blank space in the layout. Now, the trial section at the bottom of the About Tab is centered!
///
/// Discussion:
///     - [Jul 2025] This whole TrialSection stuff feels so hacky, and I feel like the abstractions that we chose are super bad. Usually I went into UI code with an attitude of "I'm just gonna hack something together without thinking it through, it'll work fine" but here. Usually, this has worked pretty well, but here, the bad code has genuinely caused worse UI and bugs, and increased programming time.

import Cocoa

class TrialSection: NSStackView, NSSecureCoding {
    
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
