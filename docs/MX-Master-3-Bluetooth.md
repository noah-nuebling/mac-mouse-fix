# MX Master 3 special buttons over Bluetooth

This experimental, opt-in implementation routes the MX Master 3 Gesture and Mode Shift controls through Mac Mouse Fix's existing button bindings. It does not require Logitech Options/Options+ or another remapper.

## Supported scope

| Property | Scope |
| --- | --- |
| Model/transport | MX Master 3, directly connected over Bluetooth Low Energy |
| USB vendor/product identity | `046D:B023` |
| HID++ vendor collection | Usage page `0xFF43`, usage `0x0202` |
| Device index | Direct device `0xFF` |
| Required feature | HID++ 2.0 `ReprogControlsV4`, feature ID `0x1B04` |
| Gesture | Advertised CID `0x00C3` or alias `0x00D0` → MMF Button 6 |
| Mode Shift | Advertised CID `0x00C4` → MMF Button 7, only while needed |

An alias is a protocol candidate, not evidence of support for another model. The tested mouse advertised `0x00C3`; `0x00D0` is covered by the in-memory tests. MX Master 3S/4, MX Anywhere, Unifying/Bolt receivers, USB connections, multiple receiver slots and other product IDs are outside this change. The horizontal thumb wheel is not Button 7; this change does not add horizontal-wheel or tilt support.

The upper button behind the main wheel is Mode Shift, sometimes called a DPI button in feature requests. It normally toggles ratchet/free-spin. While diverted, that press runs an MMF binding instead. Firmware SmartShift, scroll modes, DPI and onboard profiles are not configured here.

## Enable the experiment

Back up the configuration and stop competing remappers before testing. In the existing MMF config, set the following **inside `General`**, preserving all other keys and bindings:

```xml
<key>logitechMXMaster3SpecialButtons</key>
<true/>
```

Restart the helper after changing this startup opt-in. Missing/false means that this implementation creates no HID++ manager and sends no protocol requests. This PR does not change the default config or edit a user's settings automatically.

`General.logitechMXMaster3DivertModeShift` from the earlier personal fork is obsolete and ignored. Mode Shift follows effective bindings instead of a persistent opt-in.

## Bind and restore the buttons

### Gesture / Button 6

With the experiment enabled, open **Buttons**, hover over **+**, press/release the button under the thumb, and select an action for **Button 6**. Click, hold, multiple clicks, click-and-drag and click-and-scroll use the ordinary MMF mapping pipeline; no separate gesture interpreter is added. Gesture stays diverted while the experiment's helper runs, even without a saved Button 6 binding.

### Mode Shift / Button 7

1. Without a Button 7 binding, the upper button remains a native ratchet/free-spin toggle.
2. Hover over **+**. Add mode temporarily captures Mode Shift for recognition. Allow a Bluetooth round trip before pressing it.
3. Press/release the upper button. The row is **Button 7**. Choose an action to save a binding.
4. Dismiss the action menu without choosing an action to cancel. A newly captured Button 7 row is provisional: cancelling does not save MMF's usual default action.
5. Remove the last binding that uses Button 7 to return native wheel switching. Bindings that use Button 7 as a modifier for another button, dragging or scrolling also require diversion.

Leaving the Add field, changing tabs, closing/deactivating the window or normally quitting the GUI ends temporary Add mode. Saved bindings keep working in the background helper when the GUI is closed, consistent with ordinary MMF behavior. Disabling MMF or normally terminating its helper restores owned controls.

| Helper state | Button 7 binding | Add mode | Mode Shift behavior |
| --- | --- | --- | --- |
| Running, opted in | No | No | Native wheel toggle |
| Running, opted in | No | Yes | Temporary Button 7 capture |
| Running, opted in | Yes | Either | MMF Button 7 |
| Disabled/normally terminated | Either | No | Restore previous reporting state |
| Crash/SIGKILL/unreachable mouse | Either | Either | Restoration cannot be guaranteed; power-cycle if necessary |

