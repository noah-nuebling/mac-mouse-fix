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
    kMFModifiedInputStateNone,
    kMFModifiedInputStateInitialized,
    kMFModifiedInputStateActive,
} MFModifiedInputState;

typedef enum {
    kMFModifiedDragActivationAxisNone,
    kMFModifiedDragActivationAxisHorizontal,
    kMFModifiedDragActivationAxisVertical,
} MFModifiedDragActivationAxis;

+ (void)initializeModifiedInputWithActionArray:(NSArray *)actionArray onButton:(int)button;

+ (void)deactivateAllInputModification;

@end

NS_ASSUME_NONNULL_END
