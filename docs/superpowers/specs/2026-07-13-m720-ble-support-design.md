# Logitech M720 BLE Support Design

Status: approved in conversation on 2026-07-13

Implementation phase: 1 of 2 (Bluetooth Low Energy only)

## Summary

Mac Mouse Fix currently treats the Logitech M720 Triathlon as a generic HID
mouse. macOS exposes its standard middle, back, and forward buttons, but its
left tilt, right tilt, and thumb/gesture controls require Logitech HID++ 2.0
`REPROG_CONTROLS_V4` (`0x1B04`) diversion before software can receive them as
independent controls.

Phase 1 will add model-specific, reversible, and testable support for the M720
over BLE. The three proprietary controls will become stable Mac Mouse Fix
buttons 6, 7, and 8. A per-device asynchronous HID++ session will discover and
temporarily divert only controls that Mac Mouse Fix currently captures. When a
control is not configured, the mouse retains its exact native behavior.

Phase 2 will add Unifying receiver enumeration and slot routing behind the same
transport interface. Phase 1 must not claim Unifying support.

## Goals

- Recognize the BLE M720 by Logitech vendor ID `0x046D`, product ID `0xB015`,
  and BLE transport.
- Expose left tilt, right tilt, and thumb/gesture as stable Mac Mouse Fix
  buttons 6, 7, and 8.
- Preserve native middle, back, forward, horizontal tilt scrolling, and thumb
  behavior whenever Mac Mouse Fix is not capturing the corresponding control.
- Support the existing Mac Mouse Fix click, multi-click, hold, button-modifier,
  Click-and-Drag, and Scroll & Navigate machinery.
- Correctly handle simultaneous proprietary-button presses and arbitrary
  release order.
- Survive mouse sleep, BLE reconnect, Easy-Switch changes, Mac sleep/wake, and
  helper restart without stuck button state.
- Restore device reporting on configuration removal, kill switches, session
  deactivation, and all catchable helper termination paths.
- Detect competing HID++ ownership, especially Logi Options+, and report a
  stable conflict instead of repeatedly fighting over device state.
- Add runnable automated tests for the protocol, request state machine, input
  state machine, capture policy, and lifecycle behavior.
- Keep the protocol core transport-aware so receiver routing can be added in
  phase 2 without rewriting it.

## Non-goals

- Unifying, Bolt, or other receiver support in phase 1.
- Generic support for every Logitech HID++ mouse.
- Persistent changes to onboard mappings or feature `0x1C00`.
- Reprogramming Easy-Switch host-selection controls.
- Reprogramming the mechanical ratchet/free-spin wheel-mode switch.
- Changing the behavior of non-M720 mice or trackpads.
- Running a high-frequency keepalive or ownership tug-of-war with Logitech
  software.

## Existing behavior and evidence

- `DeviceManager` already matches the M720 because its BLE HID descriptor
  includes a Generic Desktop Mouse usage pair, even though its primary usage is
  Keyboard.
- The connected reference device reports BLE VID/PID `046D:B015` and exposes a
  vendor HID++ long-report channel (`0x11`).
- The HID descriptor declares button usages 1 through 16. `Device` currently
  uses the maximum usage as `nOfButtons`, so the M720 is incorrectly presented
  as a 16-button mouse.
- Current button input only consumes Core Graphics `OtherMouseDown` and
  `OtherMouseUp` events. HID++-only controls never reach that path.
