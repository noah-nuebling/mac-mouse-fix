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

@interface KeyCaptureView : NSTextView <NSTextViewDelegate>

- (void)setupWithCaptureHandler:(CaptureHandler)captureHandler
                  cancelHandler:(CancelHandler)cancelHandler;

@end

NS_ASSUME_NONNULL_END
