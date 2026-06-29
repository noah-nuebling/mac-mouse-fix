# Developer Documentation: Logitech Mouse & Per-App Settings Implementation

This document details the implementation details for the modern Logitech Mouse support (via HID++ 2.0 CID Activator) and the App-Specific (Per-App) Settings features.

---

## 1. Logitech Mouse Integration

### Background & Issues
Legacy Logitech remapping in Mac Mouse Fix relied on hardcoded `65347` usage page report remappings. On newer Logitech mice (such as the Logitech MX Anywhere 3S or MX Master series), the button report structure is different:
- Custom buttons (e.g., Mode-Shift, Gesture, etc.) can report large, vendor-defined integers or use the Logitech HID++ 2.0 protocol.
- Standard buttons (such as Back and Forward, buttons 4 and 5) report natively on Usage Page 9.
- The legacy remapping intercepted all reports on page `65347` and immediately released all virtual buttons upon receiving `Value: 0` reports. Since newer mice frequently send `0` reports during pointer updates, drags, or scroll mode switches, this cut off long-press and click-and-drag gestures on side buttons.

### Device Classification

There are three distinct categories of Logitech mice and how MMF handles them:

| Category | HID++ 2.0 | ReprogControlsV4 (0x1B04) | DPI Control | Side Button Reporting | Example Models |
|---|---|---|---|---|---|
| **Newer Diverted** | ✅ | ✅ | ✅ (0x2201/0x2202) | HID++ diversion via CID notifications | MX Anywhere 3S, MX Master 3S |
| **Older HID++ (non-diverted)** | ✅ | ❌ (or CIDs not divertable) | ✅/❌ | Legacy Page 65347 (values 83/86) | MX Anywhere 2S, Performance MX |
| **Legacy / non-HID++** | ❌ | ❌ | ❌ | Legacy Page 65347 or native Page 9 | Older wired Logitech mice |

> **Critical distinction**: Older HID++ mice (like Anywhere 2S) may declare Page 9 button elements in their HID descriptor but **never actually send native Page 9 reports** for side buttons. They report exclusively on Page 65347. The code must NOT filter out Page 65347 events based on the descriptor's declared elements.

### Implementation Details

#### 1.1 Logitech HID++ 2.0 CID Activator (`LogitechCIDActivator.m` / `.h`)
- Implements Logitech's HID++ 2.0 protocol to query device capabilities dynamically.
- Identifies non-native control IDs (CIDs) and diverts them to standard buttons.
- Skips standard native controls (TIDs for Left, Right, Middle, Back, Forward) using `kNativeTIDs` to keep them reporting natively via standard macOS HID channels.
- Listens to device attachment matching and registers input report callbacks to translate diverted HID++ long reports into virtual click and hold button events.

**Key HID++ features used:**
| Feature ID | Name | Purpose |
|---|---|---|
| `0x0001` | Feature Set | Device index probing — universally available on HID++ 2.0 |
| `0x1B04` | ReprogControlsV4 | Button CID enumeration and diversion |
| `0x1004` / `0x1000` | Unified Battery / Battery Levels | Battery percentage and charging status |
| `0x2201` | Adjustable DPI | Standard DPI query/set (older models) |
| `0x2202` | Extended Adjustable DPI | Extended DPI query/set with Y-axis (newer models) |
| `0x2111` / `0x2110` | SmartShift Enhanced / SmartShift | Scroll wheel mode control (ratchet/free/auto) |
| `0x1D4B` | Wireless Device Status | Connection/disconnection broadcast events |

**Device Index Probing:**
- The activator probes multiple possible device indices (`0xFF, 0x01–0x06`) using Feature Set (`0x0001`) to find the active device.
- This replaces hardcoded index assumptions and works correctly with both Unifying receivers and Bolt/BLE direct connections.

