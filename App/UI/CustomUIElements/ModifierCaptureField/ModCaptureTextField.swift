//
//  CustomTextField.swift
//  AnimatingKeyCaptureView
//
//  Created by Noah Nübling on 18.07.21.
//


/**
 Stuff:
 - How to detect if NSTextField starts / ends editing (becomeFirstResponder and resignFirstResponder don't work)
    - https://stackoverflow.com/questions/25692122/how-to-detect-when-nstextfield-has-the-focus-or-is-its-content-selected-cocoa
 */

import Cocoa
import ReactiveSwift
import ReactiveCocoa

@IBDesignable class ModCaptureTextField: CoolNSTextField, NSTextFieldDelegate, NSTextDelegate, NSTextViewDelegate, NSControlTextEditingDelegate, BindingSource, BindingTargetProvider {
    
    /// BindingSource and Target protocol implementation
    
    typealias Value = NSEvent.ModifierFlags
    typealias Error = Never
    var bindingTarget: BindingTarget<NSEvent.ModifierFlags> { content.flags }
    var producer: SignalProducer<NSEvent.ModifierFlags, Never> { content.flagss }
    
    /// Other interface
    var signal: Signal<NSEvent.ModifierFlags, Never> { content.signal }
    
    /// Data model
    
    var content = ReactiveFlags(.init(rawValue: 0))
    
    /// Set cursor on hover
    
    fileprivate func updateCursorRect() {
        self.discardCursorRects()
        
        let cursor: NSCursor
        if self.content.value.isEmpty {
            cursor = NSCursor.iBeam
        } else {
            cursor = NSCursor.current
        }
        self.addCursorRect(self.bounds, cursor: cursor)
    }
    
    /// Init
    
    override func awakeFromNib() {
        
        
        /// Set delegate to self
        self.delegate = self
        
        /// Activate layer backing
        self.wantsLayer = true
        
        /// Configure text field visuals
        self.bezelStyle = .roundedBezel
        self.alignment = .center
        self.lineBreakMode = .byTruncatingTail
        self.focusRingType = .none
        
        /// Initialize content
//        self.updateAppearance()
        
        /// Listen to content changes
        
        content.producer.startWithValues { flags in
            self.updateCursorRect()
            self.updateAppearance()
        }
    }
    
    /// Convenience
    
    var fieldEditorrrr: ModCaptureFieldEditor {
        let delegate = self.window?.delegate as! ResizingTabWindowController
        return delegate.modCaptureFieldEditor!
    }
    
    /// IBActions
    
    @IBAction func clear(_ sender: Any?) {
        self.content.value = .init(rawValue: 0)
//        _observer?.send(value: [])
    }
    
    /// Refuse first responder (editing) if already filled
    
    override func coolValidateProposedFirstResponder() -> Bool {
        return true
    }
    
    /// Disable insertion cursor if already filled
    
    override func resetCursorRects() {
        
        updateCursorRect()
    }
    
    /// Become firstResponder
    
    private var localEventMonitor: Any? = nil
    