## Implementation

### Startup and effective remaps

`DeviceManager` schedules initialization on `IOThread.runLoop` rather than reading config synchronously during device setup. Config initialization completes before that run loop starts. This prevents a silent opt-out caused by reading an uninitialized config.

`Remap.setRemaps:` forwards each effective remap snapshot to the diverter, including equal snapshots. Button 7 trigger keys or button modifier preconditions request Mode Shift. Add mode already supplies temporary feedback mappings for all buttons, so it uses the same policy path; cancelling reloads saved remaps. UI lifecycle callbacks close gaps where AppKit might omit `mouseExited`.

`Device.nOfButtons` exposes at least seven virtual button numbers for this opted-in device so SwitchMaster and Add mode can use the normal pipeline. This is a capability bound, not a count of physical switches. The tested device's ordinary HID descriptor already declares Button usages 1–16; MMF's reset hint reflects that declaration rather than counting physical buttons.

### Transport and discovery

`LogitechButtonDiverter` owns a dedicated run-loop worker. All request sequences, policy updates, verification and restoration pass through one serial work queue. A request pumps the run loop while awaiting its response; callbacks only enqueue further command sequences, so they cannot interleave requests.

The manager matches only the supported product's vendor collection and opens it without exclusive seizure. Discovery resolves feature ID `0x1B04`, enumerates the advertised control count and `getCidInfo` capability flags, and requires the divertable bit `0x20` for a candidate CID. Optional feature `0x1D4B` supplies reconnect notifications when advertised.

Requests use long report `0x11`. Framing accepts complete short/long reports with or without an IOKit-supplied report ID. Replies must match device, feature, function and a rotating nonzero software ID. CID replies must echo the requested CID. Protocol errors, truncated frames, timeouts and unrelated reports do not satisfy a request.

### Reporting and ownership

Before writing a CID, the helper reads and saves its reporting flags and remap bytes. Already-diverted controls are skipped, including controls left diverted by a different remapper. No blanket device reset is performed.

Only temporary diversion is changed: `setCidReporting` flags `0x03` enable it; `0x02` disable it. The remap parameter is zero, meaning unchanged. Permanent diversion, raw XY and wheel-mode configuration are not enabled. A write requires an acknowledgement and reporting readback. Ownership is recorded before sending so a write accepted by firmware with a lost ACK still has a cleanup path.

Restoration checks both current and original reporting state. It clears only the diversion bit this helper changed and verifies the exact original state. If another client changed reporting/remapping meanwhile, the helper relinquishes ownership without overwriting it. There is no atomic hardware ownership primitive: concurrent remappers remain unsupported.

Policy changes reconcile only affected controls. Adding/removing a Mode Shift binding preserves Gesture ownership and held state. Failed/unreachable restoration retains cleanup responsibility for a subsequent retry while the helper remains running.

### Input and recovery

HID++ diverted-button notifications are complete four-CID held snapshots. Production pure helpers validate the frame and convert the owned snapshot into down/up edges. Aliases cannot produce duplicate downs; releases precede new presses.

The helper posts `otherMouseDown`/`otherMouseUp` with MMF's integer pressure convention and the real mouse's IORegistry sender ID (CGEvent field 87), routing Button 6/7 through the existing mouse attribution, button, modifier and drag handlers. It does not generate a second drag stream or suppress cursor motion.

Disconnect, sleep and reprobe release held synthetic buttons. A timer verifies owned CIDs every 30 seconds and retries initially sleeping devices. Wake reprobes after three seconds; an optional wireless-status notification schedules a 0.3-second reprobe. These recovery paths have automated coverage but have not all been physically exercised.

Normal termination and SIGTERM/SIGINT—including launchd disable—serialize cleanup onto the worker and wait up to four seconds. Objective-C/IOKit work is never called directly from a POSIX signal handler. Essential acquisition, ownership release and failure diagnostics remain at info/error level; per-control discovery and periodic reporting traces use debug logging.

### GUI insertion regression

