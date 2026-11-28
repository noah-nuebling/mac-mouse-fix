//
// --------------------------------------------------------------------------
// CGEventHIDEventBridge.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "CGEventHIDEventBridge.h"
@import CoreGraphics.CGEvent;
#import <dlfcn.h>

/// Forward declarations for helpers defined later in this file
void CGEventSetIOHIDEvent(CGEventRef cgEvent, IOHIDEventRef iohidEvent);
void setIOHIDEvent_ManualOffsets(CGEventRef cgEvent, IOHIDEventRef iohidEvent);
void applyOffset(void **ptr, uint8_t byteOffset);

@implementation CGEventHIDEventBridge

/// MARK: CGEvent -> HIDEvent

/// Convenience wrapper
HIDEvent *CGEventGetHIDEvent(CGEventRef cgEvent) {

    if (!cgEvent) {
        assert(false);
        return nil;
    }
    
    return (HIDEvent *)CFBridgingRelease(CGEventCopyIOHIDEvent(cgEvent));
}

/// External CGEvent -> HIDEvent function
extern IOHIDEventRef CGEventCopyIOHIDEvent(CGEventRef); /// Doesnt seem to work for mouseDragged events. -> Investigate!

/// MARK: HIDEvent -> CGEvent

/// Convenience wrapper
void CGEventSetHIDEvent(CGEventRef cgEvent, HIDEvent *hidEvent) {
    return CGEventSetIOHIDEvent(cgEvent, (__bridge IOHIDEventRef)hidEvent);
}

/// IOHIDEvent -> CGEvent
///     We prefer Apple's own private `SLEventSetIOHIDEvent` (SkyLight.framework), resolved at runtime via dlsym.
///     If it can't be found, we fall back to our hand-rolled pointer-offset implementation.
///
///     Why prefer `SLEventSetIOHIDEvent`:
///         Our hand-rolled implementation (`setIOHIDEvent_ManualOffsets`) depends on the private memory layout of
///         `CGEvent`/`CGSEventRecord`, which Apple can change between OS versions. On macOS 27 (Golden Gate) Beta 3,
///         this layout changed: the hardcoded `0x18`/`0xd0` offsets no longer point at the embedded IOHIDEvent slot,
///         so the IOHIDEvent was written to the wrong address. This broke DockSwipe simulation, meaning the
///         `Spaces & Mission Control` action (switching Spaces / opening Mission Control via Click & Drag) stopped working.
///
///         `SLEventSetIOHIDEvent` doesn't depend on any hardcoded offsets and keeps working across OS versions.
///         (This is the same function the working exploration in `Tests/FixDockSwipes.m` used.)
///
///     Why dlsym instead of linking:
///         SkyLight.framework is a private framework, but it's already loaded into the process (via AppKit / CoreGraphics),
///         so we can resolve the symbol at runtime without adding it to the Xcode target. This avoids project-file changes
///         and gracefully degrades to the old implementation if the symbol ever disappears.
void CGEventSetIOHIDEvent(CGEventRef cgEvent, IOHIDEventRef iohidEvent) {
    
    /// Validate
    if (!cgEvent) {
        assert(false);
        return;
    }
    if (!iohidEvent) {
        assert(false);
        return;
    }
    
    /// Resolve `SLEventSetIOHIDEvent` once
    typedef void (*SLEventSetIOHIDEventFuncType)(CGEventRef, IOHIDEventRef);
    static SLEventSetIOHIDEventFuncType SLEventSetIOHIDEventFunc = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SLEventSetIOHIDEventFunc = (SLEventSetIOHIDEventFuncType)dlsym(RTLD_DEFAULT, "SLEventSetIOHIDEvent");
    });
    
    /// Use Apple's function if available
    ///     Note: We don't `CFRetain(iohidEvent)` here – unlike our manual implementation, `SLEventSetIOHIDEvent`
    ///     manages the retain/release of the embedded event itself.
    if (SLEventSetIOHIDEventFunc != NULL) {
        SLEventSetIOHIDEventFunc(cgEvent, iohidEvent);
        return;
    }
    
    /// Fallback: hand-rolled implementation
    setIOHIDEvent_ManualOffsets(cgEvent, iohidEvent);
}

/// Hand-rolled IOHIDEvent -> CGEvent implementation, kept as a fallback.
///     Fragile: depends on the private memory layout of CGEvent/CGSEventRecord (hardcoded offsets), which changes between OS versions.
void setIOHIDEvent_ManualOffsets(CGEventRef cgEvent, IOHIDEventRef iohidEvent) {
    
    /// Retain
    ///     CFRelease(cgEvent) also releases the embedded IOHIDEventRef
    ///     Update: [Apr 2025] ... that means if we're replacing an existing IOHIDEventRef here it might get leaked.
    CFRetain(iohidEvent);
    
    /// Get ptr
    void *resultHIDPtr = (void *)cgEvent;
    applyOffset(&resultHIDPtr, 0x18); /// Shift || Update: [Apr 2025] SLSIsEventMatchingSymbolicHotKey() disassembly might suggest that 0x18 points to a CGSEventRecord
    resultHIDPtr = *(void **)resultHIDPtr; /// Dereference
    applyOffset(&resultHIDPtr, 0xd0); /// Shift
    
    /// Store IOHIDEvent
    *(IOHIDEventRef *)resultHIDPtr = iohidEvent; /// Store pointer to iohidEvent
}

/// MARK: Helper

/// applyOffset()
/// Used to emulate the immediate offset we see in the LDR instruction (ARM assembly)
///
/// Takes a (pointer to a) pointer `ptr` as well as an offset `byteOffset`.
/// Shifts (the pointer pointed to by) `ptr` by an offset of `byteOffset` bytes before returning.
///
/// The "immediate offset" in the LDR instruction is also an offset in bytes. That's why this is helpful for recreating assembly code involving the LDR instruction.
///
/// LDR only supports positive offsets between 0 and 31*4 = 124. That's why we chose uint8_t for the `byteOffset`. We could make it bigger though.
///
/// See:  https://developer.arm.com/documentation/dui0068/b/Thumb-Instruction-Reference/Thumb-memory-access-instructions/LDR-and-STR--immediate-offset

void applyOffset(void **ptr, uint8_t byteOffset) {
    *ptr = ((uint8_t *)*ptr) + byteOffset;
}

/// MARK: Old

CGEventRef MFCGEventCreateWithIOHIDEvent_Original(HIDEvent *hidEvent) {
    
    CGEventRef result = CGEventCreate(NULL);
    uint8_t *bytePtr = (uint8_t *)result;
    uint8_t *bytePtr2 = (uint8_t *)*((uint64_t *)(bytePtr + 0x18));
    uint8_t *bytePtr3 = (bytePtr2 + 0xd0);
    uint64_t *resultHIDPtr = (uint64_t *)bytePtr3;
    *resultHIDPtr = (uint64_t)hidEvent;
    
    return result;
}

@end
