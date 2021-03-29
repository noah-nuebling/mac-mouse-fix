//
// --------------------------------------------------------------------------
// MFKeystrokeCaptureView.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "MFKeystrokeCaptureTextView.h"
#import "AppDelegate.h"
#import "UIStrings.h"

@interface MFKeystrokeCaptureTextView ()

@property IBOutlet NSButton *backgroundButton;

@end

@implementation MFKeystrokeCaptureTextView {
    
    CaptureHandler _captureHandler;
    CancelHandler _cancelHandler;
    
    id _localEventMonitor;
}

#pragma mark - Setup

- (void)setupWithCaptureHandler:(CaptureHandler)captureHandler
                   cancelHandler:(CancelHandler)cancelHandler {
    
#if DEBUG
    NSLog(@"Setting up keystroke capture view");
#endif
    
    
    self.delegate = self;
    _captureHandler = captureHandler;
    _cancelHandler = cancelHandler;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [AppDelegate.mainWindow makeFirstResponder:self];
    });
    // ^ This view is being drawn by the tableView. Using dispatch_async makes it execute after the tableView is done drawing preventing a crash
    
}

#pragma mark Drawing

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
}

- (void)drawEmptyAppearance {
    
    self.string = @"Enter keyboard shortcut";
    self.textColor = NSColor.placeholderTextColor;
    
    [self selectAll:nil];
}

#pragma mark FirstResponderStatus handlers

- (BOOL)becomeFirstResponder {

#if DEBUG
    NSLog(@"BECOME FIRST RESPONDER");
#endif
    
    BOOL superAccepts = [super becomeFirstResponder];
    
    if (superAccepts) {
        
        [self drawEmptyAppearance];
        
        _localEventMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:(NSEventMaskKeyDown | NSEventMaskFlagsChanged) handler:^NSEvent * _Nullable(NSEvent * _Nonnull event) {
            CGEventRef e = event.CGEvent;
            
            CGKeyCode keyCode = CGEventGetIntegerValueField(e, kCGKeyboardEventKeycode);
            CGEventFlags flags = CGEventGetFlags(e);
            
            
            self.textColor = NSColor.labelColor;
            
            if (event.type == NSEventTypeKeyDown) {
//                [AppDelegate.mainWindow makeFirstResponder:nil];
                self->_captureHandler(keyCode, flags); // This should undraw this view
                
            } else {
                // User is playing around with modifier keys
                
                NSString *modString = [UIStrings getKeyboardModifierString:flags];
                if (modString.length > 0) {
                    self.string = modString;
                } else {
                    [self drawEmptyAppearance];
                }
                
                
            }
            
            return nil;
        }];
    }
    
    return superAccepts;
}
/// This is called too often and at weird times (always right before the `becomeFirstResponder` call)
- (BOOL)resignFirstResponder {

#if DEBUG
    NSLog(@"RESIGN FIRST RESPONDER");
#endif
    
    BOOL superResigns = [super resignFirstResponder];

    if (superResigns) {
        [NSEvent removeMonitor:_localEventMonitor];
        _cancelHandler();
    }
    return superResigns;
}

@end