A newly inserted Button 7 row can be outside the table's realized viewport. Opening its popup with `makeIfNecessary:NO` raised `RowDoesntContainPopupButtonException` and crashed the GUI while the helper stayed alive. Popup lookup now requests cell creation. The AppKit regression compiles the production lookup and exercises an unrealized bottom row in a real table without showing a window or posting input events.

## Validation

```sh
Tests/Logitech/run.sh
plutil -lint 'Mouse Fix.xcodeproj/project.pbxproj'
git diff --check
xcodebuild -project 'Mouse Fix.xcodeproj' -scheme App -configuration Release \
  -derivedDataPath /tmp/mmf-mx-master-3-build CODE_SIGNING_ALLOWED=NO build
```

Prerequisites: macOS, Xcode/command-line tools and Python 3. Framing/state and fake-transport lifecycle tests use AddressSanitizer/UBSan. They cover complete/truncated frames, correlated replies, aliases, duplicate and simultaneous holds, all 64 ownership transitions, startup deferral with a real CFRunLoop, exact reporting preservation, foreign ownership, lost-ACK rollback, initial sleep retry, recovery of the second CID, binding add/remove/reload, Add-mode cancellation, modifier bindings, disable/quit/re-enable and shutdown idempotence. CGEvent posting is intercepted; no HID manager is opened and no input event is posted by these tests. The AppKit test exercises cell realization separately.

### Local build and signing

An unsigned build proves compilation only. Do not treat it as a runnable physical test artifact: Keychain Sharing and macOS input permissions apply to the exact signed app/helper. Use a valid development identity and the existing app/helper entitlements for local testing. If a personal team cannot register upstream's bundle identifiers, use unique local identifiers consistently in a disposable source copy, including the app/helper IPC names; keep those identifiers, team settings, profiles, keys and build outputs out of this PR. Preserve trial/payment/licensing logic.

Grant Accessibility and Input Monitoring through System Settings for the exact signed helper when needed. No permission reset or automatic security-setting change is added by this feature. Existing upstream permission/startup behavior is outside this patch. A signed, separately identified development copy was used for physical QA; the installed applications and their configurations were kept separate. Do not run two helpers or competing remappers against the same mouse.

### Physical evidence and remaining matrix

On 2026-10-21, the tester confirmed Gesture/Button 6 and the binding-controlled upper-button behavior working on their MX Master 3 over BLE after the GUI fix. Actual device replies showed feature index `0x09`, eight advertised controls, Gesture `0x00C3` and Mode Shift `0x00C4` with flags `0x31`. Reporting readbacks confirmed native `0x00`, owned diversion `0x01`, and restoration to `0x00`. These are real protocol observations, separate from automated tests. The tester's confirmation is not an exhaustive button/gesture regression suite.

Still requiring broader physical validation: repeated menu cancellation and binding deletion/disable cycles, long holds and simultaneous buttons in both release orders, all drag/scroll actions, reconnect during a hold, sleep/wake, Bluetooth timeouts and multiple devices. Other models, USB and receivers are unsupported, not silently claimed as tested. Rebasing/refactoring against current upstream does not itself revalidate hardware behavior.

For manual review, bind harmless actions first. Verify Button 6, then exercise Button 7 Add → Cancel → native toggle, Add → choose action → bound press, delete last binding → native toggle, and disable helper → native toggle. Check that ordinary Back/Forward, scrolling and cursor motion remain usable. Record real down/up events and reporting transitions; synthetic events do not prove physical button support.

## Limitations and recovery

SIGKILL, a crash, power loss, a lost GUI cancel IPC message or an unreachable/asleep/disconnected mouse can prevent restoration. HID++ temporary diversion has no process lifetime lease. Power-cycle the mouse if a control stays diverted; stop competing remappers before retrying. A lost release notification with an otherwise reachable mouse cannot be distinguished from an intentional long hold until another snapshot arrives. Recovery releases may complete a pending MMF action, so use harmless mappings during testing.

