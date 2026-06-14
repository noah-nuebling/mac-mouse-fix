---
name: logitech-hidpp-features
description: Comprehensive HID++ 2.0 Feature ID reference for implementing new Logitech mouse capabilities. Covers all 20+ feature IDs discovered from BetterMouse reverse engineering, with protocol details, function indices, packet formats, and implementation patterns for the Mac Mouse Fix codebase. Use when adding new Logitech hardware features like HiRes Scroll, Report Rate, Onboard Profiles, Thumbwheel control, or LED management.
---

# Logitech HID++ 2.0 Feature Implementation Guide

This skill provides a comprehensive reference for implementing Logitech HID++ 2.0 features in Mac Mouse Fix, based on reverse engineering of BetterMouse v1.6 and open-source references (Solaar, libratbag).

## HID++ 2.0 Protocol Fundamentals

### Packet Structure
All HID++ 2.0 communication uses 20-byte "long reports" (report ID `0x11`):

```
Byte 0: 0x11 (long report)
Byte 1: Device index (0xFF for probing, 0x01-0x06 for specific device)
Byte 2: Feature index (runtime-assigned, NOT the feature ID)
Byte 3: Function ID + Software ID (function << 4 | swId, swId = 0x0E in MMF)
Bytes 4-19: Parameters / Response data
```

### Feature Discovery Flow
```
1. Root Feature (index 0x00) → getFeature(featureID) → returns feature index
2. Use returned index in byte 2 for all subsequent calls
```

### Software ID Convention in MMF
The software ID is `0x0E`. Function indices become:
- Function 0 → `0x0E`
- Function 1 → `0x1E`
- Function 2 → `0x2E`
- Function 3 → `0x3E`
- Function 4 → `0x4E`
- Function 5 → `0x5E`
- Function 6 → `0x6E`

### Error Response
```
Byte 2: 0xFF (error marker)
Byte 3: Feature index that errored
Byte 4: Function + swId that errored
Byte 5: Error code
```
Common error codes:
- `0x01` = Unknown
- `0x02` = Invalid argument
- `0x03` = Out of range
- `0x04` = Hardware busy (retry after 200ms)
- `0x05` = Not allowed
- `0x06` = Invalid feature index
- `0x07` = Not supported
- `0x0B` = Invalid function ID

---

## Complete Feature ID Reference

### Core Features (Always Available)

#### 0x0000 — Root Feature
- **Function 0** (`0x0E`): `getFeature(featureID)` → Returns feature index
- Used by `lookupFeature()` in `LogitechCIDActivator.m`

#### 0x0001 — Feature Set  
- **Function 0** (`0x0E`): `getCount()` → Total feature count
- **Function 1** (`0x1E`): `getFeatureID(index)` → Feature ID at index
- Used for device index probing in MMF

---

### Battery Features

#### 0x1000 — Battery Levels (Legacy)
- **Function 0** (`0x0E`): `getBatteryLevelStatus()`
  - Response: `[4]=level(0-100)`, `[5]=nextLevel`, `[6]=status`
  - Status: 0=discharging, 1-3=recharging levels, 4=charge_complete

#### 0x1001 — Battery Voltage ⭐ NEW
- **Function 0** (`0x0E`): `getBatteryVoltage()`
  - Response: `[4-5]=voltage_mV(uint16 BE)`, `[6]=flags`
  - Flags bit 7: external power, bits 0-3: status
- **Conversion**: Approximate percentage from voltage lookup table:
  ```
  4186mV=100%, 4067mV=90%, 3989mV=80%, 3922mV=70%,
  3859mV=60%, 3811mV=50%, 3778mV=40%, 3756mV=30%,
  3726mV=20%, 3666mV=10%, 3500mV=5%, 3300mV=1%
  ```
- **When to use**: Fallback for devices lacking 0x1004 and 0x1000

#### 0x1004 — Unified Battery (Modern)
- **Function 0** (`0x0E`): `getCapabilities()`
  - Response: `[4]=levels_supported_flags`, `[5]=flags`
- **Function 1** (`0x1E`): `getStatus()`
  - Response: `[4]=stateOfCharge(0-100)`, `[5]=batteryLevel`, `[6]=chargingStatus`
  - ChargingStatus: 0=discharging, 1=charging, 2=slow_charging, 3=complete, 4=error
- **Already implemented in MMF** ✅

---

### Button Control Features

