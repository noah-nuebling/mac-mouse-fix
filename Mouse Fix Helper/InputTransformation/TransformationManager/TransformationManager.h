//
// --------------------------------------------------------------------------
// TransformationManager.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import "ButtonInputReceiver_CG.h"

NS_ASSUME_NONNULL_BEGIN

@interface TransformationManager : NSObject
+ (MFEventPassThroughEvaluation)handleButtonTriggerWithButton:(int64_t)button triggerType:(MFActionTriggerType)triggerType level:(int64_t)level;
@end

NS_ASSUME_NONNULL_END
