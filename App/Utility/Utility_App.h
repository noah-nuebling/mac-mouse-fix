//
// --------------------------------------------------------------------------
// Utility_App.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>


NS_ASSUME_NONNULL_BEGIN

@interface Utility_App : NSObject

+ (NSInteger)bundleVersion;
+ (NSString *)bundleVersionShort;

+ (void)centerWindow:(NSWindow *)win atPoint:(NSPoint)pt;
+ (void)openWindowWithFadeAnimation:(NSWindow *)window fadeIn:(BOOL)fadeIn fadeTime:(NSTimeInterval)time;
+ (NSPoint)getCenterOfRect:(NSRect)rect;
+ (BOOL)appIsInstalled:(NSString *)bundleID;
+ (NSImage *)tintedImage:(NSImage *)image withColor:(NSColor *)tint;
+ (CGFloat)actualTextViewWidth:(NSTextView *)textView;
+ (CGFloat)actualTextFieldWidth:(NSTextField *)textField;

@end

NS_ASSUME_NONNULL_END