#### 0x1B04 — ReprogControlsV4
- **Already implemented in MMF** ✅
- Function 0: `getCount()` → Number of CIDs
- Function 1: `getCidInfo(index)` → CID, TID, flags for each control
- Function 3: `setCidReporting(cid, flags)` → Divert/persist a CID

#### 0x8110 — Mouse Button Spy ⭐ NEW
- **Function 0** (`0x0E`): `getButtonCount()` → Number of buttons
- **Function 1** (`0x1E`): `startSpy()` → Enable button event monitoring
- **Function 2** (`0x2E`): `stopSpy()` → Disable monitoring
- **Notifications**: Button press/release events via unsolicited reports
- **Use case**: Debugging button recognition, capturing unknown button CIDs

---

### Scroll Wheel Features

#### 0x2110 — SmartShift Basic
- **Already implemented in MMF** ✅
- Function 1: `getStatus()` → mode (0=ratchet, 1=freespin, 2=smartshift)
- Function 2: `setStatus(mode)` → Set wheel mode

#### 0x2111 — SmartShift Enhanced
- **Already implemented in MMF** ✅
- Function 0: `getCapabilities()` → wheelMode, autoShift, threshold, torque
- Function 1: `getStatus/setStatus()` → Full state with torque parameter

#### 0x2121 — HiRes Scroll Wheel ⭐ NEW
High-resolution scrolling mode that outputs much denser ticks (typically 8x).

- **Function 0** (`0x0E`): `getWheelCapability()`
  - Response: `[4]=multiplier`, `[5]=capabilities_flags`
  - `capabilities_flags` bit 0: has invert
  - `capabilities_flags` bit 2: has ratchet switch
  - `multiplier`: typically 8 (8x resolution)

- **Function 1** (`0x1E`): `getWheelMode()`
  - Response: `[4]=mode_flags`
  - Bit 1: invert direction
  - Bit 2: hi-res mode enabled
  - Bit 3: analytics reporting (ignore)

- **Function 2** (`0x2E`): `setWheelMode(flags)`
  - Packet: `[4]=mode_flags`
  - To enable HiRes: set bit 2 = 1 AND bit 3 = 1 (valid bit) → `0x0C`
  - To disable HiRes: set bit 2 = 0 AND bit 3 = 1 (valid bit) → `0x08`

- **Implementation pattern**:
  ```objc
  // In MFCIDDeviceState:
  uint8_t featHiResWheel;  // 0x2121
  
  // In activateDevice():
  s->featHiResWheel = lookupFeature(s, 0x2121);
  
  // Restore saved setting:
  NSNumber *savedHiRes = (NSNumber *)config(@"Pointer.logitechHiResWheel");
  if (savedHiRes) [self setHiResWheelMode:[savedHiRes boolValue] forDevice:...];
  ```

- **BetterMouse properties**: `hasHiresWheel`, `hiResWheel`, `hiResFactor`, `hiResMultiplier`, `smoothEn`

---

### DPI Features

#### 0x2201 — Adjustable DPI
- **Already implemented in MMF** ✅

#### 0x2202 — Extended Adjustable DPI  
- **Already implemented in MMF** ✅

---

### Report Rate Features

#### 0x8060 — Report Rate ⭐ NEW
USB/wireless polling rate control.

- **Function 0** (`0x0E`): `getReportRateList()`
  - Response: `[4..11]` = supported rate indices (non-zero)
  - Index values: 1=125Hz, 2=250Hz, 3=500Hz, 4=1000Hz, 5=2000Hz, 6=4000Hz, 8=8000Hz
  - Parse until a 0x00 byte or end of payload

- **Function 2** (`0x2E`): `getReportRate()`
  - Response: `[4]` = current rate index

- **Function 3** (`0x3E`): `setReportRate(rateIndex)`
  - Packet: `[4]` = target rate index

- **Rate index → Hz mapping**:
  ```c
  static uint16_t rateIndexToHz(uint8_t idx) {
      switch(idx) {
          case 1: return 125;
          case 2: return 250;
          case 3: return 500;
          case 4: return 1000;
          case 5: return 2000;
          case 6: return 4000;
          case 8: return 8000;
          default: return 0;
      }
  }
  ```

#### 0x8061 — Extended Report Rate ⭐ NEW
Advanced report rate configuration (newer devices like Pro X Superlight 2).

- Same function indices as 0x8060 but may support additional rates
- Check for this feature as fallback when 0x8060 is absent

---

### Onboard Profile Features

#### 0x8100 — Onboard Profiles ⭐ NEW
Hardware profile management stored on device memory.

