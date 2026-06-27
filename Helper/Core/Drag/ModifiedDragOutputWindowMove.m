//
// --------------------------------------------------------------------------
// ModifiedDragOutputWindowMove.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "ModifiedDragOutputWindowMove.h"
#import <ApplicationServices/ApplicationServices.h>

@implementation ModifiedDragOutputWindowMove

#pragma mark - Vars

static ModifiedDragState *_drag;
static AXUIElementRef _windowElement;

#pragma mark - Interface

+ (void)initializeWithDragState:(ModifiedDragState *)dragStateRef {
    _drag = dragStateRef;
    _windowElement = NULL;
}

+ (void)handleBecameInUse {
    /// Get the window under the mouse pointer via Accessibility API
    
    AXUIElementRef systemWide = AXUIElementCreateSystemWide();
    AXUIElementRef element = NULL;
    CGPoint mousePos = _drag->usageOrigin;
    
    AXUIElementCopyElementAtPosition(systemWide, mousePos.x, mousePos.y, &element);
    CFRelease(systemWide);
    
    if (!element) return;
    
    /// Walk up to find the window
    AXUIElementRef window = NULL;
    CFStringRef role = NULL;
    AXUIElementCopyAttributeValue(element, kAXRoleAttribute, (CFTypeRef *)&role);
    
    if (role && CFStringCompare(role, kAXWindowRole, 0) == kCFCompareEqualTo) {
        window = element;
        element = NULL;
    } else {
        /// Try to get the window attribute
        AXUIElementCopyAttributeValue(element, kAXWindowAttribute, (CFTypeRef *)&window);
    }
    
    if (role) CFRelease(role);
    if (element) CFRelease(element);
    
    _windowElement = window;
}

+ (void)handleMouseInputWhileInUseWithDeltaX:(double)deltaX deltaY:(double)deltaY event:(CGEventRef)event {
    
    if (!_windowElement) return;
    
    /// Get current window position
    CFTypeRef positionValue = NULL;
    AXUIElementCopyAttributeValue(_windowElement, kAXPositionAttribute, &positionValue);
    if (!positionValue) return;
    
    CGPoint position;
    AXValueGetValue(positionValue, kAXValueCGPointType, &position);
    CFRelease(positionValue);
    
    /// Apply delta
    position.x += deltaX;
    position.y += deltaY;
    
    /// Set new position
    AXValueRef newPosition = AXValueCreate(kAXValueCGPointType, &position);
    AXUIElementSetAttributeValue(_windowElement, kAXPositionAttribute, newPosition);
    CFRelease(newPosition);
}

+ (void)handleDeactivationWhileInUseWithCancel:(BOOL)cancel {
    if (_windowElement) {
        CFRelease(_windowElement);
        _windowElement = NULL;
    }
}

+ (void)suspend {
}

+ (void)unsuspend {
}

@end
