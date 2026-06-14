---
name: logitech-device-management
description: Guide for implementing Logitech receiver management, device pairing, dongle identification, and multi-interface device matching. Covers Unifying, Bolt, and Lightspeed receiver protocols, Bluetooth manager integration, and the complete device lifecycle from discovery to disconnection. Use when adding receiver pairing UI, fixing device recognition issues, or implementing dongle-type-specific behaviors.
---

# Logitech Device Management & Receiver Pairing Guide

This skill covers receiver/dongle management, device pairing protocols, and multi-interface device matching for Logitech mice in Mac Mouse Fix.

## Receiver Types

| Type | USB VID:PID | Max Devices | Max Report Rate | Protocol |
|---|---|---|---|---|
| **Unifying** | 046D:C52B (6-dev), 046D:C532 (1-dev) | 6 | 125 Hz | HID++ 1.0 + 2.0 |
| **Bolt** | 046D:C548 | 6 | 1000 Hz | HID++ 2.0 (BLE-based) |
| **Lightspeed** | 046D:C539, C53A, etc. | 1 | 1000-4000 Hz | HID++ 2.0 |
| **Nano** (old) | 046D:C52F | 1 | 125 Hz | HID++ 1.0 only |

### Identifying Receiver Type (from BetterMouse)
BetterMouse uses a `DongleType` enum and `isDongle` flag:
```
isDongle       → true if the device is a receiver (not a mouse)
dongleType     → "Unifying" | "Bolt" | "Lightspeed"
paired         → whether a device is currently paired
pairedCount    → number of paired devices (for multi-device receivers)
pairName       → name of the paired device
pairing        → whether pairing mode is active
connectionType → connection method
connected      → whether a paired device is currently connected
```

### Detection in macOS
Receivers appear as IOHIDDevice instances with:
- VendorID = `0x046D`
- PrimaryUsagePage ≥ `0xFF00` (vendor-defined)
- ProductKey contains "Receiver" or specific product names

```objc
// Check if a device is a receiver vs. a mouse
NSString *name = IOHIDDeviceGetProperty(dev, CFSTR(kIOHIDProductKey));
BOOL isDongle = [name containsString:@"Receiver"] || 
                [name containsString:@"receiver"];
```

---

## Unifying Receiver Protocol (HID++ 1.0)

### Device Connection Notifications
Unifying receivers broadcast connection events as short reports (0x10):
```
Byte 0: 0x10 (short report)
Byte 1: 0xFF (receiver broadcast)
Byte 2: 0x00 (sub-ID)
Byte 3: 0x41 (device connection notification)
Byte 4: device index (1-6)
Byte 5: status flags
  - bit 6 (0x40): device connected (1) / disconnected (0)
  - bit 5 (0x20): device is encrypted
  - bits 0-3: device type (0=keyboard, 3=mouse, 4=numpad)
```

**Already handled in MMF**: `inputReportCallback` in `LogitechCIDActivator.m` detects `report[3] == 0x41` and triggers reactivation.

### Pairing Protocol
To enter pairing mode on a Unifying receiver:

1. **Open lock** (Register 0xB5, sub-ID 0x80):
```
[0x10, 0xFF, 0x80, 0xB5, 0x01, timeout_seconds, 0x00]
```
- `timeout_seconds`: 0x1E = 30 seconds pairing window

2. **Check pairing status** (wait for notification):
```
[0x10, 0xFF, 0x00, 0x41, deviceIndex, status, ...]
```
- If status bit 6 is set → device paired and connected

3. **Close lock** (cancel pairing):
```
[0x10, 0xFF, 0x80, 0xB5, 0x02, 0x00, 0x00]
```

4. **Unpair device** (sub-ID 0x80, register 0xB2):
```
[0x10, 0xFF, 0x80, 0xB2, deviceIndex, 0x00, 0x00]
```

### BetterMouse Pairing UI Flow
From localization strings:
> "1. Select a channel on your mouse, then turn off the mouse."
> "2. Click the pair button on the left to put your USB receiver into pairing mode."
> "3. Turn on your mouse to have it search and paired with the dongle."
> "Click the x button next to each slot to have your dongle erase the pairing info and free that slot for pairing a new device."

---

## Bolt Receiver Protocol (HID++ 2.0 BLE)

Bolt uses HID++ 2.0 features even on the receiver level.

### Pairing Protocol
1. **Start pairing**: Send HID++ 2.0 command to receiver's pairing feature
   - Device must be in fast-blink mode (long-press channel button)

2. **BetterMouse Bolt Pairing UI**:
> "1. Long press the channel button on your device until the LED blinks fast."
> "2. Click the Pair button on the left."

### Key Differences from Unifying
- Uses BLE-based communication → higher reliability
- Supports 1000 Hz report rate vs Unifying's 125 Hz
- Same 6-device limit
- More secure pairing (BLE-level encryption)

---

## Lightspeed Receiver Protocol

### Characteristics
- Single-device receiver (1:1 pairing)
- Lowest latency (optimized for gaming)
- Supports 1000+ Hz report rate
- Pre-paired at factory — no user pairing needed
- Same HID++ 2.0 protocol stack