**CID Diversion Logic:**
- Mode-Shift / Gesture buttons (mapped to Button ≥ 6) are only diverted if the user has explicitly remapped them (checked via `isButtonRemapped()`). This preserves native hardware functions like wheel-mode switching.
- Side buttons (CID `0x0053` = Back, CID `0x0056` = Forward) are always diverted to allow MMF remapping.
- The `kDivertFlags = 0x03` value follows Solaar's "valid bit" pattern: bit 0 = divert, bit 1 = divert_valid.

#### 1.2 Diverted Device Isolation (`Device.h` / `Device.m` / `LogitechCIDActivator.m`)
- The `isLogitechDiverted` flag on the `Device` class tracks whether CID diversion is active.
- `isLogitechDiverted` is set based purely on `s->featReprogV4 != 0` (whether the device supports ReprogControlsV4), **not** on the transient count of successfully diverted CIDs. This prevents reconnection/reactivation from incorrectly resetting the flag.
- Multi-interface sibling matching uses `isSiblingDevice()` which checks both Product ID (`kIOHIDProductIDKey`) and Product Name (`kIOHIDProductKey`) to find Device instances that belong to the same physical mouse across USB/BLE interfaces.
- All Logitech state getters (`isLogitechDiverted`, `supportsLogitechDPI`, `logitechDPI`, `logitechBatteryPercentage`, `logitechBatteryStatus`) dynamically share values across sibling device interfaces.
- The `setIsLogitechDiverted:` and `setSupportsLogitechDPI:` setters both call `[PointerSpeed setForAllDevices]` to immediately reconfigure the driver.

**Legacy Page 65347 Handler:**
```objc
if (usagePage == 65347 && !sendingDev.isLogitechDiverted) {
    // Process legacy button reports for non-diverted Logitech mice.
    // Do NOT filter by deviceHasNativeButton — older mice declare
    // Page 9 elements but send exclusively on Page 65347.
}
```
> **Warning**: Never add a `deviceHasNativeButton` check inside this block. The Anywhere 2S (and similar older mice) declare Page 9 button elements but never send native Page 9 reports for side buttons. Filtering by the descriptor drops their clicks entirely.

