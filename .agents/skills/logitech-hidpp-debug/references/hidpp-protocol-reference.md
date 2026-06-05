# Logitech HID++ 2.0 Protocol Quick Reference

This document is a concise reference for the HID++ 2.0 protocol as used in Mac Mouse Fix. For full protocol documentation, refer to [Logitech's open-source specs](https://lekensteyn.nl/files/logitech/) and the [Solaar project](https://github.com/pwr-Solaar/Solaar).

## Packet Format

### Short Report (0x10) — 7 bytes
```
[0x10] [DeviceIndex] [FeatureIndex] [FunctionID | SwID] [Param0] [Param1] [Param2]
```

### Long Report (0x11) — 20 bytes
```
[0x11] [DeviceIndex] [FeatureIndex] [FunctionID | SwID] [Param0..Param15]
```

- **DeviceIndex**: `0xFF` = USB/BLE direct, `0x01-0x06` = Unifying slot
- **FeatureIndex**: Index returned by Root Feature (0x0000) lookup
- **FunctionID | SwID**: Upper nibble = function number (0-F), lower nibble = software ID (we use `0x0E`)
- Function 0 = `0x0E`, Function 1 = `0x1E`, Function 2 = `0x2E`, etc.

## Feature Lookup (Root Feature 0x0000)

To find the index of any feature, send to Feature Index `0x00`:
```
Request:  [0x11] [DevIdx] [0x00] [0x0E] [FeatID_Hi] [FeatID_Lo] [0x00...]
Response: [0x11] [DevIdx] [0x00] [0x0E] [FeatureIndex] [FeatureType] [0x00...]
```

## Features Used in Mac Mouse Fix

### 0x0001 — Feature Set
Used for device index probing. Universal on all HID++ 2.0 devices.

### 0x1B04 — ReprogControlsV4
Button enumeration and diversion.

| Function | Byte | Description |
|---|---|---|
| F0 (`0x0E`) | GetCount | `resp[4]` = number of CIDs |
| F1 (`0x1E`) | GetCidInfo(index) | `resp[4:5]` = CID, `resp[6:7]` = TID, `resp[8]` = flags |
| F3 (`0x3E`) | SetCidReporting | `pkt[4:5]` = CID, `pkt[6]` = divert flags (`0x03` = divert + valid) |

**CID Flags (resp[8]):**
- Bit 5 (`0x20`) = divertable
- Other bits: virtual, persist, rawXY, etc.

**Divert Flags (pkt[6]):**
- `0x03` = divert=1 (bit 0) + divert_valid=1 (bit 1)
- Pattern from Solaar: each flag has a valid bit at `flag << 1`

**Unsolicited CID Event (divertedButtonsEvent):**
```
[0x11] [DevIdx] [FeatIdx] [0x00] [CID1_Hi] [CID1_Lo] [CID2_Hi] [CID2_Lo] ...
```
Up to 4 CIDs. Zero-terminated. Compare with previous state to detect press/release.

### 0x1004 — Unified Battery
```
Function 1 (0x1E): GetBatteryLevelStatus
  resp[4] = percentage (0-100)
  resp[6] = status (0=discharging, 1=charging, 2=full)
```

### 0x1000 — Battery Levels (older)
```
Function 0 (0x0E): GetBatteryLevelStatus
  resp[4] = percentage
  resp[6] = status
```

### 0x2201 — Adjustable DPI
```
Function 1 (0x1E): GetSensorDpiList (capabilities)
  Response contains DPI values as big-endian uint16 pairs, zero-terminated.
  Range-compression: if (val >> 13) == 0b111, val & 0x1FFF = step, next 2 bytes = end value.

Function 2 (0x2E): GetSensorDpi
  pkt[4] = sensor index (0)
  resp[5:6] = current DPI X
  resp[7:8] = current DPI Y (may be 0 if only X is reported)

Function 3 (0x3E): SetSensorDpi
  pkt[4] = sensor index (0)
  pkt[5:6] = DPI value (big-endian)
```

### 0x2202 — Extended Adjustable DPI
Same concept as 0x2201 but with extended range and Y-axis support.

```
Function 2 (0x2E): GetSensorDpiList — 3 ignore bytes before data
Function 5 (0x5E): GetSensorDpi
  pkt[4] = sensor index (0)
  resp[5:6] = current DPI

Function 6 (0x6E): SetSensorDpi
  pkt[4] = sensor index (0)
  pkt[5:6] = DPI X, pkt[7:8] = DPI Y, pkt[9] = LOD
```

### 0x2111 / 0x2110 — SmartShift Enhanced / Basic

```
0x2111 Function 0 (0x0E): GetCapabilities
  resp[4] = wheelMode, resp[5] = autoShift, resp[6] = threshold, resp[7] = torque

0x2111 Function 1 (0x1E): SetStatus
  pkt[4] = wheelMode, pkt[5] = autoShift, pkt[6] = threshold, pkt[7] = torque

0x2110 Function 1 (0x1E): GetStatus
  resp[4] = mode (0=ratchet, 1=freespin, 2=smartshift)

0x2110 Function 2 (0x2E): SetStatus
  pkt[4] = mode
```

### 0x1D4B — Wireless Device Status
Unsolicited broadcast on wireless reconnection:
```
[0x11] [DevIdx] [FeatIdx] [0x00] [status] ...
  status == 0x01 (proto_activation) or 0x02 (connection change) → device reconnected
```

## Error Handling

Error response format:
```
[0x11] [DevIdx] [0xFF] [OrigFeatIdx] [OrigFuncID] [ErrorCode] ...
```

Common error codes:
| Code | Meaning |
|---|---|
| `0x01` | Unknown feature |
| `0x02` | Unknown function |
| `0x04` | Busy / resource conflict |
| `0x05` | Invalid argument |
| `0x0B` | Hardware error |

## CID → Button Mapping (Mac Mouse Fix)

| CID | Button | Description |
|---|---|---|
| `0x0053` | 4 | Back |
| `0x0056` | 5 | Forward |
| `0x00C4` | 6 | Smart Shift / function key |
| `0x00D7` | 7 | Mode Shift key |
| Dynamic | 8+ | Other CIDs, assigned sequentially |

## Legacy Page 65347 (0xFF43) Mapping

| Value | Button | Description |
|---|---|---|
| `83` | 4 | Back (older Logitech) |
| `86` | 5 | Forward (older Logitech) |
| `196` | 6 | Mode-shift (older Logitech) |
| `1052927` | 6 | Mode-shift (newer Logitech, `0x1010FF`) |
| `82` | 7 | Gesture button (older Logitech) |
| `0` | — | All buttons released |