### Detection
```objc
// Lightspeed receivers have specific PIDs
// and typically report as "LIGHTSPEED Receiver"
BOOL isLightspeed = [name containsString:@"LIGHTSPEED"] ||
                    [name containsString:@"Lightspeed"];
```

---

## Multi-Interface Device Matching

A single Logitech mouse registers as 2-3 separate `IOHIDDevice` instances:

| Interface | UsagePage | Purpose |
|---|---|---|
| **Standard HID** | 0x01 (Generic Desktop) | Mouse movement, native buttons |
| **Vendor HID++** | 0xFF00+ (Vendor) | HID++ 2.0 protocol communication |
| **Consumer** | 0x0C (Consumer) | Media keys (some models) |

### Current MMF Approach: `isSiblingDevice()`
```objc
// In Device.m — matches by Product ID AND Product Name
- (BOOL)isSiblingDevice:(Device *)other {
    return [self.vendorID isEqualToNumber:other.vendorID] &&
           ([self.productID isEqualToNumber:other.productID] ||
            [self.name isEqualToString:other.name]);
}
```

### BetterMouse Approach
BetterMouse uses a `_dongle` property to associate a mouse with its receiver, plus `connectionType` to track whether the mouse is connected via USB, BLE, or Unifying/Bolt.

### Finding the Write Interface
In `LogitechCIDActivator.m`, `findVendorInterface()` locates the HID++ interface:
```objc
// Match criteria: same VID+PID, PrimaryUsagePage >= 0xFF00 OR MaxOutputReportSize >= 20
```

---

## Device Lifecycle

```
1. IOHIDManager detects device attachment
   ↓
2. DeviceManager creates Device instance
   ↓
3. LogitechCIDActivator.handleDeviceAttached:
   a. Check VID == 0x046D
   b. Find vendor interface (findVendorInterface)
   c. Register input report callback
   d. activateDevice() — probe features, divert CIDs
   e. Set isLogitechDiverted flag
   f. queryBatteryAndDPIForDevice()
   ↓
4. Device is operational — input reports flow to inputReportCallback
   ↓
5. On wireless disconnect/reconnect:
   a. Detected via inputReportCallback (0x41 or 0x1D4B)
   b. 0.35s delay → re-activateDevice()
   c. Re-apply volatile settings (DPI, SmartShift, HiRes, Report Rate)
   ↓
6. On system wake:
   a. NSWorkspaceDidWakeNotification
   b. 0.8s delay → reactivateAll()
   ↓
7. On device removal:
   a. Release all pressed buttons
   b. Unschedule from runloop
   c. Close vendor interface
   d. Free state
```

---

## Implementing Dongle Management UI

### Architecture (based on BetterMouse's `Dongles` class)
```swift
class DongleInfo {
    var isDongle: Bool
    var dongleType: DongleType  // .unifying, .bolt, .lightspeed
    var paired: Bool
    var pairedCount: Int
    var pairName: String?
    var pairing: Bool           // Currently in pairing mode
    var connected: Bool
    var slots: [SlotInfo]       // For multi-device receivers
}

struct SlotInfo {
    var index: Int
    var deviceName: String?
    var deviceType: DeviceType  // .mouse, .keyboard, etc.
    var connected: Bool
}
```

### Required IPC Commands
| Command | Direction | Description |
|---|---|---|
| `getDongleInfo` | App → Helper | Returns dongle type, paired devices |
| `startPairing` | App → Helper | Enter pairing mode |
| `stopPairing` | App → Helper | Cancel pairing mode |
| `unpairSlot` | App → Helper | Remove pairing from slot |

### UI Requirements
- Show receiver type (Unifying / Bolt / Lightspeed)
- List paired device slots with names
- "Pair" button to enter pairing mode
- "×" button per slot to unpair
- Status indicator (connected/disconnected)
- Pairing instructions (different per receiver type)

---

## Bluetooth Manager Integration

BetterMouse includes a `BluetoothManager` class (subclass of NSObject, conforms to `CBCentralManagerDelegate`) for direct Bluetooth state monitoring.

### Capabilities
- Monitor Bluetooth on/off state via `centralManagerDidUpdateState:`
- Detect BLE connections/disconnections
- Not used for HID communication (that goes through IOKit)

### When Useful
- Show Bluetooth status in receiver management UI
- Detect when a Bluetooth-connected mouse goes to sleep
- Differentiate between USB and BLE connections for the same mouse model

---

## Known Issues & Edge Cases

1. **Receiver vs Mouse Confusion**: Some Logitech USB mice (wired) have the same VID as receivers. Always check ProductKey for "Receiver".

2. **Unifying 1-Device Receivers**: Nano receivers (C52F) look like Unifying but only support 1 device. Don't show 6 slots.

3. **Lightspeed No Pairing**: Lightspeed receivers are factory-paired. Don't show pairing UI for them.

4. **Bolt BLE Security**: Bolt pairing requires the device to be in fast-blink mode. The receiver rejects pairing attempts if the device LED isn't blinking.

5. **Device Index Persistence**: After receiver firmware updates or resets, device indices may change. Always re-probe.

6. **Multiple Receivers**: A system can have multiple Unifying/Bolt receivers plugged in simultaneously. Track each receiver's device state independently.
