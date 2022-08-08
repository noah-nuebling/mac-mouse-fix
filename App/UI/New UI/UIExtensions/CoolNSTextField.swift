//
//  MFTextField.swift
//  AnimatingKeyCaptureView
//
//  Created by Noah Nübling on 19.07.21.
//

/// Wrapper around NSTextField that makes it a little more sane to use

import Cocoa

class CoolNSTextField: NSTextField {
    
    // Mark: Custom init
    
    convenience init(hintWithString hintString: String) {
        self.init(labelWithString: hintString)
        self.textColor = .secondaryLabelColor
        self.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
    }
    
    // MARK: - Screenshots
    
    override func image() -> NSImage? {
        
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
        
        let image = super.image()

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
        
        /// `super.fittingSize` is sometimes *larger* than the explicit height and width constraints. This doesn't make any sense to me and breaks some of my layout code. This function fixes this weird behaviour.
        
        let f = super.fittingSize
        var fittingWidth = f.width
        var fittingHeight = f.height
        
        
        var widthConst: (width: CGFloat, priority: NSLayoutConstraint.Priority) = (.infinity, .init(-1))
        var heightConst: (height: CGFloat, priority: NSLayoutConstraint.Priority) = (.infinity, .init(-1))
        for const in self.constraints {
            if const.firstAttribute == .width && const.priority > widthConst.priority{
                widthConst = (width: const.constant, priority: const.priority)
            }
            if const.firstAttribute == .height && const.priority > heightConst.priority {
                heightConst = (height: const.constant, priority: const.priority)
            }
        }
        
        if widthConst.width < fittingWidth {
            fittingWidth = widthConst.width
        }
        if heightConst.height < fittingHeight {
            fittingHeight = heightConst.height
        }
        
        return NSSize(width: fittingWidth, height: fittingHeight)
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
