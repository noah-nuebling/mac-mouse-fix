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

@property IBOutlet NSButton *clearButton;
@property IBOutlet NSButton *backgroundButton;

@end

@implementation MFKeystrokeCaptureTextView {
    
    CaptureHandler _captureHandler;
    CancelHandler _cancelHandler;
    ClearButtonHandler _clearButtonHandler;
    
    id _localEventMonitor;
}

@synthesize empty = _empty;

- (BOOL)empty {
    return _empty;
}
- (void)setEmpty:(BOOL)empty {
    _empty = empty;
    self.clearButton.hidden = empty;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
}

- (void)setUIToModel {
    if (self.capturedKeyCode == nil || self.capturedModifierFlags == nil) {
        self.empty = YES;
        
        // `setupWithCaptureHandler` is called from within tableView data loading function.
        //      Using dispatch_async to execute this after the tableView has loaded, otherwise crash.
        dispatch_async(dispatch_get_main_queue(), ^{
            [AppDelegate.mainWindow makeFirstResponder:self];
        });
        self.string = @"Enter keyboard shortcut";
        self.textColor = NSColor.placeholderTextColor;
        
    } else {
        self.empty = NO;
        self.string = [UIStrings getStringForKeyCode:self.capturedKeyCode.unsignedIntValue flags:self.capturedModifierFlags.unsignedLongValue];
        self.textColor = NSColor.labelColor;
    }
    
    if ([AppDelegate.mainWindow.firstResponder isEqual:self]) {
        [self selectAll:nil];
    }
}

- (void)setupWithCapturedKeyCode:(NSNumber *)keyCode
            capturedModifierFlags:(NSNumber *)flags
                  captureHandler:(CaptureHandler)captureHandler
                   cancelHandler:(CancelHandler)cancelHandler
              clearButtonHandler:(ClearButtonHandler)clearButtonHandler {
    
#if DEBUG
    NSLog(@"Setting up keystroke capture view");
#endif
    
    self.capturedKeyCode = keyCode;
    self.capturedModifierFlags = flags;
    
    self.delegate = self;
    _captureHandler = captureHandler;
    _cancelHandler = cancelHandler;
    _clearButtonHandler = clearButtonHandler;
    
    self.wantsLayer = YES;
    self.layer.cornerRadius = 5.0;
    
    [self setUIToModel];
    
}

- (IBAction)handleClearButtonAction:(id)sender {
    _clearButtonHandler();
}

//- (void)keyDown:(NSEvent *)event {
//    NSLog(@"KEYDOWN");
//}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    NSLog(@"CONTROL THINGY CALLED");
    return NO;
}

- (void)controlTextDidChange:(NSNotification *)obj {
    
    if ([self.string isEqual:@""]) {
        self.empty = YES;
    } else {
        self.empty = NO;
    }
}


#pragma mark FirstResponderStatus handlers

- (void)handleBecameFirstResponder {
    
    [AppDelegate.mainWindow makeFirstResponder:self.backgroundButton];
    [self setUIToModel];
    
    _localEventMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:(NSEventMaskKeyDown | NSEventMaskFlagsChanged) handler:^NSEvent * _Nullable(NSEvent * _Nonnull event) {
        NSLog(@"Keydown received! Type: %lu", (unsigned long)event.type);
        CGEventRef e = event.CGEvent;
        
        CGKeyCode keyCode = CGEventGetIntegerValueField(e, kCGKeyboardEventKeycode);
        CGEventFlags flags = CGEventGetFlags(e);
        
        NSLog(@"CAPTURED KEYCODE: %@", self->_capturedKeyCode);
        
        self.textColor = NSColor.labelColor;
        
        if (event.type == NSEventTypeKeyDown) {
            self.empty = NO;
            [AppDelegate.mainWindow makeFirstResponder:nil];
//            [self handleResignedFirstResponder];
            
            self->_capturedKeyCode = @(keyCode); // Not sure if neccessary
            self->_capturedModifierFlags = @(flags); // Not sure if necessary
            
            [self setUIToModel];
            
            self->_captureHandler(keyCode, flags);
            
        } else {
            // User is playing around with modifier keys
            
            NSString *modString = [UIStrings getKeyboardModifierString:flags];
            if (modString.length > 0) {
                self.string = modString;
            } else {
                [self setUIToModel];
            }
            
            
        }
        
        return nil;
    }];
}

- (void)handleResignedFirstResponder {
    if (self.string == nil || [self.string isEqual:@""]) {
        _cancelHandler();
    }
    
    [NSEvent removeMonitor:_localEventMonitor];
}

#pragma mark FirstResponderStatus Helper functions

- (BOOL)becomeFirstResponder {

    [self handleBecameFirstResponder];
    
    BOOL superBOOL = [super becomeFirstResponder];

#if DEBUG
    NSLog(@"BECOME FIRST RESPONDER: %d", superBOOL);
#endif
    
    return superBOOL;
}
/// This is called too often and at weird times (always right before the `becomeFirstResponder` call)
- (BOOL)resignFirstResponder {
    
    [self handleResignedFirstResponder];

#if DEBUG
    NSLog(@"RESIGN FIRST RESPONDER");
#endif
    
    BOOL superBOOL = [super resignFirstResponder];

    return superBOOL;
}

#pragma mark - Draw focus ring

- (void)drawFocusRingMask {
  NSRectFill([self.backgroundButton bounds]);
}
- (NSRect)focusRingMaskBounds {
  return [self.backgroundButton bounds];
}

@end
