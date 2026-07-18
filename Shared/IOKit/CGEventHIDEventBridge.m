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
#import <dispatch/dispatch.h>
#import "Logging.h"
#import "PrivateFunctions.h"

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

/// Attaches an IOHIDEvent to a CGEvent.
///     The old implementation writes through hard-coded CGEvent struct offsets. Those offsets changed on macOS 27,
///     so use SkyLight's setter there and keep the old implementation only for older macOS versions.
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

    /// Use SkyLight's setter on macOS 27
    ///     `SLEventSetIOHIDEvent` copies the HID payload into the CGEvent. It doesn't take an extra retain on the
    ///     input object, so retaining here would leak one HIDEvent for every simulated gesture event.
    if (@available(macOS 27.0, *)) {
        typedef void (*SLEventSetIOHIDEventFunction)(CGEventRef, IOHIDEventRef);
        static SLEventSetIOHIDEventFunction slEventSetIOHIDEvent = NULL;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            slEventSetIOHIDEvent = (SLEventSetIOHIDEventFunction)MFLoadSymbol_native(kMFFrameworkSkyLight, @"SLEventSetIOHIDEvent");
        });

        if (slEventSetIOHIDEvent) {
            slEventSetIOHIDEvent(cgEvent, iohidEvent);
        } else {
            /// The offsets below are known to be invalid on macOS 27. Failing closed avoids writing through an
            /// unknown pointer if Apple ever removes or renames the private setter.
            DDLogError("CGEventSetIOHIDEvent: Couldn't resolve SLEventSetIOHIDEvent on macOS 27. Skipping the known-incompatible offset writer.");
        }
        return;
    }
    
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
