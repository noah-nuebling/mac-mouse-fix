//
// --------------------------------------------------------------------------
// ModifiedDragOutputAddMode.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "ModifiedDragOutputAddMode.h"
#import "TransformationManager.h"

@implementation ModifiedDragOutputAddMode

/// Vars

static ModifiedDragState *_drag;
static NSDictionary *_addModePayload; /// Payload to send to the mainApp. Only used with modified drag of type kMFModifiedDragTypeAddModeFeedback.

/// Interface

+ (void)initializeWithDragState:(ModifiedDragState *)dragStateRef {
    
    _drag = dragStateRef;
    
    /// Prepare payload to send to mainApp during AddMode. See TransformationManager -> AddMode for context
    NSMutableDictionary *payload = _drag->effectDict.mutableCopy; /// Probably already mutable. See RemapSwizzler.
    [payload removeObjectForKey:kMFModifiedDragDictKeyType];
    _addModePayload = payload;
}

+ (void)handleBecameInUse {
    
    if (_addModePayload != nil) {
//        [TransformationManager sendAddModeFeedbackWithPayload:_addModePayload]; /// Remove this and make sendAddModeFeedbackWithPayload private.
        [TransformationManager concludeAddModeWithPayload:_addModePayload];
    } else {
        @throw [NSException exceptionWithName:@"InvalidAddModeFeedbackPayload" reason:@"_drag.addModePayload is nil. Something went wrong!" userInfo:nil]; /// Throw exception to cause crash
    }
}

+ (void)handleMouseInputWhileInUseWithDeltaX:(double)deltaX deltaY:(double)deltaY event:(nonnull CGEventRef)event {
    
    return;
}

+ (void)handleDeactivationWhileInUseWithCancel:(BOOL)cancelation {
    [TransformationManager disableAddModeWithPayload:_addModePayload];
}

+ (void)suspend {}
+ (void)unsuspend {}

@end