- **Function 0** (`0x0E`): `getDescription()`
  - Response: `[4]=memoryModel`, `[5]=profileFormat`, `[6]=macroFormat`
  - `memoryModel`: 1=RAM, 2=ROM, 3=ROM+RAM
  
- **Function 1** (`0x1E`): `setOnboardMode(mode)`
  - `[4]=1` → enable onboard profiles (device uses its own profiles)
  - `[4]=2` → disable onboard profiles (host software controls)
  
- **Function 2** (`0x2E`): `getActiveProfile()`
  - Response: `[4-5]` = profile page address, `[6]` = profile index

- **BetterMouse behavior**: When onboard profiles are enabled, profile-switching and preset buttons use their firmware functions. When disabled, those buttons become available for custom binding.

- **BetterMouse strings**: 
  > "Disable onboard profiles to release all those profile-switching & preset buttons for binding."

---

### Wireless & Connection Features

#### 0x1D4B — Wireless Device Status
- **Already implemented in MMF** ✅
- Broadcasts connection/disconnection events

#### 0x40A3 — Multi-Host ⭐ NEW
Multi-device host switching (for multi-channel mice/keyboards).

- **Function 0** (`0x0E`): `getHostCount()`
  - Response: `[4]` = number of host channels
- **Function 1** (`0x1E`): `getHostInfo(channelIdx)`
  - Response: channel status, paired host info
- **Function 2** (`0x2E`): `setCurrentHost(channelIdx)`
  - Switch to a different host channel

#### 0x4531 — Multi-Platform ⭐ NEW
OS-specific key behavior adjustment.

- **Function 0** (`0x0E`): `getCapabilities()`
  - Response: number of platforms, platform descriptors
- **Function 1** (`0x1E`): `getHostPlatform()`
  - Response: current platform ID
- **Function 2** (`0x2E`): `setHostPlatform(platformId)`
  - Platform IDs: 0=default, 1=macOS, 2=iOS, 3=Linux, 4=Windows, 6=ChromeOS, 7=Android

---

### Visual / LED Features

#### 0x1982 — Backlight ⭐ NEW (Keyboard Only)
Keyboard backlight brightness control.

- **Function 0**: getBacklightConfig()
- **Function 1**: setBacklightConfig(level)

#### 0x2150 — Color LED / RGB ⭐ NEW
LED zone color and effect control (gaming mice).

- **Function 0**: getInfo() → number of LED zones
- **Function 1**: getZoneInfo(zoneIdx)
- **Function 2**: setZoneEffect(zoneIdx, effect, color, ...)

---

## Adding a New Feature to MMF — Step by Step

### 1. Add feature index field to `MFCIDDeviceState`
```c
// In LogitechCIDActivator.m, inside the MFCIDDeviceState struct:
uint8_t featMyNewFeature;  // 0xXXXX
```

### 2. Probe the feature in `activateDevice()`
```c
s->featMyNewFeature = lookupFeature(s, 0xXXXX);
if (s->featMyNewFeature != 0) {
    DDLogInfo(@"LogitechCIDActivator: Found MyNewFeature index 0x%02X", s->featMyNewFeature);
}
```

### 3. Implement getter/setter methods
Use the same sibling-device-state lookup pattern:
```objc
- (BOOL)getMyNewFeatureState:(MyStruct *)outState forDevice:(IOHIDDeviceRef)device {
    MFCIDDeviceState *s = stateForDevice(device);
    if (!s) {
        NSString *name = (__bridge NSString *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
        if (name != nil) {
            for (NSValue *v in _states) {
                MFCIDDeviceState *otherS = (MFCIDDeviceState *)v.pointerValue;
                NSString *otherName = (__bridge NSString *)IOHIDDeviceGetProperty(otherS->device, CFSTR(kIOHIDProductKey));
                if ([name isEqualToString:otherName]) { s = otherS; break; }
            }
        }
    }
    if (!s || s->featMyNewFeature == 0) return NO;
    
    uint8_t pkt[20];
    memset(pkt, 0, 20);
    pkt[0] = kHIDPP_Long;
    pkt[1] = s->deviceIndex;
    pkt[2] = s->featMyNewFeature;
    pkt[3] = 0x0E; // Function 0
    
    if (sendAndWaitWithTimeout(s, pkt, 100) != kIOReturnSuccess) return NO;
    
    // Parse s->resp[4..] into outState
    return YES;
}
```

