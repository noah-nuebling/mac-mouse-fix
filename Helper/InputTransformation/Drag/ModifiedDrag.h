//
// --------------------------------------------------------------------------
// ModifyingActions.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import "MFDevice.h"
#import "Constants.h"

NS_ASSUME_NONNULL_BEGIN

@interface ModifiedDrag : NSObject

typedef enum {
    kMFModifiedInputActivationStateNone,
    kMFModifiedInputActivationStateInitialized,
    kMFModifiedInputActivationStateInUse,
} MFModifiedInputActivationState;

typedef enum {
    kMFAxisNone,
    kMFAxisHorizontal,
    kMFAxisVertical,
} MFAxis;

+ (void)load_Manual;

+ (void)initializeDragWithModifiedDragDict:(NSDictionary *)dict onDevice:(MFDevice *)dev;
+ (void)deactivate;

+ (void)handleMouseInputWithDeltaX:(int64_t)deltaX deltaY:(int64_t)deltaY event:(CGEventRef _Nullable)event;
@end

NS_ASSUME_NONNULL_END
