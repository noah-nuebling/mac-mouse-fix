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
#import "DisableSwiftBridging.h"

NS_ASSUME_NONNULL_BEGIN

@interface Remap : NSObject

@property (class, readonly) BOOL addModeIsEnabled;

+ (MF_SWIFT_UNBRIDGED(NSDictionary *) _Nullable)modificationsWithModifiers:(MF_SWIFT_UNBRIDGED(NSDictionary *))modifiers NS_REFINED_FOR_SWIFT;

+ (void)reload;

+ (MF_SWIFT_UNBRIDGED(NSDictionary *))remaps NS_REFINED_FOR_SWIFT;

+ (BOOL)enableAddMode;
+ (BOOL)disableAddMode;
+ (void)sendAddModeFeedback:(MF_SWIFT_UNBRIDGED(NSDictionary *))payload NS_REFINED_FOR_SWIFT;

@end

NS_ASSUME_NONNULL_END
