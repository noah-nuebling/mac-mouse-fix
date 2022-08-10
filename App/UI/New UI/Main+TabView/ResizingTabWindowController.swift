//
//  ResizingTabWindowDelegate.swift
//  tabTestStoryboards
//
//  Created by Noah Nübling on 20.06.22.
//

import Cocoa

class ResizingTabWindowController: NSWindowController, NSWindowDelegate {

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
    
//    func window(_ window: NSWindow, shouldPopUpDocumentPathMenu menu: NSMenu) -> Bool {
//
//        /// Trying to turn off the document path button. Doing it in window subclass instead
//
//        window.title = window.title
//        window.setTitleWithRepresentedFilename("")
//        window.standardWindowButton(.documentIconButton)?.image = nil
//        return false
//    }
}