- The closed upstream PRs
  [#1823](https://github.com/noah-nuebling/mac-mouse-fix/pull/1823) and
  [#1848](https://github.com/noah-nuebling/mac-mouse-fix/pull/1848) demonstrated
  that `0x1B04` diversion works on an M720, but their implementation is not safe
  to merge. It tests the wrong capability bit, parses only the first CID from a
  four-CID event, uses process-global response state, blocks in a nested
  RunLoop, and has no reliable pass-through or restoration lifecycle.
- The protocol definition for
  [`REPROG_CONTROLS_V4`](https://lekensteyn.nl/files/logitech/x1b04_specialkeysmsebuttons.html)
  defines a diverted-buttons event as the complete set of up to four currently
  pressed CIDs, not a single changed CID.
- Solaar's M720 BLE report documents model ID `B015405E0000`, HID++ 4.5, and
  the same target controls used by this design:
  [M720 B015 report](https://github.com/pwr-Solaar/Solaar/blob/master/docs/devices/M720%20Triathlon%20Multi-Device%20Mouse%20B015.txt).

## Device model and stable button mapping

Only the following physical controls are managed by phase 1:

| Physical control | HID++ CID | Native task | Mac Mouse Fix button |
| --- | ---: | --- | ---: |
| Left tilt | `0x005B` | Horizontal scroll left | 6 |
| Right tilt | `0x005D` | Horizontal scroll right | 7 |
| Thumb/gesture | `0x00D0` | Multi-platform gesture | 8 |

The following controls remain on the native Core Graphics path and are never
diverted by this feature:

| Physical control | HID++ CID | Mac Mouse Fix button |
| --- | ---: | ---: |
| Middle | `0x0052` | 3 |
| Back | `0x0053` | 4 |
| Forward | `0x0056` | 5 |

The target mapping is keyed by CID, never by enumeration order. Reconnection,
firmware table order, and the future receiver transport therefore cannot
renumber the buttons.

For the exact BLE M720 model, `Device` exposes an effective button count of 8.
The raw HID descriptor remains untouched; only the application-level
capability is corrected. Other device models continue using the existing
descriptor-derived calculation.

## Architecture

### `M720HIDPPController`

`DeviceManager` owns one controller for the helper process. The controller:

- filters attached devices to the exact phase-1 model and transport;
- owns a dictionary from stable device identity to `M720HIDPPSession`;
- creates a session only after the corresponding `Device` has been inserted
  into `attachedDevices`;
- tears down a session before the corresponding `Device` is removed;
- recomputes capture requirements after remap, Add Mode, kill-switch, active
  user, and lockdown changes;
- forwards sleep/wake and termination lifecycle events; and
- exposes readiness, error, and conflict state to the main app through the
  existing message-port boundary.

The controller is deliberately M720-specific. The HID++ codec and transport
are reusable, but model eligibility and CID policy are not generalized until
another model has fixtures and hardware coverage.

### `HIDPPTransport`

The transport boundary provides:

- a device index;
- asynchronous long-report sending;
- an input-report handler;
- cancellation/invalidation; and
- transport metadata used for response validation and diagnostics.

The phase-1 BLE implementation uses the already-open `IOHIDDevice` retained by
`Device`; it does not open or close the same device a second time. It uses HID++
device index `0xFF` and owns one input report buffer whose lifetime exceeds the
registered callback. The existing `Device` input-value callback is disabled,
so the new report callback has a single explicit owner.

The transport callback marshals state changes to the main queue, matching the
current `IOHIDManager` lifecycle. It never blocks that queue. Phase 2 can add a
receiver transport whose device index is the paired slot without changing the
codec or session.

### `M720HIDPPSession`

Each physical device has an independent session containing:

- a strong reference to the original `Device`;
- feature index and validated control metadata;
- one in-flight request and timeout at a time;
- a monotonically increasing lifecycle generation;
- original and last-written reporting state per target CID;
- desired and applied capture state per target CID;
- the ordered set of currently pressed target CIDs; and
- readiness, error, and conflict state.

Requests execute as a non-blocking asynchronous state machine. Responses must
match the transport's device index, feature index, function, and nonzero
software ID. Broadcast events use software ID zero. A response for another
software ID may inform conflict detection but can never complete Mac Mouse
Fix's request. Timeouts and late responses carry a generation and cannot mutate
a replaced or invalid session.

There is no process-global response buffer, nested RunLoop, or periodic
30-minute rewrite timer.

### Pure protocol and input state

Pure, IOHID-independent types handle:

- HID++ long-report encoding and validation;
- HID++ error decoding;
- root feature discovery;
- ReprogControlsV4 control-info and reporting-state decoding;
- target-control capability validation;
- capture-policy calculation;
- four-CID pressed-set parsing and state differencing; and
- ownership snapshot/restore decisions.

These types compile into both the helper and the new test bundle. Tests use a
scripted fake transport and do not require a mouse.

## HID++ protocol flow

All phase-1 commands use report ID `0x11`. The message layout is:

| Byte | Meaning |
| ---: | --- |
| 0 | Report ID (`0x11`) |
| 1 | Device index (`0xFF` for M720 BLE) |
| 2 | Feature index |
| 3 | Function ID in the high nibble, software ID in the low nibble |
| 4...19 | Parameters or results |

Session setup is:

1. Root `GetFeature(0x1B04)`.
2. ReprogControlsV4 `GetCount`.
3. `GetCidInfo` for each advertised row, with a bounded maximum count and
   strict response-length validation.
4. Locate each target CID and require both the mouse flag (bit 0) and divert
   capability (bit 5). Bit 4 is reprogrammability and is not a substitute for
   bit 5.
5. `GetCidReporting` for each target to establish the original snapshot.
6. Reconcile the desired capture policy.

Taking ownership uses `SetCidReporting` with byte-2 flags `0x03`, meaning
`divert=1` and `dvalid=1`. `persist`, raw XY, and remap are not changed.
Restoration changes only the temporary divert field by setting `dvalid=1` and
the snapshot's divert value.

Each write is followed by validation of the echoed response and a reporting
readback. A small bounded retry is allowed only for transient Busy or timeout
conditions. Malformed data, unsupported features, invalid capabilities, or a
terminal HID++ error fail without diversion.

## Capture policy and Add Mode

Each target button is independently either native or captured.

A button is captured when all of the following hold:

- the helper is enabled, unlocked, and associated with the active user;
- the button kill switch is off; and
- the button appears anywhere in the remap model as a direct trigger or button
  modifier, or Add Mode is actively recording buttons.

Capture is based on the presence of any binding, not only the keyboard
modifiers active at that instant. This avoids a timing race between a modifier
event, a BLE reporting command, and the physical button press. It also matches
the documented Mac Mouse Fix model: a configured button is captured completely
until all bindings for it are removed.

Consequences are intentional:

- an unconfigured left or right tilt remains native horizontal scrolling;
- an unconfigured thumb control retains the device's current native action;
- a configured target is handled exclusively by Mac Mouse Fix and cannot also
  trigger its native action; and
- restoring native behavior means removing all bindings for that target or
  disabling button handling.

Add Mode requires an asynchronous readiness handshake:

1. The helper prepares and verifies temporary diversion for buttons 6, 7, and
   8.
2. The add-field UI remains in a short waiting state until preparation
   succeeds.
3. Only then does the UI invite the user to press a button.
4. On cancellation or failure, controls not otherwise configured are restored.
5. After a binding is saved, only controls present in the resulting remap model
   remain captured.

Preparation timeout is surfaced to the user rather than silently losing the
first attempted button press.

## Input routing

The `divertedButtonsEvent` payload contains four big-endian 16-bit CID slots.
Zero slots are padding. The event is a complete snapshot of the currently
pressed diverted controls.

For each valid event:

1. Parse all four CID slots and reject structurally malformed payloads.
2. Preserve protocol order for the nonzero CIDs.
3. Compare the new set with the previous set.
4. Emit mouse-up for `old - new` and mouse-down for `new - old`.
5. Emit nothing for an unchanged set, including a set whose list order changed.
6. Ignore unknown CIDs for button mapping while retaining diagnostic context.

The session uses the fixed CID mapping to emit buttons 6, 7, and 8. A single
zero CID does not mean "release everything"; only the full set difference
controls release behavior.

Both Core Graphics and HID++ button input enter a common `ButtonInputContext`
containing:

- the real `Device`;
- button number and down/up state;
- a modifier snapshot;
- input source (`coreGraphics` or `hidpp`); and
- whether a real system event exists for pass-through.

The input router updates `HelperState.activeDevice` before starting a new click
cycle. Core Graphics builds the context from the real event. HID++ builds it
from the retained M720 `Device` and `Modifiers.modifiers(with: nil)`. `Buttons`
uses the supplied context instead of deriving device identity and modifiers
from a fabricated event.

HID++ input has no underlying Core Graphics event to pass through. This is
correct because only configured, fully captured controls are diverted. Standard
buttons 3, 4, and 5 continue through the existing Core Graphics path and retain
normal pass-through evaluation.

## Lifecycle and restoration

The session states are:

`discovering -> nativeReady -> takingOver -> active -> restoring`

Terminal or side states are `conflict`, `failed`, and `invalid`.

### Attach

1. `DeviceManager` creates and inserts the `Device`.
2. The controller creates the session and registers the input callback.
3. The session discovers and validates the feature/control table.
4. It snapshots reporting state and reconciles current capture policy.
5. Device/UI state is notified after the effective button count and readiness
   are coherent.

### Removal and reconnect

Removal order is deliberate:

1. Mark the session invalid so no new request can complete.
2. Emit mouse-up for every held target using the retained original `Device`.
3. Cancel request timeout and pending policy work.
4. Remove the report callback and invalidate the transport.
5. Remove the session.
6. Only then remove `Device` from `attachedDevices` and notify `SwitchMaster`.

A reconnect creates a fresh generation, rediscovers the feature index, and
reapplies current policy. No feature index or reporting state survives across
physical reconnection.

### Sleep and wake

Before system sleep, held target state is released locally and the session is
marked for reconciliation. On wake, the controller validates current reporting
state and reapplies only controls still required by current configuration. If
BLE removal/rematching occurs, the normal removal and attach paths take
precedence. Wireless-status changes from the device also trigger a bounded
reconciliation.

Normal mouse idle is not assumed to reset HID++ configuration. Event-driven
reconciliation replaces an unsupported periodic rewrite loop.

### Disable and termination

Button kill switch, helper lockdown, inactive user session, helper disable,
normal termination, and catchable `SIGTERM`, `SIGINT`, or `SIGHUP` all:

1. stop forwarding new HID++ buttons;
2. emit releases for held targets;
3. compare current reporting state with the value last written by Mac Mouse
   Fix; and
4. restore the original snapshot only when that comparison still matches.

`DeviceManager.deconfigureDevices` becomes a real asynchronous cleanup entry
point. The GCD-based termination handler waits for completion for a bounded
period while the main queue remains able to receive HID++ responses. Timeout
does not create a nested RunLoop or indefinite shutdown.

### Crash ownership journal

`SIGKILL` and process crashes cannot run cleanup. Before the first reporting
write, the controller records a small local ownership journal containing the
stable device identity, original reporting snapshot, and value written by Mac
Mouse Fix. Clean restoration clears the entry.

On the next launch, a matching journal entry allows the session to distinguish
its own stale temporary diversion from an unknown external owner's diversion.
It may reclaim or restore only if the device still matches the recorded
last-written value. Any mismatch is treated as external ownership and is never
overwritten automatically.

The journal stores no user content and never modifies mouse persistent memory.

## Logi Options+ and other ownership conflicts

HID++ temporary diversion is effectively last-writer-wins. Mac Mouse Fix does
not promise simultaneous ownership of the same CIDs with Logi Options+.

Conflict detection uses protocol state as the authority:

- reporting is read back immediately after takeover and during a short bounded
  verification window;
- relevant responses with another software ID trigger revalidation; and
- wake, reconnect, and wireless-status events also trigger revalidation.

Process detection may improve the user-facing explanation but is not the source
of truth.

If another owner changes a target after Mac Mouse Fix takes it:

1. release any held Mac Mouse Fix state;
2. stop writing that target and enter `conflict`;
3. do not run a high-frequency reclaim loop;
4. notify the main app once with guidance to quit Logi Options+; and
5. retry only after an explicit user action or a new device connection.

If the original reporting snapshot is already diverted and no valid Mac Mouse
Fix ownership journal explains it, the session starts in conflict rather than
stealing the control.

Movement, vertical scrolling, native middle/back/forward, and all non-target
devices remain available in every conflict and failure state.

## Error handling and diagnostics

The default failure policy is native behavior, not partial takeover.

- Unsupported `0x1B04`, missing target CIDs, missing mouse/divert capability,
  malformed frames, terminal HID++ errors, and exhausted timeouts leave targets
  native.
- Partial takeover is rolled back when setup for the required target set fails.
- Unknown notifications never complete a request or emit a mapped button.
- Duplicate, late, and stale-generation responses are ignored.
- Assertions are not used for recoverable external-device data.
- Logs include stable session identity, transport, request identity, state
  transition, retry, rollback, and conflict reason without logging unrelated
  input content.
- Attach-time failures remain quiet when the user has not configured target
  buttons. Add Mode or an existing target binding produces one actionable,
  localized error in the main app.

## UI and configuration behavior

- The M720 is presented as an 8-button mouse.
- Add Mode can capture left tilt, right tilt, and thumb as buttons 6, 7, and 8.
- No new permanent device setting is exposed in phase 1; capture remains driven
  by the existing remap table and button kill switch.
- Add Mode gains a short preparation state and explicit preparation failure.
- A localized conflict notification explains that Logi Options+ must release
  the controls and provides a retry action.
- Error/conflict notifications are deduplicated per session state and do not
  appear repeatedly while the condition is unchanged.

## Automated test strategy

The existing `Tests` target is a normal macOS application, not an XCTest
bundle. Phase 1 adds a real unit-test bundle while preserving that application.

The pure protocol and policy layers are tested with byte fixtures and a scripted
fake transport.

### Codec and discovery

- Encode Root `GetFeature(0x1B04)` and ReprogControlsV4 requests.
- Decode valid count, control-info, reporting, write-echo, and HID++ error
  responses.
- Distinguish capability bit 5 (divert) from bit 4 (reprogrammable).
- Reject short, oversized/invalid, wrong-report-ID, wrong-device-index,
  wrong-feature, wrong-function, and wrong-software-ID responses.
- Ignore a response for another request without completing the in-flight one.

### Session requests

- Execute discovery and setup in order with one request in flight.
- Retry bounded Busy and timeout failures.
- Ignore a response arriving after timeout or generation invalidation.
- Roll back partial takeover.
- Compare-and-restore only Mac Mouse Fix's own last-written value.
- Recover a matching stale ownership journal and reject a mismatching one.

### M720 mapping and capture policy

- Map `0x005B`, `0x005D`, and `0x00D0` to 6, 7, and 8.
- Never divert native middle/back/forward CIDs.
- Require exact model/transport and bit-5 capability.
- Capture each target for direct bindings, modifier use, and Add Mode.
- Restore each target after binding removal, Add Mode cancellation, kill switch,
  inactive session, or lockdown.
- Report effective button count 8 instead of descriptor value 16.

### Diverted-button state

- `[] -> [005B]` emits down(6).
- `[005B] -> [005B]` emits nothing.
- `[005B] -> [005B,005D]` emits only down(7).
- `[005B,005D] -> [005D]` emits only up(6).
- `[005D] -> []` emits up(7).
- Two-, three-, and four-CID sets tolerate arbitrary valid release order.
- Set-order changes emit nothing.
- A short payload cannot release or press anything.
- Disconnect with held controls emits exactly one release per mapped control.

### Lifecycle and conflict

- Attach then remove during every discovery step.
- Disable or terminate with active requests and held buttons.
- Wake reconciliation with state retained, reset, and externally changed.
- Reconnect creates a new generation and stable 6/7/8 mapping.
- An external reporting rewrite enters conflict and never starts a rewrite
  loop.
- A user retry after the conflict is cleared can take ownership once.

Verification order follows repository guidance: use an available remote/unit
test entry point first; if none exists, run the new XCTest scheme locally with
`xcodebuild`. Helper and App Release builds must also pass.

## BLE hardware acceptance matrix

The connected M720 BLE reference device is the phase-1 hardware target.

| Area | Check | Passing result |
| --- | --- | --- |
| Capability | Open Buttons UI | M720 contributes exactly 8 buttons |
| Native buttons | Middle, back, forward click/hold | Existing behavior, no duplicate events |
| Discovery | Enter Add Mode | Preparation completes or shows an actionable error |
| Mapping | Press left tilt, right tilt, thumb | Captured as 6, 7, and 8 |
| Actions | Single/multi-click and hold | Existing click-cycle semantics work |
| Gestures | Click-and-Drag and Scroll & Navigate | Start/end cleanly with the real M720 device identity |
| Modifiers | Use each target as a button modifier | Down/up state and dependent actions are correct |
| Chords | Hold two or three targets, release in every order | No missed or stuck state |
| Native restore | Remove all bindings for a target | Native action returns; tilt horizontally scrolls |
| Add Mode cancel | Enter then cancel without saving | All unconfigured targets return native |
| Kill switch | Disable and re-enable Buttons | Immediate release/restore, then clean reacquisition |
| Mouse power | Turn off/on, including while held | No stuck state; mapping returns after reconnect |
| Easy-Switch | Switch away and back | Clean detach/attach and stable numbering |
| Mac sleep | Sleep/wake repeatedly | Required targets work without helper restart |
| Helper lifecycle | Restart/disable helper | Reporting restores and reacquires correctly |
| Persistence | Compare device persistent mapping before/after | No persistent device changes |
| Conflict | Run Logi Options+, then quit and retry | One stable conflict; retry succeeds after release |
| Regression | Use another mouse and trackpad | Behavior is unchanged |

The release candidate must also cover repeated cycles: 20 sleep/wake cycles,
20 mouse power or BLE reconnect cycles, and held-button disconnects for each
target. Failures must be reproducible from logs without enabling verbose
keystroke or pointer logging.

## Phase-2 extension seam

Unifying support will add:

- receiver vendor-interface discovery;
- paired-slot enumeration and M720 WPID `0x405E` identification;
- mapping from receiver/slot to the logical `Device`;
- receiver connection/disconnection notifications; and
- a transport whose HID++ device index is the paired slot (`1...6`).

The codec, ReprogControlsV4 feature logic, target CID mapping, pressed-set state,
button input context, capture policy, ownership journal, and most tests remain
unchanged. Phase 2 needs its own receiver fixtures and complete hardware
acceptance matrix before support is advertised.

## Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| HID++ response interleaving | One request per session, full identity matching, no globals |
| Main-thread stalls or reentrancy | Asynchronous state machine, dispatch timeouts, no nested RunLoop |
| Simultaneous buttons lose state | Parse all four CIDs and diff complete sets |
| Wrong controls are diverted | Exact M720 model, exact CIDs, mouse flag, divert bit 5 |
| Native tilt/gesture regresses | No diversion without a binding or active Add Mode |
| Device removal leaves a held action | Release with retained original `Device` before removal |
| Helper exit strands temporary diversion | Compare-and-restore plus bounded termination cleanup |
| Crash prevents cleanup | Persistent local ownership journal and next-launch reconciliation |
| Options+ repeatedly steals controls | Detect conflict, stop writing, notify once, explicit retry |
| Phase 1 becomes a generic Logitech rewrite | Keep eligibility and CID policy M720-specific |
| Phase 2 requires protocol rewrite | Transport carries device index and endpoint identity from day one |

## Resolved product decisions

- Delivery is intentionally two-stage: BLE first, Unifying second.
- Phase 1 uses the M720-specific architecture, not a universal Logitech feature.
- Unconfigured targets preserve native behavior; configured targets are fully
  captured by Mac Mouse Fix.
- Logi Options+ conflicts are reported and require release/retry; Mac Mouse Fix
  does not continuously fight for ownership.
- Phase 1 is complete only after automated tests, Release builds, and the BLE
  hardware acceptance matrix pass.

There are no unresolved product decisions required before implementation
planning.
