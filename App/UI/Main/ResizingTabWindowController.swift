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
    
    private var removeAccessibilityViewTimer: Timer? = nil
    func windowDidBecomeMain(_ notification: Notification) {
        /// Ask helper if accessibility enabled
        MFMessagePort.sendMessage("checkAccessibility", withPayload: nil, expectingReply: false)
        /// Dismiss accessibility view if no reply
        removeAccessibilityViewTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { timer in
            AuthorizeAccessibilityView.remove()
        }
    }
    @objc public func handleAccessibilityDisabledMessage() {
        AuthorizeAccessibilityView.add()
        removeAccessibilityViewTimer?.invalidate()
    }
    
//
//    NSTimer *removeAccOverlayTimer;
//    - (void)removeAccOverlayTimerCallback {
//        [AuthorizeAccessibilityView remove];
//    }
//    - (void)handleAccessibilityDisabledMessage {
//        [AuthorizeAccessibilityView add];
//        [removeAccOverlayTimer invalidate];
//    }
//    - (void)windowDidBecomeKey:(NSNotification *)notification {
//        /// Ask helper if accessibility enabled
//        [SharedMessagePort sendMessage:@"checkAccessibility" withPayload:nil expectingReply:NO];
//        /// Use a delay to prevent jankyness when window becomes key while app is requesting accessibility. Use timer so it can be stopped once Helper sends "I still have no accessibility" message
//        removeAccOverlayTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:NO block:^(NSTimer * _Nonnull timer) {
//            [self removeAccOverlayTimerCallback];
//        }];
//    }

}
