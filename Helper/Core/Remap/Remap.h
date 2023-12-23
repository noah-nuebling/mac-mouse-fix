//
// --------------------------------------------------------------------------
// Remap.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import "ButtonInputReceiver.h"
#import "WannabePrefixHeader.h"

NS_ASSUME_NONNULL_BEGIN

@interface Remap : NSObject

@property (class, readonly) BOOL addModeIsEnabled;

+ (NSDictionary * _Nullable)modificationsWithModifiers:(NSDictionary *)modifiers MF_SWIFT_HIDDEN;
+ (id _Nullable)__SWIFT_UNBRIDGED_modificationsWithModifiers:(id)modifiers;

+ (void)reload;

+ (NSDictionary *)remaps MF_SWIFT_HIDDEN;
+ (id)__SWIFT_UNBRIDGED_remaps;

+ (BOOL)enableAddMode;
+ (BOOL)disableAddMode;
+ (void)sendAddModeFeedback:(NSDictionary *)payload MF_SWIFT_HIDDEN;
+ (void)__SWIFT_UNBRIDGED_sendAddModeFeedback:(id)payload;

@end

NS_ASSUME_NONNULL_END
