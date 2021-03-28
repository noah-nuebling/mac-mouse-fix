//
// --------------------------------------------------------------------------
// MFKeystrokeCaptureView.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^CaptureHandler) (CGKeyCode keyCode, CGEventFlags flags);
typedef void (^CancelHandler) (void);
typedef void (^ClearButtonHandler) (void);

@interface MFKeystrokeCaptureTextView : NSTextView <NSTextViewDelegate>

- (void)setupWithCapturedKeyCode:(NSNumber *)keyCodeNS
           capturedModifierFlags:(NSNumber *)flagsNS
                  captureHandler:(CaptureHandler)captureHandler
                   cancelHandler:(CancelHandler)cancelHandler
              clearButtonHandler:(ClearButtonHandler)clearButtonHandler;

@property NSNumber *capturedKeyCode;
@property NSNumber *capturedModifierFlags;
@property BOOL empty;

@end

NS_ASSUME_NONNULL_END