This is a draft device-specific implementation, not a notarized release or a universal Logitech driver. Closing only the GUI intentionally keeps saved mappings active in the helper.

## Attribution and related work

Derived from lcandy2's [PR #1995](https://github.com/noah-nuebling/mac-mouse-fix/pull/1995), transport/request-queue commit [`a874b40130ba0ab9bbea9e3eab57b5fa5de12f34`](https://github.com/lcandy2/mac-mouse-fix/commit/a874b40130ba0ab9bbea9e3eab57b5fa5de12f34), through the personal fork's [`1bc1d03d97a4d69d05852396bfdd3d3010b2d44c`](https://github.com/meded90/mac-mouse-fix-mx-master-3/commit/1bc1d03d97a4d69d05852396bfdd3d3010b2d44c). The MMF License and upstream attribution remain unchanged. No proprietary Mouser/Logitech code or private application files are included.

Open protocol references: [Solaar](https://github.com/pwr-Solaar/Solaar), including its ReprogControlsV4 definitions, and the MIT-licensed [Mouser](https://github.com/TomBadash/Mouser). These informed compatibility research; their model/transport coverage is not inherited by this patch.

## Related feature requests

These are related requests, not automatic closing claims. Several concern models, controls or actions outside this implementation.

| Request group | Issues and boundary |
| --- | --- |
| Gesture recognition | [#450](https://github.com/noah-nuebling/mac-mouse-fix/issues/450) (MX Master 3), [#1144](https://github.com/noah-nuebling/mac-mouse-fix/issues/1144) (for Mac variant unverified), [#1220](https://github.com/noah-nuebling/mac-mouse-fix/issues/1220), [#1714](https://github.com/noah-nuebling/mac-mouse-fix/issues/1714) |
| Gesture and upper button | [#226](https://github.com/noah-nuebling/mac-mouse-fix/issues/226) is the closest combined request; [#1253](https://github.com/noah-nuebling/mac-mouse-fix/issues/1253) concerns 3S, [#1695](https://github.com/noah-nuebling/mac-mouse-fix/issues/1695) spans Master/Anywhere, [#1759](https://github.com/noah-nuebling/mac-mouse-fix/issues/1759) concerns Master 4; those models are unverified |
| Earlier models | [#1102](https://github.com/noah-nuebling/mac-mouse-fix/issues/1102), [#1193](https://github.com/noah-nuebling/mac-mouse-fix/issues/1193), [#2060](https://github.com/noah-nuebling/mac-mouse-fix/issues/2060) concern 2S; this PR does not support or test 2S |
| Mixed button and wheel requests | [#253](https://github.com/noah-nuebling/mac-mouse-fix/issues/253), [#775](https://github.com/noah-nuebling/mac-mouse-fix/issues/775): Gesture input is relevant, horizontal thumb-wheel support remains outside scope; the “wheel 7” in #253 is not this PR's synthetic Button 7 |
| Mixed recognition/action/UI requests | [#1252](https://github.com/noah-nuebling/mac-mouse-fix/issues/1252), [#1472](https://github.com/noah-nuebling/mac-mouse-fix/issues/1472), [#1682](https://github.com/noah-nuebling/mac-mouse-fix/issues/1682), [#1744](https://github.com/noah-nuebling/mac-mouse-fix/issues/1744): this PR addresses the scoped input path, not every requested action or UI change; #1682's 3S remains unverified |
| Context, not a verified fix | [#1590](https://github.com/noah-nuebling/mac-mouse-fix/issues/1590) (Master 4 extra control/scroll/tracking), [#1978](https://github.com/noah-nuebling/mac-mouse-fix/issues/1978) (ambiguous press-drag behavior) |
| Historical/protocol context | [#591](https://github.com/noah-nuebling/mac-mouse-fix/issues/591) is closed around click actions, not proof that special-button support was delivered; [#1277](https://github.com/noah-nuebling/mac-mouse-fix/issues/1277) discusses HID++ 2.0, but its M650 buttons 4/5 are not supported by this patch |
