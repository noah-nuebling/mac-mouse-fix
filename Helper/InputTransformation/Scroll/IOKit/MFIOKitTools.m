//
// --------------------------------------------------------------------------
// MFIOKitTools.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "MFIOKitTools.h"
@import CoreGraphics.CGEvent;

@implementation MFIOKitTools

CGEventRef MFCGEventCreateWithIOHIDEvent(HIDEvent *hidEvent) {
    
    CGEventRef result = CGEventCreate(NULL);
    uint8_t *bytePtr = (uint8_t *)result;
    uint8_t *bytePtr2 = (uint8_t *)*((uint64_t *)(bytePtr + 0x18));
    uint8_t *bytePtr3 = (bytePtr2 + 0xd0);
    int64_t *resultHIDPtr = (int64_t *)bytePtr3;
    *resultHIDPtr = (int64_t)hidEvent;
    
    return result;
}

@end
