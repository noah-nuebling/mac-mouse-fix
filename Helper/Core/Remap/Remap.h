//
// --------------------------------------------------------------------------
// Remap.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import "ButtonInputReceiver.h"

NS_ASSUME_NONNULL_BEGIN

@interface Remap : NSObject

@property (class, readonly) BOOL addModeIsEnabled;

+ (NSDictionary *)modificationsWithModifiers:(NSDictionary *)modifiers;

+ (void)reload;
+ (NSDictionary *)remaps;

+ (void)enableAddMode;
+ (void)disableAddMode;
+ (void)concludeAddModeWithPayload:(NSDictionary *)payload;

@end

NS_ASSUME_NONNULL_END