#### 1.3 Pointer Speed and DPI Decoupling (`PointerSpeed.m` / `PointerConfig.swift`)
- **Problem**: MMF's custom acceleration curves apply a base gain of ~3.0x. When Logitech hardware DPI is set to 400, the cursor moves at ~1200 DPI effective speed.
- **Solution**: For Logitech DPI-capable mice, `setForDevice:` applies a `0.3333333333333333` (1/3) sensitivity multiplier and sets `ignoreSensitivity = YES` to bypass the user's sensitivity slider entirely.
- **Detection**: A device is treated as "Logitech DPI-capable" if `attachedDev.supportsLogitechDPI == YES` **or** `[PointerConfig hasSavedLogitechDPI] == YES` (config-level fallback for when device hasn't been probed yet).
- The sensitivity slider in the UI only affects non-DPI mice. The DPI slider only affects Logitech DPI-capable mice. The two are completely decoupled.

#### 1.4 Volatile Settings Persistence
Logitech device settings (DPI, SmartShift mode, torque, threshold) are volatile — they reset on:
- Wireless reconnection (sleep/wake, out-of-range)
- System wake from sleep
- USB replug

The activator handles all three scenarios:
1. **Wireless reconnect**: `inputReportCallback` detects Unifying 1.0 connection notifications (`0x41`) and HID++ 2.0 Wireless Status (`0x1D4B`) broadcasts, then schedules `activateDevice()` after 0.35s delay.
2. **System wake**: NSWorkspaceDidWakeNotification triggers `reactivateAll` after 0.8s delay.
3. **Periodic check**: A 5-second timer checks if any device with `featReprogV4 != 0` has lost its diverted flag and re-activates it.
4. **Native side button detection**: If a diverted device sends a native Page 9 side button event, the volatile config was lost. The code clears `isLogitechDiverted` and dispatches `reactivateDeviceWithIOHIDDevice:`.

Saved settings from config (`Pointer.logitechDPI`, `Pointer.logitechWheelMode`, etc.) are re-applied inside `activateDevice()` after feature detection.

#### 1.5 App ↔ Helper IPC (`MFMessagePort.m` / `PointerTabController.swift`)
| IPC Command | Direction | Description | Reply? |
|---|---|---|---|
| `queryLogitechInfo` | App → Helper | Returns `isLogitech`, `batteryPercentage`, `batteryStatus`, `dpi` | ✅ (sync) |
| `getLogitechState` | App → Helper | Returns SmartShift state, DPI capabilities, current DPI | ✅ (sync) |
| `setLogitechDPI` | App → Helper | Sets hardware DPI. Payload: `NSNumber(uint16)` | ❌ (fire-and-forget) |
| `setLogitechSmartShift` | App → Helper | Sets SmartShift params. Payload: `NSDictionary` | ❌ (fire-and-forget) |

> **Important**: `queryLogitechInfo` and `getLogitechState` are called from a background queue (`DispatchQueue.global(qos: .userInitiated)`) in `pollLogitechInfo()`, never on the main thread. UI updates are dispatched back to the main queue. The `queryLogitechInfo` handler rate-limits physical device queries to at most once every 10 seconds per device.

> **Important**: `setLogitechDPI` and `setLogitechSmartShift` use `waitForReply: false` to prevent slider drag lag. Config is written locally before sending the IPC message, so settings are never lost even if the helper is momentarily unreachable.

#### 1.6 Mouse Tab UI (`PointerTabController.swift`)
- `confirmedDPIMode` flag prevents transient IPC failures from downgrading the UI back to standard sensitivity controls. Once DPI mode is confirmed (from saved config or successful poll), it never degrades.
- Initial UI mode is set from saved config in `setupDPIControls()` — no IPC needed at startup.
- Polling runs at 3-second intervals while the Mouse tab is visible, with the first poll firing 0.3s after `viewWillAppear`.
- All programmatic UI strings use `MFLocalizedString()` for l10n support.
- SF Symbols require `#available(macOS 11.0, *)` guards for the macOS 10.15 deployment target.

#### 1.7 Button Down/Up Robustness (`ButtonInputReceiver.m`)
- Mouse button state is resolved from the CGEvent type for mouse down/up events instead of relying only on `kCGMouseEventPressure`.
- This keeps side-button hold and drag recognition stable on devices or macOS paths where pressure is not a reliable down-state signal.

#### 1.8 Add Mode Drag Capture (`ButtonTabController.swift`)
- The Buttons tab enables helper-side Add Mode while the pointer is inside the add field. Do not disable Add Mode immediately on `mouseExited`.
- "Click and Drag" capture must move the pointer, and on Logitech side buttons the helper often needs the first movement events after leaving the add field to cross the modified-drag threshold.
- `mouseExited_Internal(dueToAddModeFeeback: false)` therefore schedules a short delayed `disableAddMode`; `mouseEntered` and `handleAddModeFeedback` cancel the pending disable. This preserves ordinary hover behavior while giving buttons 4/5 a real capture window for drag gestures.
- When diagnosing this path, use the CocoaLumberjack file logs at `~/Library/Logs/Mac Mouse Fix Helper/`. Useful probes are `enableAddMode`, `disableAddMode`, `buttonModifiers`, `INITIALIZING MODIFIEDDRAG`, `Concluding addMode`, and `addModeFeedback`.

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

3. **PWA Override Inheritance (`Config.m`)**
   - Progressive Web Apps run inside wrapper processes with distinct bundle identifiers. These are mapped to their parent browser's identifier:
     - `com.apple.Safari.WebApp.*` → `com.apple.Safari`
     - `com.google.Chrome.app.*` → `com.google.Chrome`
     - `com.microsoft.edgemac.app.*` → `com.microsoft.edgemac`
     - `com.brave.Browser.app.*` → `com.brave.Browser`

4. **UI Layout Transitions (`TabViewController.swift`)**
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

## 4. Known Issues & Pitfalls

### Logitech-Specific
1. **Multi-interface Device Race**: A single Logitech mouse registers as 2-3 separate `Device` instances (standard HID, vendor HID++, sometimes a third). State must be shared across siblings via `isSiblingDevice()`. If sibling matching fails, DPI/battery reads return stale `-1` values.
2. **Descriptor vs. Reality Mismatch**: Older Logitech mice declare Page 9 button elements in their HID descriptor but send side button clicks exclusively on Page 65347. **Never filter legacy Page 65347 events based on `deviceHasNativeButton()`**.
3. **Volatile Config Reset**: Logitech device settings reset on any power cycle. The activator re-applies settings via `activateDevice()`, but there's a 0.35-0.8 second window where settings are lost. During this window, the mouse may briefly behave with default firmware settings.
4. **HID++ Report Collision**: The `inputReportCallback` handles both synchronous responses (to our requests) and unsolicited notifications. The `waitingIndex` field prevents confusing the two, but if multiple requests are in-flight simultaneously, responses can be misrouted. The current code serializes all HID++ communication on the main thread.
5. **`sIsActivatingOrReactivating` Guard**: `queryBatteryAndDPIForDevice:` is skipped while activation is in progress to avoid overlapping HID++ transactions. If activation fails silently, the battery/DPI query never runs. The periodic check mitigates this.

### IPC-Specific
6. **CFMessagePort Timeout**: The `recieveTimeout` for `waitForReply: true` is 1.0 second. If the helper is performing HID++ transactions, it may not respond in time. The main app's `pollLogitechInfo()` handles this gracefully by keeping the last known UI state.
7. **Fire-and-Forget Ordering**: `setLogitechDPI` and `setLogitechSmartShift` do not wait for replies. If the helper receives them out of order (unlikely but possible), the last-written config value wins since `activateDevice()` re-applies from config on reconnect.

### Scroll & Config-Specific
8. **Quartz Timestamp Double-Scaling (`EventUtility.m`)**: `CGEventGetTimestamp(event)` returns timestamps that are already standard Quartz nanoseconds. Never pass it to `machTimeToSeconds` on Apple Silicon. Doing so will multiply Quartz timestamps by `125 / 3 = 41.67`, causing physical scroll intervals of e.g. 10ms to be measured as 417ms. This exceeds the 160ms `consecutiveScrollTickIntervalMax` threshold and breaks all consecutive tick and swipe speedup detection, locking scrolling to its slowest fallback speed.
9. **ScrollConfig Initialization Order (`ScrollConfig.swift`)**: In `ScrollConfig.reload()`, the static raw configuration `_scrollConfigRaw = newConfigRaw` must be assigned *before* instantiating the new `shared = ScrollConfig()` object. Otherwise, when `SwitchMaster` queries properties like `u_speed` and `u_precise` (which are `@objc lazy var` properties) during initialization, they will evaluate using the stale raw configuration and cache it permanently.
10. **App Overrides and `configForKeyPath` usage**: In `ScrollConfig.reload()`, never use the C global `config("Scroll")` to read configuration. That C function retrieves config from `ConfigFileInterface_Helper.config` (i.e. `_config`), which does NOT include App-Specific Overrides. Instead, always use `Config.configForKeyPath("Scroll")` which resolves config with active App Overrides (`configWithAppOverridesApplied`).
11. **Writing back overridden values in `scrollConfig(modifiers:inputAxis:display:)`**: When `u_precise` or `u_speed` are modified dynamically inside `scrollConfig` (due to modifiers like `useQuickMod` or `usePreciseMod`), they must be assigned back to the copy instance (e.g. `new.u_precise = precise`, `new.u_speed = u_speed`). Since these are `@objc lazy var` properties, copying them via shallow copy retains their evaluated values, and any dynamic overrides won't reflect in properties unless explicitly written back. Failing to do so causes `ScrollAnalyzer` to read stale values (e.g., keeping precise scrolling active when it should be bypassed), which breaks features like the start-of-scroll smooth preheating hack.
12. **Config Overrides Rebuild Skip (`Config.swift`)**: When reloading the configuration via `updateDerivedStates()`, if the current frontmost application (`currentAppIdentifier`) hasn't changed, `loadOverridesForApp(_:force:)` will skip rebuilding the overridden configuration dictionary `configWithAppOverridesApplied` due to its internal deduplication optimization. This causes any configuration changes made while in the same application to be ignored by all downstream reloaders. To bypass this, always pass `force: true` when reloading from configuration file updates.
13. **Precise Scroll and System Speed Uncoupling (`ScrollConfig.swift`)**: Precise scrolling must never be active when using the macOS default acceleration speed (`u_speed == kMFScrollSpeedSystem`). Even if the underlying configuration dictionary retains a stale `precise: true` value, the evaluation of `u_precise` must override it to `false` to avoid breaking the start-of-scroll preheating logic and locking native scrolling to its slowest speed.


---

## 5. Build Workflow Notes

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
  cd /tmp/MacMouseFix-build
  xcodebuild -project "Mouse Fix.xcodeproj" -scheme "App" -configuration Debug -destination 'platform=macOS' build
  ```
- Keep source edits in the iCloud repo as the canonical working tree. Use `/tmp/MacMouseFix-build` only for build verification, then return to the original repo for `git status`, staging, commit, and push.
- When the user asks to run the new build for manual testing, do not launch the app directly from DerivedData. Copy the freshly built app into `/Applications`, stop any running app/helper processes, then launch `/Applications/Mac Mouse Fix.app`:
  ```bash
  BUILT_DIR=$(xcodebuild -project "Mouse Fix.xcodeproj" -scheme "App" -configuration Debug -showBuildSettings 2>/dev/null \
    | grep '^\s*BUILT_PRODUCTS_DIR' | head -1 | sed 's/.*= //')
  rm -rf "/Applications/Mac Mouse Fix.app"
  ditto "$BUILT_DIR/Mac Mouse Fix.app" "/Applications/Mac Mouse Fix.app"
  osascript -e 'tell application "Mac Mouse Fix" to quit' >/dev/null 2>&1 || true
  pkill -x "Mac Mouse Fix Helper" >/dev/null 2>&1 || true
  open -n "/Applications/Mac Mouse Fix.app"
  ```

### Helper Signing & Runtime Verification
- Do not use `CODE_SIGNING_ALLOWED=NO` for a build that will be installed and tested as a working app. It can make the main app appear to launch, but the helper registration will fail with:
  ```text
  SMAppServiceErrorDomain Code=3 "Codesigning failure loading plist: sm_launchd.plist code: -67056"
  ```
- That failure shows up in the UI as the recurring toast/popover:
  ```text
  系统偏好设置中已禁用 Mac Mouse Fix
  ```
  The message is misleading during development: the real cause can be an unsigned or improperly signed app/helper, not a user-disabled Login Item.
- For a "make it usable" verification, the installed `/Applications/Mac Mouse Fix.app` and the embedded helper must both pass bundle signing verification before launching:
  ```bash
  codesign --verify --deep --strict --verbose=4 "/Applications/Mac Mouse Fix.app"
  codesign --verify --strict --verbose=4 "/Applications/Mac Mouse Fix.app/Contents/Library/LoginItems/Mac Mouse Fix Helper.app"
  ```
- After launching, confirm the helper actually registers and starts. The app log should not contain `SMAppServiceErrorDomain Code=3`, `Codesigning failure loading plist`, or repeated `Can't send message ..., because there is no CFMessagePort` entries after enabling Mac Mouse Fix.
- If a local development certificate is invalid and a signed build cannot be produced, do not call the app "usable" just because the window opens. Either fix signing first, install a known-good signed build, or explicitly report that helper startup is blocked by code signing.

---

## 6. Debugging Guide

### Log Locations
| Log | Path | Contents |
|---|---|---|
| Helper runtime logs | `~/Library/Logs/Mac Mouse Fix Helper/` | CocoaLumberjack file logs |
| System log (helper) | Console.app → filter `Mac Mouse Fix Helper` | `DDLogInfo`/`DDLogError` output |
| System log (app) | Console.app → filter `Mac Mouse Fix` | App-side IPC and UI logs |

### Useful Log Probes
- **HID++ activation**: `LogitechCIDActivator: Found active device index`, `configured %d CID(s)`, `diverted side-button CID`
- **Wireless reconnect**: `Wireless reconnection event detected`, `Scheduling activation in 0.35 seconds`
- **DPI/Battery**: `DPI query successful`, `Battery query successful`, `DPI raw response`
- **Pointer speed**: `setForDevice:`, `isLogitechDPI`, `ignoreSensitivity`
- **Side button capture**: `enableAddMode`, `disableAddMode`, `INITIALIZING MODIFIEDDRAG`, `Concluding addMode`
- **Legacy Page 65347**: `Ignoring legacy Logitech Page 65347` — if you see this unexpectedly, side button clicks are being dropped

### Quick Diagnosis Workflow
1. Check if HID++ activation succeeded: grep logs for `configured %d CID(s)` — should show `>= 0`.
2. Check if `isLogitechDiverted` is correctly set: look for `isLogitechDiverted = YES` after activation.
3. For side button issues, check if clicks arrive on Page 65347 or Page 9 by watching `handleInput` log output.
4. For speed issues, check if `isLogitechDPI = YES` and `multiplier = 0.333...` are applied in `setForDevice:`.

---

## 7. Sparkle Release & Code Signing Guide

### Background & Issue
When the signature specified in `appcast.xml` (`sparkle:edSignature`) does not match the actual update archive when verified against the App's built-in public key (`SUPublicEDKey`), Sparkle will abort the update. On macOS, this failure is presented to the user as a misleading extraction error:
```text
更新错误！解压过程中出现错误，请稍后再试。
```

### Strong Verification Hook
To prevent releasing broken updates, the `scripts/release.sh` script has been updated to perform a mathematical verification of the signatures before writing them to `appcast.xml`:
1. It extracts `SUPublicEDKey` dynamically from `App/SupportFiles/Info.plist`.
2. It uses an inline Swift script via `CryptoKit` to verify the generated `edSignature` against the newly compressed ZIP file.
3. If verification fails, the release script prints an error banner and exits with a non-zero status code, leaving `appcast.xml` untouched.

### Keychain Mismatch & Conflicts
The most common cause of mismatched signatures is **Keychain Key Mismatch**.
- **The Cause**: The `sign_update` tool reads from the Keychain matching service `https://sparkle-project.org` and account `ed25519`. If you develop multiple macOS apps that use Sparkle, you may have multiple `ed25519` private keys stored in your keychain. The system might resolve a private key belonging to another project, producing a signature that is mathematically valid for that key but rejected by Mac Mouse Fix's public key.
- **How to Resolve**:
  1. Inspect the comment (`icmt`) field of your Keychain credentials for service `https://sparkle-project.org` to find the one matching Mac Mouse Fix's public key (`bjptNX8PlJbdwtszqi3/BAHV4TYyZ3UuV1EMANJ+GaY=`).
  2. Clean up or isolate conflicting Sparkle keys.
  3. Alternatively, you can use Sparkle's `--account` parameter (e.g., storing the private key under account name `mac-mouse-fix`) to target the correct key and modify the `release.sh` variable `SIGN_TOOL` or key flags to pass `--account mac-mouse-fix`.

