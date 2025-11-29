//
// --------------------------------------------------------------------------
// PayButton.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// Following this tutoria:l https://www.advancedswift.com/flat-nsbutton-in-swift/

import Cocoa

@IBDesignable @objc class PayButton: NSButton {

    /// Vars
    
    @IBInspectable var backgroundColor: NSColor = .green
    var coolAction: () -> () = { }
    
    /// Action helper
    @objc func doCoolAction() {
        self.coolAction()
    }
    
    /// Drawing
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        /// Set corner radius
        ///     Not sure if necessary to do this in draw()
        wantsLayer = true
        layer?.cornerRadius = frame.height / 2.0
        
        /// Click feedback
        if isHighlighted {
            layer?.backgroundColor = backgroundColor.blended(withFraction: 0.1, of: .black)?.cgColor
        } else {
            layer?.backgroundColor = backgroundColor.cgColor
        }
    }
    
    /// Draw thicker than frame
    override var alignmentRectInsets: NSEdgeInsets { .init(top: 4, left: 0, bottom: 4, right: 0) }
    
    /// Add padding around text
    override var intrinsicContentSize: NSSize {
        let s = super.intrinsicContentSize
        return NSSize(width: s.width + 11, height: s.height + 9)
    }
    
    /// Init
    
    init(title: String, action: @escaping () -> ()) {
        /// For init from code
        
        /// Super init
        ///     Can't just call super.init() because swift is weird
        super.init(frame: NSRect.zero)
        
        /// Real init
        realInit(title: title, coolAction: action)
    }
    
    required init?(coder: NSCoder) {
        /// For init from interface builder
        ///     Call realInit() from code after this

        /// Super init
        ///     We have to call some designated initializer from the immediate superclass I think. But NSButton doesn't have any designated initializers. No idea why this works.
        super.init(coder: coder)
    }
    
    func realInit(title: String, coolAction: @escaping () -> ()) {
        
        /// awakeFromNib doesn't work because we're creating these from code
        
        /// Set title
        self.title = title
        
        /// Store action
        self.coolAction = coolAction
        
        /// Set action
        target = self
        action = #selector(doCoolAction)
        
        /// Basic setup
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        
        /// Make pill-shaped
        layer?.masksToBounds = true
        layer?.cornerRadius = frame.height/2
        bezelStyle = .texturedSquare /// .rounded
        isBordered = false
        
        /// Don't clip
        self.layer?.masksToBounds = false
        
        if #available(macOS 10.14, *) {
            
            /// Make background blue
            ///     And text white
            
            backgroundColor = .systemBlue
            self.contentTintColor = .white.blended(withFraction: 0.01, of: .black)
            
        } else {
            
            /// Make background white pre 10.14
            ///     Because we can't easily change the text color to white
            
            bezelStyle = .rounded
            backgroundColor = .white
            layer?.borderColor = NSColor.gridColor.cgColor
            layer?.borderWidth = 1
        }
        
        /// Wrap content
        self.setContentHuggingPriority(.required, for: .horizontal)
//        self.setContentHuggingPriority(.required, for: .vertical)
    }
}
