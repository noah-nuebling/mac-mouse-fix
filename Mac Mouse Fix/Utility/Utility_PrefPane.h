//
// --------------------------------------------------------------------------
// Utility_PrefPane.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>


NS_ASSUME_NONNULL_BEGIN

@interface Utility_PrefPane : NSObject
+ (NSArray *)subviewsForView:(NSView *)view withIdentifier:(NSString *)identifier;
+ (void)centerWindow:(NSWindow *)win atPoint:(NSPoint)pt;
+ (NSPoint)getCenterOfRect:(NSRect)rect;
+ (NSDictionary *)dictionaryWithOverridesAppliedFrom:(NSDictionary *)src to: (NSDictionary *)dst;
+ (BOOL)appIsInstalled:(NSString *)bundleID;
@end

NS_ASSUME_NONNULL_END
