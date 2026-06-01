# Developer Documentation: Logitech Mouse & Per-App Settings Implementation

This document details the implementation details for the modern Logitech Mouse support (via HID++ 2.0 CID Activator) and the App-Specific (Per-App) Settings features.

---

## 1. Logitech Mouse Integration

### Background & Issues
Legacy Logitech remapping in Mac Mouse Fix relied on hardcoded `65347` usage page report remappings. On newer Logitech mice (such as the Logitech MX Anywhere 3S or MX Master series), the button report structure is different:
- Custom buttons (e.g., Mode-Shift, Gesture, etc.) can report large, vendor-defined integers or use the Logitech HID++ 2.0 protocol.
- Standard buttons (such as Back and Forward, buttons 4 and 5) report natively on Usage Page 9.
- The legacy remapping intercepted all reports on page `65347` and immediately released all virtual buttons upon receiving `Value: 0` reports. Since newer mice frequently send `0` reports during pointer updates, drags, or scroll mode switches, this cut off long-press and click-and-drag gestures on side buttons.

### Implementation Details
To support newer Logitech mice correctly without breaking older ones:

1. **Logitech HID++ 2.0 CID Activator (`LogitechCIDActivator.m` / `.h`)**
   - Implements Logitech's HID++ 2.0 protocol to query the device capabilities dynamically.
   - Identifies non-native control IDs (CIDs) and diverts them to standard buttons.
   - Skips standard native controls (TIDs for Left, Right, Middle, Back, Forward) using `kNativeTIDs` to keep them reporting natively via standard macOS HID channels.
   - Listens to device attachment matching and registers input report callbacks to translate diverted HID++ long reports into virtual click and hold button events.

2. **Diverted Device Isolation (`Device.h` / `Device.m` / `LogitechCIDActivator.m`)**
   - Added an `isLogitechDiverted` flag on the `Device` class.
   - When the `LogitechCIDActivator` successfully diverts CIDs on a Logitech mouse, it sets `device.isLogitechDiverted = YES`.
   - In `Device.m`'s low-level `handleInput` callback, the legacy `usagePage == 65347` remapping block is skipped entirely if `sendingDev.isLogitechDiverted` is `YES`:
     ```objc
     if (usagePage == 65347 && !sendingDev.isLogitechDiverted) {
         // Legacy remapping is only applied to older Logitech devices
     }
     ```
   - This ensures that native standard buttons (buttons 4 and 5) flow directly to `ButtonInputReceiver.m` without double-down conflicts or premature button-release interruptions from legacy code.
   - For Logitech devices that expose native button elements 4 and 5, the legacy `65347` path also ignores old Back/Forward values (`83` and `86`). This prevents vendor-defined `Value: 0` packets from synthesizing an early button-up while the native side button is still physically held for long-press or click-and-drag gestures.

3. **Button Down/Up Robustness (`ButtonInputReceiver.m`)**
   - Mouse button state is resolved from the CGEvent type for mouse down/up events instead of relying only on `kCGMouseEventPressure`.
   - This keeps side-button hold and drag recognition stable on devices or macOS paths where pressure is not a reliable down-state signal.

---

## 2. Per-App (App-Specific) Settings

### Background & Issues
Users want different mouse button and scroll behaviors depending on the active frontmost application. Additionally:
- Some applications (like Java tools, Minecraft, or CLI scripts running in wrappers) do not have a standard `bundleIdentifier`.
- Switching to the App-specific tab previously caused visual layout flickers or frame jumps.

### Implementation Details
1. **Dynamic Config & Overrides**
   - Config storage matches keys against the active application's bundle identifier or fallback identifiers.
   - `Remap.m` and `Config.m` resolve configurations using the active frontmost application's state, merging global settings with application-specific overrides.

2. **Bundle-less App Resolution**
   - Added a resolution fallback to handle applications that lack a standard `bundleIdentifier`.
   - When bundle identification fails, it falls back to parsing window ownership, app name, or package structures to ensure per-app configurations can still be matched.

3. **UI Layout Transitions (`TabViewController.swift`)**
   - Optimized tab transitions and size calculations when switching to the App settings panel.
   - Cleans up transition frames, prevents frame jumps, and matches standard smooth animations of other App preferences.
   - The existing pointer settings view is now exposed as the Mouse tab instead of being hidden at startup, and it is included in tab validation/autosave so it behaves like the other top-level preference tabs.

---

## 3. General Stability Enhancements

1. **SecureStorage Bridge Crash Fix (`SecureStorage.swift`)**
   - Swift's forced cast `value as! NSObject?` fails and crashes when certain Swift types (e.g. Swift's `Date` from `TrialCounter.lastUseDate`) are stored.
   - Replaced all forced casts with safe `value as? NSObject` casting.
   - Removed `assert(false)` from the keychain `readDict` catch block, preventing unhandled keychain read failures from crashing the helper process.

2. **ClickCycle Unconditional State Guard (`ClickCycle.swift`)**
   - Added defensive guard-let checks in asynchronous timer blocks (e.g. `.hold` and `.levelExpired` timers) to prevent Swift runtime force-unwrap nil crashes if the click cycle is invalidated or killed concurrently.

---

## 4. Build Workflow Notes

### iCloud Workspace Build Stalls
- This repo often lives under `/Users/shawnrain/Library/Mobile Documents/com~apple~CloudDocs/...`, and Xcode can stall there while listing schemes, resolving packages, or starting a build.
- If `xcodebuild` hangs in the iCloud directory before real compile output appears, copy the source tree to a temporary local folder and build there:
  ```bash
  rm -rf /tmp/MacMouseFix-build
  rsync -a --delete \
    --exclude='.git' \
    --exclude='.build' \
    --exclude='releases' \
    --exclude='Mac Mouse Fix*.app' \
    --exclude='DerivedData' \
    ./ /tmp/MacMouseFix-build/
  xcodebuild -project "Mouse Fix.xcodeproj" -scheme "App" -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
  ```
- Keep source edits in the iCloud repo as the canonical working tree. Use `/tmp/MacMouseFix-build` only for build verification, then return to the original repo for `git status`, staging, commit, and push.
