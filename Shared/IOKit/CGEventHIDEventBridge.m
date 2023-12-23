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

@implementation CGEventHIDEventBridge

/// MARK: CGEvent -> HIDEvent

/// Convenience wrapper
HIDEvent *CGEventGetHIDEvent(CGEventRef cgEvent) {
    
    if (cgEvent == NULL) {
        assert(false);
    }
    
    return (__bridge_transfer HIDEvent *)CGEventCopyIOHIDEvent(cgEvent);
}

/// External CGEvent -> HIDEvent function
extern IOHIDEventRef CGEventCopyIOHIDEvent(CGEventRef); /// Doesnt seem to work for mouseDragged events. -> Investigate!

/// MARK: HIDEvent -> CGEvent

/// Convenience wrapper
void CGEventSetHIDEvent(CGEventRef cgEvent, HIDEvent *hidEvent) {
    
    return CGEventSetIOHIDEvent(cgEvent, (__bridge IOHIDEventRef)hidEvent);
}

/// Defining our own IOHIDEvent -> CGEvent function, because we can't find an external one. (See header)
void CGEventSetIOHIDEvent(CGEventRef cgEvent, IOHIDEventRef iohidEvent) {
    
    if (cgEvent == NULL) {
        assert(false);
    }
    if (iohidEvent == NULL) {
        assert(false);
    }
    
    CFRetain(iohidEvent);
    /// ^ When we just stored HIDEvent * instead of IOHIDEventRef we needed to retain here. That's because CFRelease(cgEvent) also releases the embedded embedded IOHIDEventRef to be released. Now that we're storing IOHIDEventRef I'm not sure if this still works.
    
    void *resultHIDPtr = (void *)cgEvent;
    
    applyOffset(&resultHIDPtr, 0x18); /// Shift
    resultHIDPtr = *(void **)resultHIDPtr; /// Dereference
    applyOffset(&resultHIDPtr, 0xd0); /// Shift
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
