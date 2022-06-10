//
// --------------------------------------------------------------------------
// CGEventHIDEventBridge.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "CGEventHIDEventBridge.h"
@import CoreGraphics.CGEvent;

@implementation CGEventHIDEventBridge

/// MARK: ----- CGEvent -> HIDEvent -----

/// External CGEvent -> HIDEvent function

extern HIDEvent *CGEventCopyIOHIDEvent(CGEventRef);

/// Wrapper for external CGEvent -> HIDEvent function
///
/// Disassembly shows that CGEventCopyIOHIDEvent() calls CFRetain() before returning the HIDEvent. But in ARC the retain count of HIDEvent is then increased *again* because we hold a pointer to it. That's why we CFRelease() the HIDEvent before returning it. Edit: It would probably do the same thing and make more sense to declare the return of CGEventCopyIOHIDEvent() as IOHIDEvent, and then use __bridge to cast to HIDEvent.

HIDEvent *CGEventGetIOHIDEvent(CGEventRef cgEvent) {
    
    if (cgEvent == NULL) {
        assert(false);
    }
    
    HIDEvent *hidEvent = CGEventCopyIOHIDEvent(cgEvent);
    
    if (hidEvent != nil) {
        CFRelease((__bridge CFTypeRef)hidEvent);
    }
    
    return hidEvent;
}

/// MARK: ----- HIDEvent -> CGEvent -----

/// Defining our own HIDEvent -> CGEvent function, because we can't find an external one.
CGEventRef CGEventCreateWithIOHIDEvent(HIDEvent *hidEvent) {
    
    if (hidEvent == nil) {
        assert(false);
    }
    
    CFRetain((__bridge CFTypeRef)hidEvent);
    /// Releasing the cgEvent will release the embedded hidEvent as well. That's why we need to retain it here.
    
    CGEventRef cgEvent = CGEventCreate(NULL);
    
    void *resultHIDPtr = (void *)cgEvent;
    
    applyOffset(&resultHIDPtr, 0x18); /// Shift
    resultHIDPtr = *(void **)resultHIDPtr; /// Dereference
    applyOffset(&resultHIDPtr, 0xd0); /// Shift
    *(HIDEvent *__weak *)resultHIDPtr = hidEvent; /// Store pointer to hidEvent. Not sure whether to use '__strong' here, or if there might be memory issues.
    
    return cgEvent;
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
