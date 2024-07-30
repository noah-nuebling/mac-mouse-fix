//
// --------------------------------------------------------------------------
// ToastController.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface ToastController : NSWindowController <NSWindowDelegate>

///
/// Prefer using Toasts.swift instead of using this directly
///     It's nice to have everything centralized in Toasts.swift for localization screenshots.
///

#define kMFToastDurationAutomatic -1.0
+ (void)attachNotificationWithMessage:(NSAttributedString *)message toWindow:(NSWindow *)window forDuration:(NSTimeInterval)showDuration;
+ (void)closeNotificationWithFadeOut;
+ (NSFont *)defaultFont;

@end

NS_ASSUME_NONNULL_END
