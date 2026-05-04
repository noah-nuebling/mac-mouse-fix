//
// --------------------------------------------------------------------------
// LogitechCIDActivator.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Miguel Angelo in 2026
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//
// Activates Logitech HID++ 2.0 ReprogControlsV4 (feature 0x1B04) on attached
// Logitech devices so that extra buttons (thumb, tilt wheel, precision, side
// buttons) are diverted and reported as standard CGEvent mouse buttons that
// Mac Mouse Fix can remap.
//
// References:
//   - Solaar (pwr-Solaar/Solaar) hidpp20.py — flag byte "valid bit" pattern
//   - libratbag hidpp20.c — TID definitions and GetCidInfo parsing
//   - https://lekensteyn.nl/files/logitech/x1b04_specialkeysmsebuttons.html
//

#import <Foundation/Foundation.h>
#import <IOKit/hid/IOHIDDevice.h>

@interface LogitechCIDActivator : NSObject

+ (instancetype)shared;

/// Call when a new device is attached. Activates CID diversion if the device
/// is a Logitech mouse with ReprogControlsV4 support.
- (void)handleDeviceAttached: (IOHIDDeviceRef)device;

/// Call when a device is removed. Cleans up state for that device.
- (void)handleDeviceRemoved: (IOHIDDeviceRef)device;

@end
