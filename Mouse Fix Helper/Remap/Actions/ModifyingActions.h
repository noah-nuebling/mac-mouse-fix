//
// --------------------------------------------------------------------------
// ModifyingActions.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ModifyingActions : NSObject

typedef enum {
    kMFModifiedInputActivationStateNone,
    kMFModifiedInputActivationStateInitialized,
    kMFModifiedInputActivationStateInUse,
} MFModifiedInputActivationState;

typedef enum {
    kMFActivationConditionTypeMouseButtonPressed,
} MFActivationConditionType;

typedef enum {
    kMFModifiedDragUsageAxisNone,
    kMFModifiedDragUsageAxisHorizontal,
    kMFModifiedDragUsageAxisVertical,
} MFModifiedDragUsageAxis;

struct ActivationCondition {
    MFActivationConditionType type;
    int64_t value;
};

+ (void)initializeModifiedInputsWithActionArray:(NSArray *)actionArray
                         withActivationCondtion:(struct ActivationCondition)activationCondition;

+ (void)deactivateAllInputModificationConditionedOnButton:(int64_t)button;

+ (BOOL)anyModifiedInputIsInUseForButton:(int64_t)button;

@end

NS_ASSUME_NONNULL_END
