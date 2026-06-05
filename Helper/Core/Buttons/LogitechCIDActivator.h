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
#import <Foundation/Foundation.h>
#import <IOKit/hid/IOHIDLib.h>

typedef struct {
    uint8_t  wheelMode;    // 0 = Freespin, 1 = Ratchet
    uint8_t  autoShift;    // 0 = off, 1 = on
    uint8_t  threshold;    // 1 ~ 100
    uint8_t  torque;       // 1 ~ 100
    BOOL     supportsTunableTorque;
} LogitechSmartShiftState;

typedef struct {
    uint16_t currentDpi;
    uint16_t defaultDpi;
    uint16_t minDpi;
    uint16_t maxDpi;
    uint16_t step;
} LogitechDPICapabilities;

typedef struct {
    BOOL    supported;        // Device supports HiRes wheel
    BOOL    hiResEnabled;     // Current HiRes mode state
    uint8_t multiplier;       // Resolution multiplier (typically 8)
    BOOL    hasRatchetSwitch; // Has physical ratchet/free switch
} LogitechHiResWheelState;

typedef struct {
    uint8_t  currentRate;    // Current report rate index
    uint8_t  rateCount;      // Number of supported rates
    uint16_t rates[8];       // Supported rate values in Hz (e.g. 125, 250, 500, 1000)
} LogitechReportRateInfo;

@class Device;

@interface LogitechCIDActivator : NSObject

+ (instancetype)shared;

/// Call when a new device is attached. Activates CID diversion if the device
/// is a Logitech mouse with ReprogControlsV4 support.
- (void)handleDeviceAttached: (IOHIDDeviceRef)device;

/// Call when a device is removed. Cleans up state for that device.
- (void)handleDeviceRemoved: (IOHIDDeviceRef)device;

/// Queries and updates the cached Logitech battery percentage and native DPI.
- (void)queryBatteryAndDPIForDevice:(Device *)device;

/// Manually trigger re-activation of the specified IOHIDDevice.
- (void)reactivateDeviceWithIOHIDDevice:(IOHIDDeviceRef)device;

/// Toggle the SmartShift mode (between Ratchet and Freespin) for the device.
- (BOOL)toggleSmartShiftForDevice:(IOHIDDeviceRef)device;

/// Returns YES if any currently attached device has been confirmed to support SmartShift (0x2111/0x2110).
- (BOOL)anyAttachedDeviceSupportsSmartShift;

/// Logitech Fine Settings control
- (BOOL)getSmartShiftState:(LogitechSmartShiftState *)outState forDevice:(IOHIDDeviceRef)device;
- (BOOL)setSmartShiftState:(LogitechSmartShiftState)state forDevice:(IOHIDDeviceRef)device;
- (BOOL)getDPICapabilities:(LogitechDPICapabilities *)outCaps forDevice:(IOHIDDeviceRef)device;
- (BOOL)setDpi:(uint16_t)dpi forDevice:(IOHIDDeviceRef)device;

/// HiRes Scroll Wheel control (feature 0x2121)
- (BOOL)getHiResWheelState:(LogitechHiResWheelState *)outState forDevice:(IOHIDDeviceRef)device;
- (BOOL)setHiResWheelMode:(BOOL)enabled forDevice:(IOHIDDeviceRef)device;

/// Firmware-level scroll direction control via 0x2121 setWheelMode.
/// Sets the invert flag in firmware so scroll direction survives HiRes mode toggles.
/// @param inverted YES to invert scroll direction, NO for normal
- (BOOL)setFirmwareScrollDirection:(BOOL)inverted forDevice:(IOHIDDeviceRef)device;

/// Report Rate control (feature 0x8060 / 0x8061)
- (BOOL)getReportRateInfo:(LogitechReportRateInfo *)outInfo forDevice:(IOHIDDeviceRef)device;
- (BOOL)setReportRate:(uint8_t)rateIndex forDevice:(IOHIDDeviceRef)device;

@end

