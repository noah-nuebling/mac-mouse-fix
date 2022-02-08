//
// --------------------------------------------------------------------------
// ModifyingActions.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "Device.h"
#import <CoreGraphics/CoreGraphics.h>
//#import <Foundation/Foundation.h>
#import "Constants.h"
#import "VectorUtility.h"
#import "IOHIDEventTypes.h"

NS_ASSUME_NONNULL_BEGIN

/// Forward declaration
///     So that typedef works
@protocol ModifiedDragOutputPlugin;

/// Typedefs

typedef enum {
    kMFModifiedInputActivationStateNone,
    kMFModifiedInputActivationStateInitialized,
    kMFModifiedInputActivationStateInUse,
} MFModifiedInputActivationState;

typedef struct {
    
    CFMachPortRef eventTap;
    int64_t usageThreshold;
    
    NSDictionary *dict;
    
    MFStringConstant type;
    id<ModifiedDragOutputPlugin> outputPlugin;
    
    MFModifiedInputActivationState activationState;
    Device *modifiedDevice;
    
    CGPoint origin;
    Vector originOffset;
    CGPoint usageOrigin; /// Point at which the modified drag changed its activationState to inUse
    MFAxis usageAxis;
    IOHIDEventPhaseBits phase;
    
    dispatch_queue_t queue;
} ModifiedDragState;


/// Plugin Declaration

@protocol ModifiedDragOutputPlugin <NSObject>

+ (void)initializeWithDragState:(ModifiedDragState *)dragStateRef;
+ (void)handleBecameInUse;
+ (void)handleMouseInputWhileInUseWithDeltaX:(double)deltaX deltaY:(double)deltaY event:(CGEventRef)event;
+ (void)handleDeactivationWhileInUseWithCancel:(BOOL)cancel;

@end

/// Modified Drag Declaration

@interface ModifiedDrag : NSObject

+ (void)load_Manual;

+ (NSDictionary *)dict;
+ (void)initializeDragWithModifiedDragDict:(NSDictionary *)dict onDevice:(Device *)dev;

+ (void)modifiedScrollHasBeenUsed;
//+ (void)suspend;
+ (void)deactivate;
+ (void)deactivateWithCancel:(BOOL)cancel;

//+ (void)handleMouseInputWithDeltaX:(int64_t)deltaX deltaY:(int64_t)deltaY event:(CGEventRef _Nullable)event;
@end

NS_ASSUME_NONNULL_END
