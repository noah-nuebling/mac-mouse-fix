//
// --------------------------------------------------------------------------
// MFKeystrokeCaptureField.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "MFKeystrokeCaptureField.h"

@implementation MFKeystrokeCaptureField


typedef void (^CaptureHandler) (CGKeyCode, CGEventFlags);
typedef void (^CancelHandler) (void);

CaptureHandler _captureHandler;
CancelHandler _cancelHandler;
NSEvent *capturedEvent;

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.delegate = self;
    }
    return self;
}

- (instancetype)initWithCaptureHandler:(CaptureHandler)captureHandler cancelHandler:(CancelHandler)cancelHandler {
    
    self = [self init]; // Not sure what I'm doing here
    
    _captureHandler = captureHandler;
    _cancelHandler = cancelHandler;
    
    return self;
}

- (BOOL)resignFirstResponder {
    
    _cancelHandler();
    
    return YES;
}

- (void)keyDown:(NSEvent *)event {
    NSLog(@"Keydown received!");
    CGEventRef e = event.CGEvent;
    _captureHandler(CGEventGetIntegerValueField(e, kCGKeyboardEventKeycode), (CGEventFlags)CGEventGetFlags(e));
}

@end
