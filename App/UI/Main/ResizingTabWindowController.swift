//
//  ResizingTabWindowDelegate.swift
//  tabTestStoryboards
//
//  Created by Noah Nübling on 20.06.22.
//

import Cocoa

class ResizingTabWindowController: NSWindowController, NSWindowDelegate {

    
    // MARK: Lifecycle
    
    override func windowDidLoad() {
        
        super.windowDidLoad()
        let thewindow = window!
        
        /// Restore position
        ///     src: https://developer.apple.com/forums/thread/679764
        thewindow.setFrameUsingName("MyWindow")
        self.windowFrameAutosaveName = "MyWindow"
    }
    
    // MARK: Custom field editor
    /// Assign our custom modCaptureFieldEditor to modCaptureTextField instances
    
    var modCaptureFieldEditor: ModCaptureFieldEditor? = nil
    
    func windowWillReturnFieldEditor(_ sender: NSWindow, to client: Any?) -> Any? {
        
        guard let client = client as? ModCaptureTextField else {
            return nil
        }
        
        if modCaptureFieldEditor == nil {
            modCaptureFieldEditor = ModCaptureFieldEditor.init(frame: client.frame) /// Why do we need to pass a frame?
        }
        
        return modCaptureFieldEditor
    }
    
    // MARK: Accessibility view
    
    func windowDidBecomeMain(_ notification: Notification) {
        let accessibilityEnabled = (MFMessagePort.sendMessage("checkAccessibility", withPayload: nil, waitForReply: true) as? NSNumber)?.boolValue ?? true
        
        if accessibilityEnabled {
            AuthorizeAccessibilityView.remove()
        } else {
            AuthorizeAccessibilityView.add()
        }
    }

}
