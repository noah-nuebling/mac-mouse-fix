//
// --------------------------------------------------------------------------
// ModifyingActions.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import "MFDevice.h"

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
    kMFAxisNone,
    kMFAxisHorizontal,
    kMFAxisVertical,
} MFAxis;

struct ActivationCondition {
    IOHIDDeviceRef activatingDevice;
    MFActivationConditionType type;
    int64_t value;
};

+ (void)initializeModifiedInputsWithActionArray:(NSArray *)actionArray
                         withActivationCondition:(struct ActivationCondition)activationCondition;

+ (void)deactivateAllInputModificationConditionedOnButton:(int64_t)button;

+ (BOOL)anyModifiedInputIsInUseForButton:(int64_t)button;


+ (void)handleMouseInputWithDeltaX:(int64_t)deltaX deltaY:(int64_t)deltaY;

@end

NS_ASSUME_NONNULL_END