### 4. Add IPC handlers in `MFMessagePort.m`
```objc
// In the handler switch/if-else chain:
else if ([msg isEqualToString:@"getMyNewFeatureState"]) {
    // Query device, return NSDictionary
}
else if ([msg isEqualToString:@"setMyNewFeature"]) {
    // Apply setting, write to config
}
```

### 5. Add Device properties in `Device.h`
```objc
@property (nonatomic) BOOL supportsMyNewFeature;
@property (nonatomic) /* type */ myNewFeatureValue;
```

### 6. Add UI in `PointerTabController.swift`
```swift
// Poll in pollLogitechInfo():
if let state = MessagePort.send("getMyNewFeatureState") {
    // Update UI on main queue
}

// React to user action:
@objc func myFeatureToggled(_ sender: NSButton) {
    let enabled = sender.state == .on
    setConfig("Pointer.logitechMyNewFeature", enabled as NSNumber)
    MessagePort.send("setMyNewFeature", payload: NSNumber(value: enabled), waitForReply: false)
}
```

### 7. Restore volatile settings in `activateDevice()`
```c
if (s->featMyNewFeature != 0) {
    NSNumber *saved = (NSNumber *)config(@"Pointer.logitechMyNewFeature");
    if (saved != nil) {
        [[LogitechCIDActivator shared] setMyNewFeature:[saved boolValue] forDevice:s->device];
    }
}
```

---

## BetterMouse Device State Model Reference

From reverse engineering, BetterMouse tracks these per-device properties:

```swift
// MiceOpt / MiceNoUI class properties
struct DeviceState {
    // Capabilities
    var hasHiresWheel: Bool
    var hasThumbWheel: Bool
    var hasHaptic: Bool
    var hasPressure: Bool
    var isMouse: Bool
    var isDongle: Bool
    var isQuirkBtn: Bool
    var canChangePlatform: Bool
    
    // Battery
    var _hasInternalBattery: Bool
    var battery: Int           // percentage
    var isCharging: Bool
    var isBatteryOk: Bool
    var isBatteryPowered: Bool
    
    // DPI
    var dpiEn: Bool            // DPI control enabled
    var dpiIndex: Int          // Current DPI preset index
    var dpiList: [Int]         // Available DPI values
    var dpiRange: (Int, Int)   // Min/Max DPI
    
    // SmartShift
    var smartShiftSupported: Bool
    var ratchetMode: Bool      // Current ratchet state
    var torque: Int            // Torque value
    var torqueSupported: Bool  // Tunable torque
    
    // Scroll
    var hiResFactor: Int       // HiRes multiplier
    var hiResMultiplier: Int   // Applied multiplier
    var smoothEn: Bool         // Smooth scrolling enabled
    
    // Thumbwheel
    var thumbWheelLowRes: Bool
    var twDirInv: Bool         // Direction inverted
    var twSpeed: Int           // Scroll speed
    var twUsage: Int           // 0=hscroll, 1=vscroll, 2=zoom, 3=shortcuts
    
    // Feature discovery
    var featureMap: [UInt16: UInt8]  // featureID → featureIndex
    var featureCompleted: Bool       // Discovery complete
    var featInQuest: UInt16          // Currently probing feature
    
    // Connection
    var _dongle: Any?          // Associated dongle/receiver
    var reportDescSum: String  // HID descriptor summary
    
    // CID state
    var _cid: [UInt16]         // Known CIDs
    var _cidHi: [UInt16]       // Highlighted CIDs in UI
}
```

---

## Debugging Tips

### Log Probes for New Features
| Feature | Log Grep Pattern |
|---|---|
| HiRes Wheel | `HiRes Scroll Wheel feature` |
| Report Rate | `Report Rate feature` |
| Onboard Profile | `Onboard Profile` |
| Feature lookup failure | `lookupFeature.*not found` |
| Packet errors | `sendAndWait received error packet` |
| Reconnect restore | `activateDevice applying saved` |

### Common Pitfalls
1. **Feature index ≠ Feature ID**: Always use `lookupFeature()`, never hardcode indices
2. **Volatile settings**: ALL Logitech hardware settings reset on wireless reconnect / sleep / replug
3. **Main thread only**: All HID++ communication must be on the main thread
4. **Sibling device**: Use the product-name-based fallback pattern for `stateForDevice()`
5. **0x8060 rate indices**: They are NOT Hz values — use the mapping table
6. **HiRes mode bit**: Bit 2 sets the mode, bit 3 is the "valid" flag — both must be set
