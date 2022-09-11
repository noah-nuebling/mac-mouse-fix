//
// --------------------------------------------------------------------------
// TransformationManager.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import "ButtonInputReceiver.h"

NS_ASSUME_NONNULL_BEGIN

@interface TransformationManager : NSObject

@property (class, readonly) BOOL addModeIsEnabled;

+ (void)reload;
+ (NSDictionary *)remaps;

+ (void)enableAddMode;
+ (void)disableAddMode;

+ (void)concludeAddModeWithPayload:(NSDictionary *)payload;
+ (void)disableAddModeWithPayload:(NSDictionary *)payload;
+ (void)sendAddModeFeedbackWithPayload:(NSDictionary *)payload;
+ (BOOL)addModePayloadIsValid:(NSDictionary *)payload;

+ (void)enableKeyCaptureMode;
+ (void)disableKeyCaptureMode;

@end

NS_ASSUME_NONNULL_END
