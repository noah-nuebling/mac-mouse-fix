//
// --------------------------------------------------------------------------
// HelperStateObjC.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import "WannabePrefixHeader.h"

NS_ASSUME_NONNULL_BEGIN

/// Define ConfigOverrideCondition dict keys
#define kConfigOverrideConditionKeyDisplayUnderMousePointer @"displayUnderMousePointer"
#define kConfigOverrideConditionKeyAppUnderMousePointer     @"appUnderMousePointer"
#define kConfigOverrideConditionKeyFrontmostApp             @"frontmostApp"
#define kConfigOverrideConditionKeyActiveDevice             @"activeDevice"
#define kConfigOverrideConditionKeyActiveProfile            @"activeProfile"

@interface HelperStateObjC : NSObject

+ (NSString * _Nullable)serializeApp:(NSRunningApplication * _Nonnull)app MF_SWIFT_HIDDEN;
+ (id _Nullable)__SWIFT_UNBRIDGED_serializeApp:(id _Nonnull)app;

@end

NS_ASSUME_NONNULL_END
