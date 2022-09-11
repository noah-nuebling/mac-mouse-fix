//
// --------------------------------------------------------------------------
// ModifyingActions.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
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
    
    NSDictionary *effectDict;
    NSDictionary *initialModifiers;
    
    MFStringConstant type;
    id<ModifiedDragOutputPlugin> outputPlugin;
    
    MFModifiedInputActivationState activationState;
    Device *modifiedDevice;
    
    CFTimeInterval initTime;
    Boolean isSuspended;
    
    CGPoint origin;
    Vector originOffset;
    CGPoint usageOrigin; /// Point at which the modified drag changed its activationState to inUse
    MFAxis usageAxis;
    Boolean firstCallback;
    
    dispatch_queue_t queue;
    
} ModifiedDragState;


/// Plugin Declaration

@protocol ModifiedDragOutputPlugin <NSObject>

+ (void)initializeWithDragState:(ModifiedDragState *)dragStateRef;
+ (void)handleBecameInUse;
+ (void)handleMouseInputWhileInUseWithDeltaX:(double)deltaX deltaY:(double)deltaY event:(CGEventRef)event;
+ (void)handleDeactivationWhileInUseWithCancel:(BOOL)cancel;
+ (void)suspend; /// See OutputCoordinator
+ (void)unsuspend;

@end

/// Modified Drag Declaration

@interface ModifiedDrag : NSObject

+ (void)load_Manual;

+ (NSDictionary *)initialModifiers;
+ (CGEventTapProxy)tapProxy;
+ (void)initializeDragWithDict:(NSDictionary *)effectDict initialModifiers:(NSDictionary *)modifiers onDevice:(Device *)dev;

//+ (void)modifiedScrollHasBeenUsed;

+ (void (^ _Nullable)(void))suspend;
+ (void)deactivate;
+ (void)deactivateWithCancel:(BOOL)cancel;

//+ (void)handleMouseInputWithDeltaX:(int64_t)deltaX deltaY:(int64_t)deltaY event:(CGEventRef _Nullable)event;


CGPoint getRoundedPointerLocation(void); /// Making this public for testing. Remove.
@end

NS_ASSUME_NONNULL_END
