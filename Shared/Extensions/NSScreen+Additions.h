//
// --------------------------------------------------------------------------
// NSScreen+Additions.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSScreen (Additions)

+ (NSScreen * _Nullable)screenUnderMousePointerWithEvent:(CGEventRef _Nullable)event;
+ (NSScreen * _Nullable)screenWithDisplayID:(CGDirectDisplayID)displayID;
- (CGDirectDisplayID)displayID;

@end

NS_ASSUME_NONNULL_END
