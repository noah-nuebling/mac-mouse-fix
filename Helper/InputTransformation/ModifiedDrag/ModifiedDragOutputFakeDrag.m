//
// --------------------------------------------------------------------------
// ModifiedDragOutputFakeDrag.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "ModifiedDragOutputFakeDrag.h"
#import "Utility_Transformation.h"
#import "SharedUtility.h"
#import "Utility_Helper.h"

@implementation ModifiedDragOutputFakeDrag

/// Vars

static ModifiedDragState *_drag;
static MFMouseButtonNumber _fakeDragButtonNumber; /// Button number. Only used with modified drag of type kMFModifiedDragTypeFakeDrag.

/// Interface

+ (void)initializeWithDragState:(ModifiedDragState *)dragStateRef {
    
    _drag = dragStateRef;
    
    _fakeDragButtonNumber = ((NSNumber *)_drag->dict[kMFModifiedDragDictKeyFakeDragVariantButtonNumber]).intValue;
}

+ (void)handleMouseInputWhileInitialized {
    
    [Utility_Transformation postMouseButton:_fakeDragButtonNumber down:YES];
}

+ (void)handleMouseInputWhileInUseWithDeltaX:(double)deltaX deltaY:(double)deltaY event:(CGEventRef)event {
    
    CGPoint location;
    if (event) {
        location = CGEventGetLocation(event); // I feel using `event` passed in from eventTap here makes things slighly more responsive that using `getPointerLocation()`
    } else {
        location = getPointerLocation();
    }
    CGMouseButton button = [SharedUtility CGMouseButtonFromMFMouseButtonNumber:_fakeDragButtonNumber];
    CGEventRef draggedEvent = CGEventCreateMouseEvent(NULL, kCGEventOtherMouseDragged, location, button);
    CGEventPost(kCGSessionEventTap, draggedEvent);
    CFRelease(draggedEvent);
}

+ (void)handleDeactivationWhileInUseWithCancel:(BOOL)cancelation {
    [Utility_Transformation postMouseButton:_fakeDragButtonNumber down:NO];
}

@end
