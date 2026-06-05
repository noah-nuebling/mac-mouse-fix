---
name: logitech-hidpp-debug
description: Diagnose and fix Logitech HID++ 2.0 mouse integration issues including button recognition, DPI control, SmartShift, battery status, wireless reconnection, and pointer speed scaling. Use when buttons stop working, DPI jumps, speed feels wrong, or wireless reconnection fails.
---

# Logitech HID++ Debug Skill

Use this skill to diagnose and fix issues with Logitech mouse integration in Mac Mouse Fix. This covers the entire HID++ 2.0 protocol stack, from low-level USB/BLE report parsing to high-level UI state management.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    Main App (UI)                         │
│  PointerTabController.swift                             │
│    ├── pollLogitechInfo()     [async, background queue] │
│    ├── dpiSliderChanged()    [fire-and-forget IPC]      │
│    ├── sendSmartShiftSettings() [fire-and-forget IPC]   │
│    ├── hiResToggleChanged()  [fire-and-forget IPC]      │
│    └── reportRateChanged()   [fire-and-forget IPC]      │
└───────────────┬─────────────────────────────────────────┘
                │  CFMessagePort IPC
                ▼
┌─────────────────────────────────────────────────────────┐
│                  Helper Process                          │
│  MFMessagePort.m                                        │
│    ├── queryLogitechInfo     → LogitechCIDActivator      │
│    ├── getLogitechState      → SmartShift + DPI caps     │
│    ├── setLogitechDPI        → setDpi:forDevice:         │
│    ├── setLogitechSmartShift → setSmartShiftState:       │
│    ├── getLogitechHiResState → getHiResWheelState:       │
│    ├── setLogitechHiResMode  → setHiResWheelMode:        │
│    ├── getLogitechReportRate → getReportRateInfo:         │
│    └── setLogitechReportRate → setReportRate:             │
│                                                          │
│  LogitechCIDActivator.m (HID++ 2.0 protocol)            │
│    ├── activateDevice()      → Feature probe + CID div  │
│    │     Probes: 0x1B04 0x1D4B 0x2111/0x2110            │
│    │             0x2201/0x2202 0x2121 0x8060/0x8061      │
│    ├── queryBatteryAndDPI()  → 0x1004 / 0x2201/0x2202  │
│    ├── inputReportCallback() → Button events + reconnect │
│    └── periodicCheck()       → Re-activation watchdog    │
│                                                          │
│  Device.m (state & sibling matching)                     │
│    ├── isLogitechDiverted    → Shared across siblings    │
│    ├── supportsLogitechDPI   → Shared across siblings    │
│    ├── supportsLogitechHiResWheel → HiRes Scroll state   │
│    ├── supportsLogitechReportRate → Report Rate state     │
│    ├── handleInput()         → Legacy Page 65347 handler │
│    └── isSiblingDevice()     → PID + Product Name match  │
│                                                          │
│  PointerSpeed.m (driver configuration)                   │
│    └── setForDevice:         → 1/3x multiplier for DPI  │
└─────────────────────────────────────────────────────────┘
```

## Diagnosis Workflow

### Step 1: Identify the Symptom

| Symptom | Likely Cause | Go To |
|---|---|---|
| Side buttons don't work | Legacy Page 65347 filtering or failed CID diversion | §A |
| Mouse pointer too fast / too slow | DPI multiplier misconfigured or sensitivity leaking | §B |
| DPI slider doesn't change speed | `setDpi:forDevice:` failing or wrong device state | §C |
| Battery/DPI shows "--" in UI | Sibling device matching failure | §D |
| Settings reset after sleep/reconnect | Volatile config re-application failed | §E |
| Mouse tab freezes / lags | Synchronous IPC on main thread | §F |
| SmartShift toggle not working | Feature `0x2111`/`0x2110` not found or wrong function | §G |

### §A: Side Button Diagnosis

1. **Check which report path the mouse uses:**
   ```
   Grep helper logs for: "handleInput" and "usagePage"
   ```
   - If you see `usagePage == 9, usage == 4/5` → Native Page 9 path → Works natively
   - If you see `usagePage == 65347, value == 83/86` → Legacy path → Check §A.2
   - If you see HID++ reports with `report[2] == featReprogV4` → Diverted path → Check §A.3

2. **Legacy Page 65347 path issues:**
   - Check `Device.m` `handleInput` callback:
     - The block must be entered when `!sendingDev.isLogitechDiverted`
     - **NEVER** add `deviceHasNativeButton()` filtering inside this block — older mice declare but don't send native events
   - Check if `isLogitechDiverted` is incorrectly `YES` when it shouldn't be

3. **Diverted path issues:**
   - Check `LogitechCIDActivator.m` logs for `diverted side-button CID 0x0053/0x0056`
   - If CID diversion failed: check `Failed to divert CID` logs
   - If CID reports arrive but aren't parsed: check `inputReportCallback` — verify `report[2] == s->featReprogV4` and `report[3] == 0x00`

### §B: Pointer Speed Diagnosis

1. **Check if DPI multiplier is applied:**
   - In `PointerSpeed.m` → `setForDevice:`, log or verify:
     - `isLogitechDPI` should be `YES` for Logitech DPI mice
     - `multiplier` should be `0.3333...`
     - `ignoreSensitivity` should be `YES`
   - If `isLogitechDPI` is `NO`:
     - Check `attachedDev.supportsLogitechDPI` — may not be set yet (race condition with `queryBatteryAndDPIForDevice:`)
     - Check `[PointerConfig hasSavedLogitechDPI]` — needs `Pointer.logitechDPI` in config

2. **Check if sensitivity slider is leaking into DPI mice:**
   - When `confirmedDPIMode == true`, the sensitivity `producer.skip(first: 1)` callback should `return` early (guard at line ~86 of PointerTabController.swift)
   - Config should NOT have `Pointer.sensitivity` updated while in DPI mode

### §C: DPI Slider Diagnosis

1. **Verify IPC reaches the helper:**
   - `setLogitechDPI` uses `waitForReply: false` — check helper logs for the DPI set command
   - `currentLogitechDevice()` in `MFMessagePort.m` may return `nil` if the active device is not Logitech

2. **Verify hardware accepts the DPI value:**
   - Check `setDpi:forDevice:` — the feature index (`featAdjustableDpi` or `featExtendedDpi`) must be non-zero
   - Verify the DPI value is within the device's supported range from `getDPICapabilities`
   - Check for `sendAndWaitWithTimeout` errors

### §D: Sibling Device Matching

1. **Problem**: Battery/DPI is queried on one `Device` interface but the UI reads from another.
2. **Check `isSiblingDevice()`**:
   - Both devices must share the same Vendor ID (`0x046D`)
   - They must match on Product ID OR Product Name
   - If neither matches, the sibling lookup fails silently
3. **Common failure**: After a device removal + re-attach, the old `Device` instance may linger in `attachedDevices` briefly

### §E: Volatile Config Re-application

1. **Check reconnection detection:**
   - Grep logs for `Wireless reconnection event detected` or `Unifying reconnection event`
   - If neither appears: the reconnect notification format may have changed
   - Check `inputReportCallback` parsing for Unifying (`report[3] == 0x41`) and HID++ 2.0 (`report[3] == 0x00` with `featWirelessStatus`)
2. **Check re-activation:**
   - Grep for `activateDevice applying saved DPI setting`
   - If this doesn't appear: saved config values may be missing (`Pointer.logitechDPI`, etc.)

### §F: UI Freeze / Lag

1. **`pollLogitechInfo()` must run all IPC on a background queue:**
   ```swift
   DispatchQueue.global(qos: .userInitiated).async { ... }
   ```
   - UI updates must dispatch back to `DispatchQueue.main.async`
2. **Slider IPC must use `waitForReply: false`:**
   - `setLogitechDPI` and `setLogitechSmartShift` are fire-and-forget
   - Config is saved locally before sending IPC

### §G: SmartShift Diagnosis

1. **Check feature support:**
   - Grep logs for `Found SmartShift feature index`
   - Feature `0x2111` = SmartShift Enhanced (supports tunable torque)
   - Feature `0x2110` = SmartShift Basic
2. **Function index mapping:**
   - `0x0E` = Function 0 (getCapabilities)
   - `0x1E` = Function 1 (getStatus / setStatus fallback)
   - `0x2E` = Function 2 (setStatus)
3. **Mode values:**
   - `0` = Ratchet, `1` = Freespin, `2` = SmartShift (auto-switch)

## Key Files Reference

| File | Purpose |
|---|---|
| `Helper/Core/Buttons/LogitechCIDActivator.m` | HID++ 2.0 protocol, CID diversion, DPI/battery/SmartShift |
| `Helper/Core/Buttons/LogitechCIDActivator.h` | Public API + structs (`LogitechSmartShiftState`, `LogitechDPICapabilities`) |
| `Shared/Devices/Device.m` | Low-level input callback, sibling matching, Logitech state sharing |
| `Shared/Devices/Device.h` | `isLogitechDiverted`, `supportsLogitechDPI`, battery/DPI properties |
| `Helper/Core/PointerSpeed/PointerSpeed.m` | Driver sensitivity/acceleration config, 1/3x DPI multiplier |
| `Helper/Core/Config/PointerConfig.swift` | `hasSavedLogitechDPI`, acceleration curve generation |
| `App/UI/Main/Tabs/PointerTabController.swift` | Mouse tab UI, async polling, DPI/SmartShift controls |
| `Shared/MessagePort/MFMessagePort.m` | IPC handlers for all `queryLogitechInfo`/`setLogitechDPI`/etc commands |

## Common Mistakes to Avoid

1. **Never** filter legacy Page 65347 button events by `deviceHasNativeButton()` — older mice declare but don't send native Page 9 events.
2. **Never** use synchronous IPC (`waitForReply: true`) on the main thread for Logitech queries — the helper may take >1s to respond.
3. **Never** set `isLogitechDiverted` based on the count of diverted CIDs — use `featReprogV4 != 0` instead.
4. **Never** downgrade `confirmedDPIMode` from `true` to `false` based on a transient IPC failure.
5. **Always** call `[PointerSpeed setForAllDevices]` after changing `isLogitechDiverted` or `supportsLogitechDPI`.
6. **Always** re-apply saved config inside `activateDevice()` since Logitech firmware settings are volatile.
