//
// --------------------------------------------------------------------------
// MFNotificationOverlayController.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

/// What is this? Delete?

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface MFNotificationController : NSWindowController <NSWindowDelegate>
+ (void)attachNotificationWithMessage:(NSAttributedString *)message toWindow:(NSWindow *)window;
@end

NS_ASSUME_NONNULL_END
