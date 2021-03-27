//
// --------------------------------------------------------------------------
// MFKeystrokeCaptureField.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import "Cocoa/Cocoa.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^CaptureHandler) (CGKeyCode keyCode, CGEventFlags flags);
typedef void (^CancelHandler) (void);
typedef void (^ClearButtonHandler) (void);

@interface MFKeystrokeCaptureField : NSTextField <NSTextFieldDelegate, NSControlTextEditingDelegate>

- (void)setupWithText:(NSString *)text captureHandler:(CaptureHandler)captureHandler cancelHandler:(CancelHandler)cancelHandler clearButtonHandler:(ClearButtonHandler)clearButtonHandler;
@end

NS_ASSUME_NONNULL_END
