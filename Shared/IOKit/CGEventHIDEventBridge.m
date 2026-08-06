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

/// IOHIDEvent -> CGEvent.
///     We prefer Apple's own private `SLEventSetIOHIDEvent` (SkyLight), resolved at runtime via `dlsym`.
///     We keep our hand-rolled offset-based writer below as a fallback.
///
///     Why: Our hand-rolled writer stores the `IOHIDEventRef` into the opaque `CGEvent`/`CGSEventRecord`
///     struct using hardcoded offsets (`0x18` / `0xd0`). Those offsets are not part of any stable ABI, so a
///     `CGEvent` layout change can make us write the pointer to the wrong address – the `IOHIDEvent` then
///     never reaches Dock and gesture simulation silently breaks. This is what happened on macOS 27
///     ("Golden Gate"): synthetic dock swipes (Switch Spaces, Mission Control, Show Desktop, Launchpad) stopped
///     working. See issue #1919 (and #1871, #1873, #1892 …) and the exploration in `Tests/FixDockSwipes.m`,
///     which concluded that `SLEventSetIOHIDEvent` is the working path there.
///
///     `SLEventSetIOHIDEvent` exists on older macOS too, so preferring it is backwards-compatible and needs no
///     version gate. We resolve it with `dlsym` rather than link `SkyLight.framework` so there is no link-time
///     dependency (safer for a potential Mac App Store variant) and we degrade gracefully to the offset writer
///     if the symbol ever disappears.
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

    /// Preferred path: Apple's private SLEventSetIOHIDEvent (SkyLight)
    static void (*sl_setIOHIDEvent)(CGEventRef, IOHIDEventRef) = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void *skylight = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY);
        if (skylight != NULL) {
            sl_setIOHIDEvent = (void (*)(CGEventRef, IOHIDEventRef))dlsym(skylight, "SLEventSetIOHIDEvent");
        }
    });
    if (sl_setIOHIDEvent != NULL) {
        sl_setIOHIDEvent(cgEvent, iohidEvent);
        return;
    }

    /// Fallback: hand-rolled offset writer (original implementation)

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
