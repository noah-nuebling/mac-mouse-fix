//
// --------------------------------------------------------------------------
// ModifiedDragOutputAddMode.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "ModifiedDragOutputAddMode.h"
#import "Remap.h"

@implementation ModifiedDragOutputAddMode

/// Vars

static ModifiedDragState *_drag;
static NSDictionary *_addModePayload; /// Payload to send to the mainApp. Only used with modified drag of type kMFModifiedDragTypeAddModeFeedback.
static BOOL _didConclude;

/// Interface

+ (void)initializeWithDragState:(ModifiedDragState *)dragStateRef {
    
    _drag = dragStateRef;
    
    /// Prepare payload to send to mainApp during AddMode. See Remap -> AddMode for context
    NSMutableDictionary *payload = _drag->effectDict.mutableCopy; /// Probably already mutable. See RemapSwizzler.
    [payload removeObjectForKey:kMFModifiedDragDictKeyType];
    _addModePayload = payload;
    _didConclude = NO;
}

+ (void)handleBecameInUseWithEvent:(CGEventRef)event {
    
    return;
}

+ (void)handleMouseInputWhileInUseWithDeltaX:(double)deltaX deltaY:(double)deltaY event:(nonnull CGEventRef)event {
    
    if (!_didConclude) {
        if (_addModePayload != nil) {
            [Remap sendAddModeFeedback:_addModePayload];
            _didConclude = YES;
        } else {
            @throw [NSException exceptionWithName:@"InvalidAddModeFeedbackPayload" reason:@"_drag.addModePayload is nil. Something went wrong!" userInfo:nil]; /// Throw exception to cause crash
        }
    }
}

+ (void)handleDeactivationWhileInUseWithCancel:(BOOL)cancelation {
}

+ (void)suspend {}
+ (void)unsuspend {}

@end
