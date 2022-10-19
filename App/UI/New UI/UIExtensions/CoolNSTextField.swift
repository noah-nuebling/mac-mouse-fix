//
//  MFTextField.swift
//  AnimatingKeyCaptureView
//
//  Created by Noah Nübling on 19.07.21.
//

/// Wrapper around NSTextField that makes it a little more sane to use

import Cocoa

class MarkdownTextField: CoolNSTextField {
    
    /// This is intended to be used in IB, and it will parse the string set in IB as markdown automatically
    
    required init?(coder: NSCoder) {
        
        /// Init from IB
        
        /// Init super
        
        super.init(coder: coder)
        
        /// Make clickable
        makeLinksClickable()
        
        /// Parse md
        guard let md = NSAttributedString(coolMarkdown: self.stringValue, fillOutBase: false) else { return }
        
        /// Assign markdown to self
        assignAttributedStringKeepingBase(&self.attributedStringValue, md)
    }
    
}

class CoolNSTextField: NSTextField {
    
    // MARK: Custom init
    
    convenience init(hintWithString hintString: String) { /// Wny is this not in a NSTextField extension?
        ///
        self.init(labelWithString: hintString)
        self.textColor = .secondaryLabelColor
        self.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
    }
    convenience init(hintWithAttributedString hintString: NSAttributedString) { /// Wny is this not in a NSTextField extension?
        
        let hintString = hintString.fillingOutBaseAsHint()
        self.init(labelWithAttributedString: hintString)
        makeLinksClickable()
    }
    
    // MARK: - Links
    
//    override func resetCursorRects() {
//        /// Keep normal cursor despite setting `isSelectable` true.
//        ///     Stops working after the field has been clicked
//
//        addCursorRect(bounds, cursor: .arrow)
//    }
    
    func makeLinksClickable() {
        
        /// Make clickable so links work
        /// This also makes the cursor an inseration cursor on hover which is weird
        /// Src: https://developer.apple.com/library/archive/qa/qa1487/_index.html
        
        self.allowsEditingTextAttributes = true
        self.isSelectable = true
    }
    
    // MARK: - Screenshots
    
    override func takeImage() -> NSImage? {
        
        /// Find the original implementation of `image()` in `NSView+Extensions.swift`
        
        /// This alternate version is necessary for properly screenshotting NSTextField. Noooot sure what's going on
        ///     What might be going on is that the layout system works with a separate frame from self.frame. The only API function to interact with this layoutFrame is fittingSize(). To screenshot the part of the view that the layout system will work with / make visible we need to: first force self.frame.size to equal the fittingSize, and then take the screenshot.
        
        let fittingSize = self.fittingSize
        
        var deactivatedConstraints: [NSLayoutConstraint] = []
        for const in self.constraints {
            if const.firstAttribute == .width || const.firstAttribute == .height {
                deactivatedConstraints.append(const)
                const.isActive = false
            }
        }
        
        let fittingWidthConst = self.widthAnchor.constraint(equalToConstant: fittingSize.width)
        fittingWidthConst.isActive = true
        let fittingHeightConst = self.heightAnchor.constraint(equalToConstant: fittingSize.height)
        fittingHeightConst.isActive = true
        
        self.needsLayout = true
        self.layoutSubtreeIfNeeded()
        
        let image = super.takeImage()

        fittingWidthConst.isActive = false
        fittingHeightConst.isActive = false
        for const in deactivatedConstraints {
            const.isActive = true
        }
        
        return image
    }
    
    // MARK: - Frame and size
    
    override func size() -> NSSize {
        /// Use instead of self.frame.size
        ///     self.frame.size is wrong for NSTextField. It's different than the size it is actually displayed at. Even after calling layoutSubTreeIfNeeded).
        ///     Using `fittingSize` gets the correct result
        ///     But this might break things if self's size is controlled by a constraint to a superview (because fittingSize ignores superviews)
        ///         No idea how we could handle that case
        return self.fittingSize
    }
    
    override var fittingSize: NSSize {
        return super.coolFittingSize()
    }
    
    // MARK: - First responder status
    
    /// Src: https://stackoverflow.com/questions/25692122/how-to-detect-when-nstextfield-has-the-focus-or-is-its-content-selected-cocoa
    /// Provides sane firstResponder functions for subclasses
    /// The normal firstResponder functions don't work, because NSTextField does delegate text editing to the enclosing windows' fieldEditor.
    /// The result is that resignFirstResponder is called right after becomeFirstResponder making both functions pretty useless.
    ///     Edit: Except that on my system (Big Sur) resignFirstResponder is always called __before__ becomeFirstResponder making things even more confusing.
    ///         -> I have a suspicion, that this is not the case on older OSs / other systems, based on what I read on Stack Overflow. We should look into using our custom ModCaptureFieldEditor to gain info on when first responder is resigned / attained in a robust way that will surely work on any macOS version.
    
    var expectingFieldEditor = false
    var isCoolFirstResponder = false
    
    override func resignFirstResponder() -> Bool {
        /// For some reason resignFirstResponder() is always called before becomeFirstResponder() ?
        
        let success = super.resignFirstResponder()
        
        print("Raw resignFirstResponder")
        
        if success {
            expectingFieldEditor = true
        }
        
        return success
        
    }
    
    override func becomeFirstResponder() -> Bool {
        
        if !self.coolValidateProposedFirstResponder() { return false }
        
        let success = super.becomeFirstResponder()
        
        print("Raw becomeFirstResponder")
        
        if success && expectingFieldEditor {
            /// Call cool function
            self.isCoolFirstResponder = true
            self.coolDidBecomeFirstResponder()
            
        }
        expectingFieldEditor = false
        
        return success
    }
    
    override func textDidEndEditing(_ notification: Notification) {
        super.textDidEndEditing(notification)
        
        print("textEndEditing")
        
        /// Call cool function
        if self.isCoolFirstResponder {
            self.isCoolFirstResponder = false
            self.coolDidResignFirstResponder()
        }
    }
    
    /// Subclass overridable firstResponder functions
    
    func coolValidateProposedFirstResponder() -> Bool {
        return true
    }
    
    func coolDidBecomeFirstResponder() {
        /// Override
    }
    
    func coolDidResignFirstResponder() {
        /// Override
    }
    
    
}
