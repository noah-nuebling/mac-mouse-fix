//
// --------------------------------------------------------------------------
// SharedUtility.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// Stub for RemapSwizzlerTests. Only declares what RemapSwizzler.m uses.

#import <Foundation/Foundation.h>
@interface SharedUtility : NSObject
+ (id)deepMutableCopyOf:(id)object;
+ (NSDictionary *)dictionaryWithOverridesAppliedFrom:(NSDictionary *)src to:(NSDictionary *)dst;
@end
