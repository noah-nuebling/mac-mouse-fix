//
// --------------------------------------------------------------------------
// TransformationManager.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import "ButtonInputReceiver.h"

NS_ASSUME_NONNULL_BEGIN

@interface TransformationManager : NSObject
+ (NSDictionary *)remaps;
+ (MFEventPassThroughEvaluation)handleButtonTriggerWithButton:(NSNumber *)button triggerType:(MFActionTriggerType)trigger clickLevel:(NSNumber *)level device:(NSNumber *)devID;
+ (BOOL)effectOfEqualOrGreaterLevelExistsForDevice:(NSNumber *)devID button:(NSNumber *)button level:(NSNumber *)level;
@end

NS_ASSUME_NONNULL_END
