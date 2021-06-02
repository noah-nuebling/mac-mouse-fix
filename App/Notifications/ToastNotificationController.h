//
// --------------------------------------------------------------------------
// MFNotificationOverlayController.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface ToastNotificationController : NSWindowController <NSWindowDelegate>

typedef enum {
    kMFNotificationAlignmentTopMiddle,
    kMFNotificationAlignmentBottomRight,
    kMFNotificationAlignmentBottomMiddle,
} MFNotificationAlignment;

+ (void)attachNotificationWithMessage:(NSAttributedString *)message toWindow:(NSWindow *)window forDuration:(NSTimeInterval)showDuration;
+ (void)attachNotificationWithMessage:(NSAttributedString *)message toWindow:(NSWindow *)attachWindow forDuration:(NSTimeInterval)showDuration alignment:(MFNotificationAlignment)alignment;

+ (void)closeNotificationWithFadeOut;

@end

NS_ASSUME_NONNULL_END
