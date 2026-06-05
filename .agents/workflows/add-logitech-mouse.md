# Workflow: Adding Support for a New Logitech Mouse Model

This workflow covers the steps to verify and add support for a new Logitech mouse model to Mac Mouse Fix.

## Prerequisites
- Physical access to the mouse for testing
- The mouse must support Logitech HID++ 2.0 (almost all post-2015 Logitech mice do)
- Mac Mouse Fix built and running from the development environment

## Step 1: Device Identification

Connect the mouse and check the helper logs for automatic detection:

```bash
# Watch helper logs in real-time
log stream --predicate 'process == "Mac Mouse Fix Helper"' --style compact
```

Look for:
```
LogitechCIDActivator: Found active device index 0xXX on '<device name>'
```

If this line appears, the device is already detected and being configured. Note:
- **Device Index**: `0xFF` = direct USB/BLE, `0x01-0x06` = Unifying receiver slot
- **Product Name**: Used for sibling device matching

## Step 2: Feature Verification

Check which features are supported by looking at the logs:

| Log Entry | Feature |
|---|---|
| `Found Adjustable DPI feature index 0xXX` | `0x2201` (standard DPI) |
| `Extended DPI support: 1` | `0x2202` (extended DPI, newer models) |
| `Found SmartShift feature index 0xXX` | `0x2111` or `0x2110` (scroll wheel mode) |
| `Found wireless status feature 0x1D4B` | Wireless reconnection detection |
| `configured %d CID(s)` | `0x1B04` (ReprogControlsV4, button diversion) |

## Step 3: Button Mapping Verification

### Diverted mice (ReprogControlsV4 supported)
The log should show:
```
LogitechCIDActivator: side-button CID 0x0053/TID ... will be diverted as Button 4
LogitechCIDActivator: side-button CID 0x0056/TID ... will be diverted as Button 5
```

Test: Press side buttons → verify MMF captures them in the Buttons tab.

### Non-diverted mice (no ReprogControlsV4)
The mouse will use the legacy Page 65347 path. Check:
1. `isLogitechDiverted` should remain `NO`
2. Side button presses should generate `usagePage == 65347` events with values `83` (Back) and `86` (Forward)
3. These should be remapped to virtual button 4/5 events

**Common issue**: If the mouse declares native Page 9 button elements but doesn't actually send them, the legacy path must still process Page 65347 events. The current code handles this correctly (no `deviceHasNativeButton` filter in the legacy block).

## Step 4: DPI Verification

If the mouse supports DPI control:
1. Open the Mouse tab → verify the DPI slider appears
2. Drag the slider → verify the mouse speed changes in real-time
3. Check log for: `DPI query successful. DPI: <value>`
4. Verify the DPI range makes sense (typically 200-4000 or 400-8000)

**If the DPI range is wrong:**
Check `getDPICapabilities:forDevice:` parsing. Some models use non-standard page/response formats. The current code supports both `0x2201` and `0x2202` with range-compression encoding.

## Step 5: Wireless Reconnection Verification

1. Turn the mouse off and back on
2. Watch logs for reconnection detection:
   - Unifying: `Unifying reconnection event detected`
   - HID++ 2.0: `Wireless reconnection event (StatusBroadcast via feature 0x1D4B)`
3. After reconnection, verify:
   - Buttons still work (CID diversion was re-applied)
   - DPI is still at the saved value (not firmware default)
   - SmartShift mode is still correct

## Step 6: SmartShift Verification (if applicable)

1. Open the Mouse tab → verify the scroll wheel mode controls appear
2. Toggle between Ratchet and Free-spin → verify the wheel physically changes mode
3. Enable SmartShift (auto-switch) → verify it works
4. If the mouse supports tunable torque (`0x2111`): verify the torque slider appears

## Step 7: Edge Cases to Test

1. **Sleep/Wake**: Put Mac to sleep → wake → verify all settings restored
2. **Receiver swap**: If using Unifying, swap receivers → verify re-detection
3. **Multi-mouse**: Connect both the new mouse and another Logitech mouse → verify independent configuration
4. **Add Mode capture**: In the Buttons tab, try adding a custom mapping for side buttons → verify click-and-drag capture works

## Troubleshooting

If something doesn't work, use the `logitech-hidpp-debug` skill for systematic diagnosis.

### Quick Checks
```bash
# Check if device is detected
log stream --predicate 'process == "Mac Mouse Fix Helper"' --style compact 2>&1 | grep -i "LogitechCIDActivator"

# Check if DPI is being queried
log stream --predicate 'process == "Mac Mouse Fix Helper"' --style compact 2>&1 | grep -i "DPI"

# Check button events
log stream --predicate 'process == "Mac Mouse Fix Helper"' --style compact 2>&1 | grep -i "handleInput\|injectButton\|postVirtualButton"
```

## Files That May Need Modification

For most new Logitech mice, **no code changes are needed** — the activator dynamically probes features and adapts. However, in rare cases:

| Scenario | File to Modify | What to Change |
|---|---|---|
| New button type with unknown CID | `LogitechCIDActivator.m` → `buttonForCID()` | Add CID → button number mapping |
| New TID that should be kept native | `LogitechCIDActivator.m` → `kNativeTIDs[]` | Add TID to the skip list |
| New DPI feature variant | `LogitechCIDActivator.m` → `queryBatteryAndDPIForDevice:` | Add feature ID lookup and response parsing |
| New SmartShift feature variant | `LogitechCIDActivator.m` → `getSmartShiftState:` | Add feature ID and function mapping |
| New battery feature variant | `LogitechCIDActivator.m` → `queryBatteryAndDPIForDevice:` | Add feature ID lookup |
| New wireless reconnection format | `LogitechCIDActivator.m` → `inputReportCallback` | Add report pattern matching |
