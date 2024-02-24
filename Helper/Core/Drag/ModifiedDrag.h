//
// --------------------------------------------------------------------------
// ModifyingActions.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
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
//    NSDictionary *initialModifiers;
    
    bool naturalDirection; /// Content follows mouse movement
    
    MFStringConstant type;
    id<ModifiedDragOutputPlugin> outputPlugin;
    
    MFModifiedInputActivationState activationState;
//    Device *modifiedDevice;
    
    CFTimeInterval initTime;
    bool isSuspended;
    
    CGPoint origin;
    Vector originOffset;
    CGPoint usageOrigin; /// Point at which the modified drag changed its activationState to inUse
    MFAxis usageAxis;
    bool firstCallback;
    
    dispatch_queue_t queue;
    
} ModifiedDragState;


/// Plugin Declaration

@protocol ModifiedDragOutputPlugin <NSObject>

+ (void)initializeWithDragState:(ModifiedDragState *)dragStateRef;
+ (void)handleBecameInUseWithEvent:(CGEventRef)event;
+ (void)handleMouseInputWhileInUseWithDeltaX:(double)deltaX deltaY:(double)deltaY event:(CGEventRef)event;
+ (void)handleDeactivationWhileInUseWithCancel:(BOOL)cancel;
+ (void)suspend; /// See OutputCoordinator
+ (void)unsuspend;

@end

/// Modified Drag Declaration

@interface ModifiedDrag : NSObject

+ (void)activationStateWithCallback:(void (^)(MFModifiedInputActivationState))callback;

+ (void)load_Manual;

//+ (NSDictionary *)initialModifiers;
//+ (CGEventTapProxy)tapProxy;
+ (void)initializeDragWithDict:(NSDictionary *)effectDict;
+ (void)__SWIFT_UNBRIDGED_initializeDragWithDict:(id)effectDict;

//+ (void)modifiedScrollHasBeenUsed;

//+ (void (^ _Nullable)(void))suspend;

+ (void)deactivate;
+ (void)deactivateWithCancel:(BOOL)cancel;

//+ (void)handleMouseInputWithDeltaX:(int64_t)deltaX deltaY:(int64_t)deltaY event:(CGEventRef _Nullable)event;


CGPoint getRoundedPointerLocation(void); /// Making this public for testing. Remove.
@end

NS_ASSUME_NONNULL_END
