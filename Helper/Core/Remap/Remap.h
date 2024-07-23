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

+ (__DISABLE_SWIFT_BRIDGING(NSDictionary *) _Nullable)modificationsWithModifiers:(__DISABLE_SWIFT_BRIDGING(NSDictionary *))modifiers NS_REFINED_FOR_SWIFT;

+ (void)reload;

+ (__DISABLE_SWIFT_BRIDGING(NSDictionary *))remaps NS_REFINED_FOR_SWIFT;

+ (BOOL)enableAddMode;
+ (BOOL)disableAddMode;
+ (void)sendAddModeFeedback:(__DISABLE_SWIFT_BRIDGING(NSDictionary *))payload NS_REFINED_FOR_SWIFT;

@end

NS_ASSUME_NONNULL_END