    override func coolDidBecomeFirstResponder() {
        
        print("BECOMING FIRST RESPONDER")
        
        /// Hide cursor
        ///     By setting its color to clear.
        ///     Maybe we should set it to black again on resignFirstResponder()
        ///     Src: https://stackoverflow.com/questions/2258300/nstextfield-white-text-on-black-background-but-black-cursor
        let editor: NSText? = self.currentEditor()
        if let editorTextView = editor as? NSTextView? {
            editorTextView?.insertionPointColor = .clear
        }
        
        /// Set firstResponder appearance
        
        self.updateAppearance()
        
        /// Setup keyboard modifer event listener
        
        self.localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .leftMouseDown]) { (event) -> NSEvent? in
            
            if event.type == .leftMouseDown {
                
                let locationInSuperView = self.superview!.convert(event.locationInWindow, from: nil)
                let hitView = self.hitTest(locationInSuperView)
                if hitView == nil {
                    self.window?.makeFirstResponder(nil)
                }
                
            } else if event.type == .flagsChanged {
                
                /// Get string from modifier flags
                
                let mods = event.modifierFlags
                let modString = self.getString(fromFlags: mods)
                
                self.stringValue = modString
                self.textColor = .placeholderTextColor
                self.currentEditor()?.selectedRange = NSMakeRange(0, 0)
                
                print("modString: \(modString)")
                
                if !(modString == "-") {
                    
                    let timingFunction:CAMediaTimingFunction = .init(name: .easeOut)
                    let duration = 0.4
                    
                    /// Animate scale
                    
                    self.scale(withFactor: 1.1, timingFunction: timingFunction, duration: duration) {
                        
                        print("Captured \(modString)")
                        
                        /// Clear
                        ///     Necessary to disable insertion cursor. Not sure why.
                        self.clear(nil)
                        
                        /// Strip weird stuff from mods
                        let filteredMods = mods.intersection(.deviceIndependentFlagsMask)
                        
                        /// Update data model
                        self.content.value = filteredMods
                        
                        /// Notify signal
//                        self._observer?.send(value: mods)
                        
                        /// Resign first responder
                        self.window?.makeFirstResponder(nil)
                        
                        /// Set normal appearance
                        self.updateAppearance()
                        self.updateCursorRect()
                        
                        /// Restore initial scaling with bounce animation
                        
                        let bounceAnimation = CASpringAnimation()
                        bounceAnimation.stiffness = 1200
                        bounceAnimation.damping = 15.0
                        bounceAnimation.mass = 1.3
                        self.scale(withFactor: 1.0, animation: bounceAnimation, onComplete: {})
                    }
                    
                } else {
                    self.scale(withFactor: 1.0, timingFunction: .init(name: .easeOut), duration: 0.25) {}
                    self.updateAppearance() /// Not sure if necessary
                }
            } else {
                fatalError()
            }
            
            /// Return
            
            return event
        }
        
    }
    
    /// Resign firstResponder
    
    override func coolDidResignFirstResponder() {
        
        print("RESIGNING FIRST RESPONDER")
        
        updateAppearance()
        
        NSEvent.removeMonitor(self.localEventMonitor!)
    }

    /// Helper
    
    private func updateAppearance() {
        /// This is called whenever `content` changes, but also in some other spots
        
        /// Update appearance based on content
        
        let contentString = self.getString(fromFlags: self.content.value)
        
        if contentString == "-" {
            self.textColor = .placeholderTextColor
        } else {
            self.textColor = .controlTextColor
        }
        
        /// Update appearance based on responder status
        
        if self.isCoolFirstResponder {
            self.currentEditor()?.selectAll(nil)
        } else {
            self.currentEditor()?.selectedRange = NSMakeRange(0, 0)
        }
        
        /// Set string value
        
        if isCoolFirstResponder && contentString == "-" {
//            self.stringValue = getString(fromFlags: [.command, .shift, .option, .control])
            self.stringValue = contentString
        } else {
            self.stringValue = contentString
        }
    }
    
    private func getString(fromFlags flags: NSEvent.ModifierFlags) -> String {
        
        /// Validate
        
//        let validFlagMask: NSEvent.ModifierFlags = [.control, .option, .shift, .command, .function]
//
//        for flag in flags. {
//            assert(validFlagMask.contains(flag))
//        }
        
        var modString = ""
        
//        if flags.contains(.function) {
//            modString.append("fn")
//        }
        if flags.contains(.control) {
            modString.append("⌃")
        }
        if flags.contains(.option) {
            modString.append("⌥")
        }
        if flags.contains(.shift) {
            modString.append("⇧")
        }
        if flags.contains(.command) {
            modString.append("⌘")
        }
        if modString == "" {
            modString = "-"
        }
        
        return modString
    }
    
    fileprivate func animateTextColor(onView view: ModCaptureTextField, startColor: NSColor, endColor: NSColor, duration: Double, timingFunction: CAMediaTimingFunction) {
        ///     For some reason we're doing everything in the completion block. No idea why this works but it does
        ///     Src: https://stackoverflow.com/a/51042306/10601702
        view.textColor = startColor
        
        let colorTransition = CATransition()
        colorTransition.duration = duration /// Setting these on the CATransaction doesn't work
        colorTransition.timingFunction = timingFunction
        
        CATransaction.begin()
        
        CATransaction.setCompletionBlock {
            view.layer?.add(colorTransition, forKey: nil)
            view.textColor = endColor
        }
        
        CATransaction.commit()
    }
    
    /// v Trying to prevent text selection, but nothing works.
    ///     I'll have to provide a custom field editor. See https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/TextEditing/Tasks/FieldEditor.html#//apple_ref/doc/uid/20001815-131165
    
    override func mouseDown(with event: NSEvent) {
        
//        self.updateAppearance() /// Not sure if necessary
        return
    }
    
    override func select(withFrame rect: NSRect, editor textObj: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
        return;
    }
    
    func textField(_ textField: NSTextField, textView: NSTextView, shouldSelectCandidateAt index: Int) -> Bool {
        return false
    }
}
