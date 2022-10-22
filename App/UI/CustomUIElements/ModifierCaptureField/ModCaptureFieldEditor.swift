//
//  ModCaptureFieldEditor.swift
//  AnimatingKeyCaptureView
//
//  Created by Noah Nübling on 19.07.21.
//

import Cocoa

class ModCaptureFieldEditor: NSTextView, NSTextViewDelegate {
    
    /// Init
    ///     Override all init functions so that customInit() is executed in any case
    ///     We could maybe also use awakeFromNIB() or load(), but those might lead to other problems
    
    required init?(coder: NSCoder) {
        
//        print("CODER INIT")
        
        super.init(coder: coder)
        customInit()
    }
    override init(frame frameRect: NSRect) {
        
//        print("FRAMEEEE INIT")
        
        super.init(frame: frameRect)
//        customInit()
        /// ^ The textContainer init (below) seems to be called when this is called, so we don't need to call customInit here, again
    }
    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        
//        print("FRAME INIT")
        
        super.init(frame: frameRect, textContainer: container)
        customInit()
    }
    
    func customInit() {
        
//        print("CUSTOM FIELD EDITOR INIT")
        
        self.isFieldEditor = true
    }
    
    /// Main
    
    /// Prevent selection
    
    override func mouseDown(with event: NSEvent) {
        return
    }
    
    /// Prevent text input
    
    override func keyDown(with event: NSEvent) {
        return
    }
    override func keyUp(with event: NSEvent) {
        return
    }
    
    /// Prevent insertion cursor from appearing
    ///     Doesn't work but that's fine.
    
    override func mouseMoved(with event: NSEvent) {
        return
    }
    override func scrollWheel(with event: NSEvent) {
        return
    }
    override func mouseEntered(with event: NSEvent) {
        return
    }
    
    override func resetCursorRects() {
        self.discardCursorRects()
    }
    
    
}
