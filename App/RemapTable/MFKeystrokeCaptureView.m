//
// --------------------------------------------------------------------------
// MFKeystrokeCaptureView.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "MFKeystrokeCaptureView.h"
#import "AppDelegate.h"

@interface MFKeystrokeCaptureView ()

@property IBOutlet NSButton *clearButton;

@end

@implementation MFKeystrokeCaptureView {
    
    CaptureHandler _captureHandler;
    CancelHandler _cancelHandler;
    ClearButtonHandler _clearButtonHandler;
//    NSEvent *capturedEvent;
}


- (void)setupWithText:(NSString *)text captureHandler:(CaptureHandler)captureHandler cancelHandler:(CancelHandler)cancelHandler clearButtonHandler:(ClearButtonHandler)clearButtonHandler {

#if DEBUG
    NSLog(@"Setting up keystroke capture view");
#endif

    self.delegate = self;
    self.string = text;
    _captureHandler = captureHandler;
    _cancelHandler = cancelHandler;
    _clearButtonHandler = clearButtonHandler;

    if (text == nil || [text isEqual:@""]) {
        self.clearButton.hidden = YES;

        // `setupWithCaptureHandler` is called from within tableView data loading function.
        //      Using dispatch_async to execute this after the tableView has loaded, otherwise crash.
        dispatch_async(dispatch_get_main_queue(), ^{
            [AppDelegate.mainWindow makeFirstResponder:self];
        });
} else
    self.clearButton.hidden = NO;
}

- (IBAction)handleClearButtonAction:(id)sender {
    _clearButtonHandler();
}

- (void)keyDown:(NSEvent *)event {
    NSLog(@"Keydown received!");
    CGEventRef e = event.CGEvent;
    CGKeyCode keyCode = CGEventGetIntegerValueField(e, kCGKeyboardEventKeycode);
    CGEventFlags flags = CGEventGetFlags(e);
    _captureHandler(keyCode, flags);
    [AppDelegate.mainWindow makeFirstResponder:nil];
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    NSLog(@"CONTROL THINGY CALLED");
    return NO;
}

- (void)controlTextDidChange:(NSNotification *)obj {

    if ([self.string isEqual:@""]) {
        self.clearButton.hidden = YES;
    } else {
        self.clearButton.hidden = NO;
    }
}


#pragma mark FirstResponderStatus handlers

- (void)handleBecameFirstResponder {
    
}

- (void)handleResignedFirstResponder {
    if (self.string == nil || [self.string isEqual:@""]) {
        _cancelHandler();
    }
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
  NSRectFill([self bounds]);
}
- (NSRect)focusRingMaskBounds {
  return [self bounds];
}

@end
