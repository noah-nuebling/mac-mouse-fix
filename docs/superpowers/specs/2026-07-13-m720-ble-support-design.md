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
- Route M720 input through the existing Mac Mouse Fix click, multi-click, hold,
  button-modifier, Click-and-Drag, and Scroll & Navigate machinery without a
  fabricated Core Graphics event.
- Correctly decode simultaneous proprietary-button presses and arbitrary
  release order, preserve button-modifier state, and leave no stuck cleanup
  state.
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
descriptor-derived calculation. This override is applied synchronously while
the `Device` is created, so the existing attach notification is not delayed by
HID++ discovery.

## Architecture

### `M720HIDPPController`

`DeviceManager` owns one controller for the helper process. The controller:

- filters attached devices to the exact phase-1 model and transport;
- owns a dictionary from the live IORegistry entry/device identity to
  `M720HIDPPSession`;
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
- invalidation with an asynchronous drain completion; and
- transport metadata used for response validation and diagnostics.

The phase-1 BLE implementation uses the already-open `IOHIDDevice` retained by
`Device`; it does not open or close the same device a second time. It sends with
HID++ device index `0xFF` and owns one input-report buffer whose lifetime
exceeds the registered callback. No active `Device` input-value callback exists
today, so the new report callback is the only IOHID callback introduced for
these vendor reports and does not affect the native Core Graphics path.

Transport teardown unregisters only its own input-report callback and releases
its own buffer/context. It never closes, cancels, or unschedules the shared
`IOHIDDevice`; those operations remain owned by `Device` and `DeviceManager`.

The transport callback marshals state changes to the main queue, matching the
current `IOHIDManager` lifecycle. Before the IOHID callback returns, it copies
exactly the reported byte count into immutable `Data`; no asynchronously
executing code may retain or read the reusable IOHID buffer. It never blocks the
main queue.

Registration, callback entry, unregistration, and callback-context release are
serialized on the main queue where the device is scheduled. Invalidation first
closes the send gate, increments the callback generation, and clears the report
handler on main. It then enqueues a fence behind every accepted
`IOHIDDeviceSetReport` block on the same dedicated serial I/O queue. Only after
that fence returns to main may teardown unregister the callback, release the
buffer/context, and complete its coalesced invalidation waiters. A late waiter
also completes asynchronously. This prevents callback unregistration or a new
same-device session from racing an old synchronous Set report. Already-copied
reports carry the old generation and are ignored. Phase 2 can add a receiver
transport whose device index is the paired slot without changing the codec or
session.

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

Requests execute as a non-blocking asynchronous state machine. Each request is
assigned an exact nonzero software ID, rotating through `0x8...0xF`. A normal
response must match report ID, the request's feature index, function, and exact
assigned software ID. BLE accepts response device index `0xFF` or the
documented BLE reply alias `0x00`, while requests always use `0xFF`. A timed-out
software ID is quarantined for the rest of that lifecycle generation, so a late
response cannot collide with a newer request. Exhausting all eight software IDs
is a terminal request error until a new lifecycle generation is created.

HID++ 2.0 errors use their special layout
`[0x11, device, 0xFF, originalFeature, originalFunctionAndSoftwareID,
errorCode, ...]`; their original feature, function, and exact assigned software
ID must match the in-flight request. Broadcast events use software ID zero. A
response for another software ID may trigger conflict revalidation but can
never complete Mac Mouse Fix's request. Timeouts and late responses carry a
generation and cannot mutate a replaced or invalid session.

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

These types compile into the Helper, its hosted test bundle, and the read-only
diagnostic command-line target. Automated tests use a scripted fake transport
and do not require a mouse.

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
3. `GetCidInfo` for each advertised row, rejecting a count above 32 and using
   strict response-length validation.
4. Locate each target CID and require both the mouse flag (bit 0) and divert
   capability (bit 5). Bit 4 is reprogrammability and is not a substitute for
   bit 5.
5. `GetCidReporting` for each target to establish the original snapshot.
6. Reconcile the desired capture policy.

Every entry into `takingOver`, regardless of source state, performs a fresh
`GetCidReporting` preflight for the complete new required set immediately
before writing any journal `prepared` phase or sending any
`SetCidReporting`. This includes `nativeReady`, explicit retry, policy/Add Mode
changes, and `restoring -> takingOver`. With no valid journal, a clean baseline
means the full current state still equals the trusted discovery snapshot and
`divert=0`. A valid journal may instead explain an exact current `intended`
state. Any other value closes the input gate, sends zero takeover writes, rolls
back other targets still provably owned by this session, and enters `conflict`.
No unrelated asynchronous session step is allowed between preflight and the
serialized write transaction.

An explicit conflict-recovery retry may replace an untrusted/stale baseline
only after one fresh readback shows all three target CIDs have `divert=0`. Their
then-current non-divert reporting fields become the new trusted baseline. This
is how retry succeeds after Options+ releases ownership without ever adopting
an unknown diverted state.

Taking ownership uses `SetCidReporting` with `parameters[2] = 0x03`, meaning
`divert=1` and `dvalid=1`. `persist`, raw XY, and remap-valid bits remain clear,
so persistent mapping, raw XY, and remap state are not changed. Restoration
changes only the temporary divert field by setting `dvalid=1` and the
snapshot's divert value.

Each write validates the correlated response fields that the device supplies,
then treats a fresh `GetCidReporting` readback as authoritative; a full payload
echo is not assumed. A request times out after 1 second. Busy is retried twice,
after 50 ms and 200 ms. A timeout is retried once after 200 ms with a new
software ID. Malformed data, unsupported features, invalid capabilities,
terminal HID++ errors, or exhausted retries fail without leaving a partial
diversion.

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

The configured targets form one required target set for a session. A policy
change is reconciled as an atomic session transaction: release local held
state, compare-and-restore the previously owned set, then take over and verify
the new set. If any required CID fails takeover, readback, or conflict
validation, the session compare-and-restores every target it still owns and
exposes no partial active set. A conflict therefore applies to the M720
session, not to one CID.

Add Mode uses an asynchronous request-ID handshake over the existing message
ports; no synchronous port callback waits for HID++:

The Helper has only one HID ownership path. The Add Mode coordinator freezes a
Controller snapshot containing the monotonic device-set revision, environment
enablement, and each sorted live `(deviceToken, exactRequiredCIDs)` participant,
then asks the Controller for its single opaque temporary-policy lease. The
Controller validates the whole frozen set atomically and applies overrides only
through each session's ordinary `setRequiredCIDs` transaction. Attach, removal
start, or pending replacement changes the revision and cancels the operation;
new participants never inherit a lease. A rollback that cannot be verified
keeps the lease blocked and journal entries intact, preventing a superseding
takeover. Readiness remains provisional until its queued delivery turn: the
Controller rechecks the live token, required-CID, and stable-state predicate at
delivery, and uses the same predicate before clearing a lease.

Environment disable has priority over both saved policy and the lease: its
effective target is empty until every remaining participant is stably native.
The frozen/saved baseline remains cached and is reacquired, with fresh
preflight, only after a later re-enable. Synthetic Add Mode remaps may update
environment enablement but never overwrite the saved-policy cache.

| Direction | Message | Contract |
| --- | --- | --- |
| App -> Helper | `prepareAddMode` | UUID `requestID`; immediately acknowledges `{accepted}` within the existing one-second message-port limit |
| Helper -> App | `addModePreparationResult` | Same `requestID`; `ready`, `failed`, `conflict`, or `cancelled`; stable error code and session-lifetime opaque `deviceToken` list |
| App -> Helper | `cancelAddModePreparation` | Same `requestID`; immediately acknowledges and invalidates that preparation generation |
| App -> Helper | `renewAddModeLease` | Same `requestID`; sent every 2 seconds while preparing/recording and immediately acknowledged |
| App -> Helper | `finishAddMode` | Same `requestID`; sent after saving a binding; immediately acknowledges, disables effective Add Mode, and reconciles saved configuration |
| Helper -> App | `addModeStateChanged` | Same `requestID`; reports post-ready transition to `inactive` with `saved`, `cancelled`, `deviceSetChanged`, or `appUnavailable` reason |
| App -> Helper | `retryM720Capture` | New UUID `requestID` plus `deviceToken`; immediately acknowledges |
| Helper -> App | `m720CaptureStateChanged` | `deviceToken`, session state, stable error code when applicable, and optional `requestID` when caused by retry |
| App -> Helper | `getM720CaptureStates` | Read-only synchronous snapshot used when the app opens or reconnects to the helper |

Message-level `failed` is an Add Mode operation result, not an additional
session state.

At accepted-request time, the controller freezes the set of currently attached
M720 session tokens and each session's exact pre-prepare required set. It treats
those participants as one transaction and temporarily requires target CIDs 6,
7, and 8 on each. The result is `ready` only after every participant verifies
takeover. Only then does the helper enable `Remap`'s effective Add Mode flag and
the UI invite the user to press a button. Preparation has an overall 5-second
deadline beginning at acknowledgement.

Every accepted preparation request emits exactly one
`addModePreparationResult`. `ready` completes the preparation handshake but
keeps the same request ID as the active recording lease. A cancel before ready
produces the one `cancelled` preparation result. A cancel after ready first
calls `Remap.disableAddMode`, then reports `addModeStateChanged(inactive)`; it
never emits a second preparation result.

A new prepare request atomically supersedes the old generation: the helper
closes effective Add Mode if enabled, attempts the rollback transaction below,
emits the old request's one outstanding terminal message, and only then may
start the accepted new request. Any M720 attach or detach between accept and
`finishAddMode` cancels the generation with `deviceSetChanged`; this also covers
an M720 attaching while the immediate generic/no-M720 Add Mode path is
recording. The user can retry against the new frozen participant set.

Failure, cancellation, deadline, or device-set change first compare-and-restores
only states still provably written by Mac Mouse Fix, then uses the ordinary
fresh-preflight transaction to re-establish each remaining participant's exact
saved required set, not blindly all-native. If disconnect, external mismatch,
or transport error prevents verified rollback/re-establishment, the controller
retains the journal, leaves that session `invalid`/`conflict`, and returns a
failed/conflict result. A superseding prepare is not started and receives its
own terminal failure; no blind write or new takeover occurs.

A late completion is suppressed by request ID and generation, and the app
ignores a message for a request that is no longer current. On successful save,
`finishAddMode` keeps the temporary lease active while reloading config,
updating the Controller's saved cache, switching the lease target to that new
effective policy, and verifying it. Only then does it clear the lease and
publish inactive(saved). Accepted finish is irreversible: app termination or a
queued preparation-context notice cannot restore the old baseline. If the
device/environment context changes during finish verification, the Helper
retries the current-saved transaction in the new context before clearing.

The request ID is also a lease: the app renews it every 2 seconds and the helper
cancels after 5 seconds without renewal. An `NSWorkspace` main-app termination
notification cancels immediately; the lease covers a crash or missed
notification. Thus app exit cannot leave Add-Mode-only diversion active.

Stable error codes are `unsupported`, `protocol`, `timeout`, `conflict`,
`disconnected`, `cancelled`, `deviceSetChanged`, and `appUnavailable`. If no
M720 is attached, preparation returns `ready` immediately and then follows the
same lease/finish lifecycle for existing generic Add Mode. A retry with a stale
or unknown `deviceToken` synchronously returns `{accepted: false,
error: disconnected}` and emits no async result; every accepted retry emits one
correlated capture-state result after reaching a stable state.

Retry acceptance is synchronous on the Helper main turn. The session returns a
Boolean and has no second retry-result observer. The Controller stores at most
one pending request ID and consumes it on the next token-guarded stable-state
publication, including a disconnected removal publication. Ordinary stable
dedupe ignores request ID, while a nonnil accepted retry forces exactly one
correlated publication even if the stable state key did not otherwise change.

Mutation-route decoders receive the raw nullable payload object so a wrong root
class is a protocol rejection rather than an Objective-C/Swift bridge trap.
Callbacks acknowledge before queued takeover work, including the no-M720 path.
The App typed dispatcher and diagnostic-state receiver are separate follow-up
work; this phase only shares codecs and implements Helper mutation routes.

## Input routing

The `divertedButtonsEvent` payload contains four big-endian 16-bit CID slots.
Zero slots are padding. The event is a complete snapshot of the currently
pressed diverted controls.

For each valid event:

1. Require the complete long report, expected feature/event header, and all four
   CID slots; reject duplicate nonzero CIDs or any structurally malformed
   payload without changing the previous pressed set.
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
from the retained M720 `Device` and an immutable copy of
`Modifiers.modifiers(with: nil)`. `Buttons` uses the supplied context instead
of deriving device identity and modifiers from a fabricated event.

The button engine gains an explicit `cancel(device:button:)` cleanup path.
Release/end callbacks use a `ButtonInputKey` made from
`ObjectIdentifier(device)` plus button, not the button alone or an optional
cross-launch identifier. Registration, lookup, removal, and
`cancel(device:button:completion:)` are serialized on the existing button
queue. Cancellation atomically invalidates that key's cycle generation, drains
its cleanup callbacks exactly once, kills a matching active click cycle, and
does not synthesize a click action or pass-through event.

Every timer or asynchronous button callback captures the cycle generation and
rechecks it on the button queue before registering cleanup or starting a hold
action. Matching mouse-up, replacement by another cycle, ordinary `kill()`, and
explicit cancellation all advance that generation before doing their own
release/transition work. A delayed callback that loses any of those four races
is a no-op. Disconnect, sleep, policy change, conflict, and shutdown await the
asynchronous cancellation completion for every held target before releasing
its `Device`.

HID++ input has no underlying Core Graphics event to pass through. This is
correct because only configured, fully captured controls are diverted. Standard
buttons 3, 4, and 5 continue through the existing Core Graphics path and retain
normal pass-through evaluation.

The existing action engine has one global direct `ClickCycle`. Phase 1
therefore guarantees complete HID++ down/up differencing, button-modifier
semantics, and exact cleanup without sticky state, but does not promise that two
different target buttons execute two independent direct click/hold actions in
parallel. Expanding direct-action concurrency is a separate all-mouse engine
change, not part of M720 transport support.

## Lifecycle and restoration

The session has exactly these states:

| State | Meaning and allowed transitions |
| --- | --- |
| `discovering` | No HID++ target input is forwarded. Successful discovery enters `nativeReady`; unsupported or terminal discovery enters `invalid(reason)` while native mouse behavior remains available. |
| `nativeReady` | Mac Mouse Fix owns no target and leaves current device behavior untouched. A nonempty required set enters `takingOver`; an empty set stays native. |
| `takingOver` | The whole required set is being written and verified. Input is not forwarded until every CID verifies. Success enters `active`; cancellation, policy change, or error enters `restoring`; observed external ownership restores what is still ours, then enters `conflict`. |
| `active` | Only the verified required set is forwarded. The same policy stays active. Any policy change, disable, wake mismatch, or shutdown enters `restoring`. Observed external ownership restores what is still ours, then enters `conflict`. |
| `restoring` | Held input is cancelled and each still-owned target is compare-and-restored. An empty desired set enters `nativeReady`; a new nonempty set enters `takingOver`; an external mismatch enters `conflict`; exhausted transport/restoration errors retain the journal and enter `invalid(reason)`. |
| `conflict` | No target input is forwarded and no automatic takeover write occurs. Clearing all target bindings enters `nativeReady`. An explicit retry or a fresh connection may enter `takingOver` only after a clean authoritative readback. |
| `invalid` | No request or event may mutate the session. Removal tears it down; an explicit retry after discovery failure creates a new generation/session. |

Every asynchronous completion carries the lifecycle generation and expected
state. No completion is allowed to skip the transitions above.

Every exit from `active` first closes the session input gate and increments the
event generation synchronously, before starting cancellation or any HID++
read/write. Queued copied reports and button callbacks from the old generation
then become no-ops. Only after held inputs finish exact-once cancellation may
the session perform asynchronous compare-and-restore.

### Attach

1. `DeviceManager` creates the `Device`, applies the M720 button-count override,
   inserts it, and sends the existing `SwitchMaster` attach notification
   immediately.
2. The controller creates the session and registers its input-report callback.
3. The session asynchronously discovers and validates the feature/control
   table.
4. It snapshots reporting state and reconciles current capture policy.
5. HID++ readiness/error/conflict is reported separately; discovery never
   delays native middle, back, forward, movement, or scrolling.

### Removal and reconnect

Removal order is deliberate:

1. Set `isTearingDown`, increment the generation, and reject new normal input
   without clearing the held-CID set.
2. Call the dedicated button cancellation path for every held target using the
   retained original `Device`, and await all button-queue cleanup completions.
3. Invalidate the request pipeline, fail stale request continuations, close the
   transport send gate, and enqueue the serial I/O-queue drain fence. If the
   transport is already unavailable, retain any applied journal entry for
   reconnect recovery instead of pretending restoration succeeded.
4. After the fence, unregister only this session's input-report callback and
   release its buffer and context on main.
5. Enter `invalid(disconnected)` and complete removal waiters; shutdown waiters
   joined to the same terminal drain complete only after removal waiters.
6. Remove the session only after that completion. A reconnect with the same
   journal identity waits for every invalidating older session token before its
   factory may create or start the replacement, so no old Set can land after
   new recovery reads or journal reconciliation.
7. Only then remove `Device` from `attachedDevices` and notify `SwitchMaster`.

A reconnect creates a fresh generation, rediscovers the feature index, and
reapplies current policy. No feature index or reporting state survives across
physical reconnection.

### Sleep and wake

Before system sleep, held target state is released locally and the session is
marked for reconciliation. On wake, the controller validates current reporting
state and reapplies only controls still required by current configuration. If
BLE removal/rematching occurs, the normal removal and attach paths take
precedence.

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
point owned by an idempotent `ShutdownCoordinator`. Starting shutdown
immediately rejects new takeover and Add Mode work and coalesces repeated
termination requests.

For normal AppKit exit, the helper implements `applicationShouldTerminate:`,
returns `NSTerminateLater`, and calls
`replyToApplicationShouldTerminate:` after cleanup completes or the overall
3-second deadline expires. `applicationWillTerminate:` is not relied upon for
asynchronous work.

For a catchable signal, the signal source remains on a background queue,
dispatches shutdown start to the main queue, and waits on the background queue
for completion or the same 3-second deadline. The main queue never waits and
therefore remains able to receive HID++ replies. The signal handler then
restores the default disposition and re-raises the original signal. A deadline
exit leaves the journal intact for next-launch reconciliation; it never starts
a nested RunLoop or waits indefinitely.

### Crash ownership journal

`SIGKILL` and process crashes cannot run cleanup. Cross-launch ownership uses a
versioned `M720HIDPPOwnership-v1.plist` in the helper's Application Support
directory. The runtime session dictionary is keyed by the connected IORegistry
entry/device lifetime; that ephemeral key is never used for crash recovery.

The cross-launch device key is the exact tuple `(VID, PID, transport,
nonempty SerialNumber)`. `PhysicalDeviceUniqueID` is retained only as a
diagnostic/cross-check because its reconnect stability is not assumed. If the
serial is absent, or two attached devices collide on the tuple, capture is not
attempted: the session remains native and reports `unsupported` rather than
performing an unrecoverable write.

The journal is atomically replaced through a temporary file and stores, per
CID, the full original reporting snapshot, intended temporary state, and one of
these phases:

1. `prepared` is persisted before sending `SetCidReporting`.
2. `applied` is persisted only after a correlated response and authoritative
   readback equal the intended state.
3. `restoring` is persisted before sending the compare-and-restore write.
4. The CID entry is removed only after readback equals the original state; an
   empty device entry is then removed.

Next-launch reconciliation reads every CID independently before forming the
session-level required-set transaction:

| Journal phase | Current state | Decision |
| --- | --- | --- |
| `prepared` | equals original | The device write did not take effect; clear the CID entry. |
| `prepared` | equals intended | Promote to `applied`, then keep it only if current policy still requires capture; otherwise restore. |
| `applied` | equals intended | Keep/reclaim it if current policy requires capture; otherwise restore. |
| `applied` | equals original | The device reset or another owner restored the baseline; clear the CID entry, then use the fresh preflight before any policy-required takeover. |
| `restoring` | equals original | Restoration completed before the crash; clear the CID entry. |
| `restoring` | equals intended | Keep it if current policy now requires capture; otherwise retry restoration. |
| any | equals neither recorded state | Treat as external ownership, perform no write to that CID, roll back other still-owned CIDs, and enter session `conflict`. |

Entries for disconnected devices remain until that exact device returns.
Unknown schema versions or corrupt files are quarantined and cause no automatic
recovery write. An explicit retry may establish a new snapshot only when fresh
authoritative readback shows all three M720 targets have `divert=0`; any unknown
diverted target remains conflict and can never be adopted as the original
baseline. Tests inject crashes at every phase boundary, including partial
multi-CID takeover and `applied` state reset by power/reconnect. The journal
stores no user input and the transport never sends persistent mapping feature
`0x1C00`.

## Logi Options+ and other ownership conflicts

HID++ temporary diversion is effectively last-writer-wins. Mac Mouse Fix does
not promise simultaneous ownership of the same CIDs with Logi Options+.

Conflict detection uses protocol state as the authority:

- reporting is read back immediately after takeover and again after 250 ms,
  2 seconds, and 10 seconds;
- an observed relevant response with another software ID starts the same
  readback sequence;
- wake and reconnect perform an immediate authoritative readback; and
- an `NSWorkspace` application-launch notification for Logi Options+ or its
  known agent starts the same sequence, with sequence starts rate-limited to
  once per 2 seconds.

An initial scan of already-running applications applies the same trigger when a
session first becomes active.

Process detection may improve the user-facing explanation but is not the source
of truth.

These triggers detect observed or lifecycle-correlated changes; the design does
not claim continuous detection of an otherwise unobservable write after the
10-second window. There is no periodic rewrite or polling loop.

If another owner is observed changing any required target after Mac Mouse Fix
takes it:

1. atomically enter `restoring(target: conflict)`, close the input gate, and
   invalidate the old event generation;
2. cancel every held Mac Mouse Fix input and await its cleanup completion;
3. compare-and-restore every target whose current state still equals the value
   Mac Mouse Fix last wrote, without touching the externally changed target;
4. place the whole session in `conflict` with the input gate still closed;
5. notify the main app once with guidance to quit Logi Options+; and
6. retry only after an explicit user action or a new device connection.

If a required target's original reporting snapshot is already diverted and no
valid Mac Mouse Fix ownership journal explains it, the session starts in
conflict rather than stealing the control. Unconfigured targets are never
rewritten merely because another program currently owns them.

Movement, vertical scrolling, native middle/back/forward, and all non-target
devices remain available in every conflict or discovery-error condition.

## Error handling and diagnostics

Before takeover, the failure policy is to leave device behavior untouched. Once
Mac Mouse Fix owns a target, it reports only a readback-verified restore and
never exposes a partially active required set.

- Unsupported `0x1B04`, missing target CIDs, missing mouse/divert capability,
  malformed discovery frames, terminal discovery errors, and exhausted
  pre-takeover timeouts leave targets untouched.
- Partial takeover is compare-and-rolled back when setup for the required
  target set fails. If transport loss prevents verified rollback, the session
  becomes `invalid`, retains its journal, and reports that native target
  availability cannot be guaranteed until reconnect recovery; it never claims
  a restore that was not read back.
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
- Add Mode gains the specified asynchronous preparation state, 5-second
  deadline, cancellation, and explicit preparation failure.
- A localized conflict notification explains that Logi Options+ must release
  the controls and provides a retry action.
- Error/conflict notifications are deduplicated per session state and do not
  appear repeatedly while the condition is unchanged.

## Automated test strategy

The existing `Tests` target is a normal macOS application, not an XCTest
bundle. Phase 1 preserves it and adds a Helper-hosted XCTest bundle with shared
scheme `M720 HIDPP Tests`. Its Test Host is the Debug Mac Mouse Fix Helper. The
scheme sets `MMF_M720_UNIT_TESTING=1`, which skips real IOHID registration,
event taps, launchd/service work, and production signal installation, then
injects fake devices, transport, clock, scheduler, journal store, and shutdown
sessions. This makes `Buttons`, `DeviceManager`, IPC, and shutdown integration
tests executable instead of pretending they are pure codec tests.

The pure protocol and policy types are compiled into the Helper and exercised
from the same bundle with byte fixtures and a scripted fake transport.
Time-dependent tests use the injected clock/scheduler and do not sleep in
wall-clock time.

### Codec and discovery

- Encode Root `GetFeature(0x1B04)` and ReprogControlsV4 requests.
- Decode valid count, control-info, reporting, correlated write responses, and
  the HID++ 2.0 special error-frame layout.
- Distinguish capability bit 5 (divert) from bit 4 (reprogrammable).
- Accept BLE response device index `0xFF` and `0x00`; reject every other index,
  short or oversized/invalid frames, wrong report ID, feature, function, and
  exact software ID.
- Ignore a response for another request without completing the in-flight one.
- Add raw reference-M720 fixtures for every successful request/response shape
  and for a harmless deliberately invalid request that produces a real HID++
  error response.

### Session requests

- Execute discovery and setup in order with one request in flight.
- Reject a control count above 32.
- Assert the 1-second timeout, Busy retries at 50/200 ms, and one timeout retry
  after 200 ms.
- Rotate exact software IDs through `0x8...0xF`, quarantine timed-out IDs, and
  ignore responses arriving after timeout or generation invalidation.
- Exercise every documented state transition and reject completions for the
  wrong state/generation.
- Re-read the whole required set immediately before takeover; an external
  change after attach but before adding a binding must enter conflict with zero
  `SetCidReporting` requests.
- Expand an already-active required set after an external change to the new CID;
  the `restoring -> takingOver` preflight must also enter conflict with zero
  takeover `SetCidReporting` requests.
- Roll back partial takeover for the whole session required set.
- Compare-and-restore only Mac Mouse Fix's own last-written value.
- Inject crashes before/after every per-CID journal phase update, including a
  partially applied multi-CID transaction; recover exact matches and reject
  mismatches, corrupt schemas, absent serials, and duplicate identities.
- Clear `applied` when a power/reconnect reset returns current state to original,
  then require a fresh preflight before policy-driven reacquisition.

### M720 mapping and capture policy

- Map `0x005B`, `0x005D`, and `0x00D0` to 6, 7, and 8.
- Never divert native middle/back/forward CIDs.
- Require exact model/transport and bit-5 capability.
- Capture each target for direct bindings, modifier use, and Add Mode.
- Restore each target after binding removal, Add Mode cancellation, kill switch,
  inactive session, or lockdown.
- Report effective button count 8 instead of descriptor value 16.
- Prove the M720 override does not delay the existing attach notification.
- Assert the fake transport never sends feature `0x1C00` and that persist, raw
  XY, and remap fields are unchanged across takeover/restoration readbacks.

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
- Copy modifier state immutably and set the retained M720 as active device.
- Interleave Core Graphics and HID++ input from two devices without sharing a
  release callback key.
- Cancel held Click-and-Drag, Scroll & Navigate, modifier, and hold actions
  exactly once without firing a pending click or fabricating pass-through.
- Race mouse-up, cycle replacement, ordinary kill, and explicit cancellation
  against hold timers/delayed button-queue callbacks; stale generations cannot
  register cleanup or start a hold action.
- Copy an IOHID report before callback return, unregister before buffer/context
  release, and ignore copied reports queued before teardown.
- Verify simultaneous direct-button edges reach the existing global click-cycle
  policy without promising independent parallel direct actions.

### Add Mode IPC

- A prepare request acknowledges immediately and resolves asynchronously with
  the same UUID and exactly one preparation result.
- Ready is emitted only after every frozen participant verifies all three
  targets, and enables effective Add Mode exactly once.
- Cancellation before/after ready, overlapping prepare, 5-second deadline,
  disconnect, new-device attach, and one-session failure close effective Add
  Mode and restore each participant's exact pre-prepare required set.
- If supersede/cancel rollback is externally changed, disconnected, or times
  out, retain the journal, emit conflict/failure for both affected generations,
  and send no new takeover write.
- Saving disables Add Mode and reconciles the saved remap rather than the old
  baseline.
- Lease renewal succeeds every 2 seconds; main-app termination or 5 seconds
  without renewal cancels and rolls back.
- A late ready/result for a cancelled or superseded request is ignored by both
  helper and app.
- No attached M720 preserves the immediate generic path, but attaching an M720
  during that recording cancels it for a prepared retry.
- A stale retry token is rejected synchronously; every accepted retry produces
  exactly one correlated stable-state result.

### Lifecycle and conflict

- Attach then remove during every discovery step.
- Disable or terminate with active requests and held buttons.
- Wake reconciliation with state retained, reset, and externally changed.
- Reconnect creates a new generation and stable 6/7/8 mapping.
- Normal shutdown and `SIGTERM`, `SIGINT`, and `SIGHUP` coalesce cleanup,
  release held state, and complete or hit the exact 3-second deadline while the
  main queue continues handling replies.
- External rewrites found by immediate/250 ms/2 s/10 s verification, another
  software ID, wake, reconnect, or Logi Options+ launch enter one session-level
  conflict and never start a rewrite loop.
- Conflict first closes the input/event generation; reports arriving during
  rollback cannot recreate held state.
- A user retry after the conflict is cleared can take ownership once.

### Hardware diagnostic target

Phase 1 also adds a command-line target and shared scheme named
`M720 HIDPP Diagnostic`. It has two read-only subcommands:

- `helper-snapshot` queries `getM720DiagnosticState` over the existing helper
  message port. Sorted JSON contains `deviceToken`, session state/generation,
  required/applied/pressed CIDs, cumulative sent feature/function counts, and
  the last 256 request identities `(feature, function, CID, generation)`. It
  sends no IOHID request.
- `device-snapshot --vid 046d --pid b015` requires the helper port to be absent,
  opens the matching BLE device, and sends only Root/ReprogControlsV4 `Get`
  requests. Sorted JSON contains the serial-based device key and, for each
  target CID, raw reporting flags, `divert`, `persist`, raw-XY, and remap CID.
  It refuses to run concurrently with the helper.

Neither output includes pointer, key, or action content. The exact build and
snapshot commands are:

```sh
xcodebuild -project "Mouse Fix.xcodeproj" -scheme "M720 HIDPP Diagnostic" -configuration Debug -derivedDataPath /tmp/mmf-m720-diagnostic build
'/tmp/mmf-m720-diagnostic/Build/Products/Debug/M720 HIDPP Diagnostic' helper-snapshot
'/tmp/mmf-m720-diagnostic/Build/Products/Debug/M720 HIDPP Diagnostic' device-snapshot --vid 046d --pid b015
```

The last command is intentionally expected to refuse while the helper is
running. For post-exit readback and signal acceptance, first build the Direct
Helper, boot out the KeepAlive job, and run that build directly:

```sh
xcodebuild -project "Mouse Fix.xcodeproj" -scheme "Helper - Direct" -configuration Debug -derivedDataPath /tmp/mmf-m720-direct build
launchctl bootout "gui/$(id -u)/com.nuebling.mac-mouse-fix.helper"
'/tmp/mmf-m720-direct/Build/Products/Debug/Mac Mouse Fix Helper.app/Contents/MacOS/Mac Mouse Fix Helper' &
helper_pid=$!
kill -TERM "$helper_pid"
wait "$helper_pid" || true
'/tmp/mmf-m720-diagnostic/Build/Products/Debug/M720 HIDPP Diagnostic' device-snapshot --vid 046d --pid b015
```

Repeat from the direct-helper launch with `-INT` and `-HUP`. A separate
`-KILL` run validates journal recovery: the first post-exit snapshot may equal
the recorded intended diversion, restarting the Direct Helper must adopt the
matching journal without conflict, and a subsequent normal quit must restore
the original snapshot. For the normal-exit row, replace `kill` with:

```sh
osascript -e 'tell application id "com.nuebling.mac-mouse-fix.helper" to quit'
wait "$helper_pid" || true
```

After acceptance, re-enable the helper through Mac Mouse Fix so its service is
registered again.

The repository currently has no remote unit-test runner for this target, so the
defined verification commands are:

```sh
xcodebuild -project "Mouse Fix.xcodeproj" -scheme "M720 HIDPP Tests" -configuration Debug -destination 'platform=macOS' test
xcodebuild -project "Mouse Fix.xcodeproj" -scheme "M720 HIDPP Diagnostic" -configuration Debug build
xcodebuild -project "Mouse Fix.xcodeproj" -scheme "Helper - Release" -configuration Release -destination 'platform=macOS' build
xcodebuild -project "Mouse Fix.xcodeproj" -scheme "App - Release" -configuration Release -destination 'platform=macOS' build
```

All four commands must exit zero. If a remote macOS unit runner becomes
available before implementation finishes, run the same shared scheme there
first, then use the local commands for hardware-adjacent verification.

## BLE hardware acceptance matrix

The connected M720 BLE reference device is the phase-1 hardware target.

| Area | Check | Passing result |
| --- | --- | --- |
| Capability | Open Buttons UI | M720 contributes exactly 8 buttons |
| Native buttons | Middle, back, forward: 20 presses and one hold each | Exactly one logical down/up per press, no duplicate action, hold ends once |
| Discovery | Enter Add Mode | Ready within 5 seconds or one actionable error; UI never invites a press before ready |
| Mapping | Press left tilt, right tilt, thumb 20 times each | Each produces exactly one 6, 7, or 8 down/up pair and no other mapped button |
| Actions | Test single/multi-click and hold on each target separately | Each matches the current one-cycle action semantics and ends once |
| Gestures | Run Click-and-Drag and Scroll & Navigate, then release/disconnect | Real M720 is active device; start/end occur once; no residual drag/scroll state |
| Modifiers | Hold each target as a modifier while triggering another configured action | Dependent action sees modifier down; release removes it exactly once |
| Chords | Run `helper-snapshot` while holding two/three targets and release in every order | `pressedCIDs` contains the exact held set; every edge is present and no modifier/cleanup state remains stuck; independent parallel direct actions are not asserted |
| Native restore | Remove all bindings for each target in turn | Readback equals original state; tilt resumes horizontal scrolling and thumb resumes its prior native action |
| Add Mode cancel | Enter then cancel before and after preparation completes | No late ready reopens capture; every unconfigured target readback equals original |
| Kill switch | Disable and re-enable Buttons while each target is held | One local release, original readback on disable, verified reacquisition on enable |
| Mouse power | Turn off/on, including while each target is held | One cleanup per held target; fresh generation and stable 6/7/8 mapping return |
| Easy-Switch | Switch away and back | Clean detach/attach, stable serial identity, stable numbering, no stale completion |
| Mac sleep | Sleep/wake | Required targets work without helper restart and authoritative readback matches policy |
| Normal exit | Quit the helper while every target is captured, once with one held | Process exits within 3 seconds; held cleanup runs once; an independent post-exit diagnostic readback equals original before restart/reacquisition |
| `SIGTERM` | Signal helper while every target is captured, once with one held | Original signal termination occurs within 3 seconds; independent post-exit readback equals original; no stuck action |
| `SIGINT` | Repeat the `SIGTERM` procedure with `SIGINT` | Same result |
| `SIGHUP` | Repeat the `SIGTERM` procedure with `SIGHUP` | Same result |
| `SIGKILL` crash recovery | Kill the Direct Helper while captured, snapshot, restart with the same config, then quit normally | Matching intended state is adopted from the journal without conflict; final post-quit snapshot equals original |
| Persistence | Compare `device-snapshot` and `helper-snapshot` before/after all tests | Persist/raw-XY/remap fields are identical and cumulative request counts contain no feature `0x1C00` |
| Conflict before takeover | Let Logi Options+ actively own a target, snapshot counters, then request capture | One conflict within the 5-second preparation deadline; the `SetCidReporting` counter does not increase |
| Conflict after takeover | Reach active, then launch Logi Options+ | One conflict within the 10-second verification window; still-owned targets restore; retry succeeds only after release |
| Regression | Run the existing button scenarios with another mouse and trackpad | Event/action counts equal the pre-change baseline |

Release sign-off, rather than every inner implementation loop, additionally
requires zero failures across 20 sleep/wake cycles, 20 mouse-power or BLE
reconnect cycles, and held-button disconnects for each target. Failures must be
reproducible from logs without enabling verbose keystroke or pointer logging.

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
| HID++ response interleaving | One request per session, exact software-ID/generation matching, timeout quarantine, no globals |
| External write races takeover | Fresh whole-set preflight immediately before serialized writes, authoritative post-write readback, and conflict on mismatch; HID++ offers no compare-and-swap |
| Main-thread stalls or reentrancy | Asynchronous state machine, dispatch timeouts, no nested RunLoop |
| Simultaneous buttons lose state | Parse all four CIDs, diff complete sets, and cancel cleanup per device/button |
| Existing direct actions are globally serialized | Preserve current click-cycle semantics; guarantee input edges/modifiers/cleanup, not new parallel action engines |
| Wrong controls are diverted | Exact M720 model, exact CIDs, mouse flag, divert bit 5 |
| Native tilt/gesture regresses | No diversion without a binding or active Add Mode |
| Device removal leaves a held action | Dedicated cancellation with retained original `Device` before teardown |
| Helper exit strands temporary diversion | Compare-and-restore with a 3-second nonblocking shutdown coordinator |
| Main app disappears during Add Mode | Two-second lease renewal, five-second expiry, termination notification, exact baseline rollback |
| Crash prevents cleanup | Atomic per-CID journal phases and exact-device next-launch reconciliation |
| Options+ repeatedly steals controls | Triggered authoritative readbacks, session-level rollback, notify once, explicit retry |
| Phase 1 becomes a generic Logitech rewrite | Keep eligibility and CID policy M720-specific |
| Phase 2 requires protocol rewrite | Transport carries device index and endpoint identity from day one |

## Resolved product decisions

- Delivery is intentionally two-stage: BLE first, Unifying second.
- Phase 1 uses the M720-specific architecture, not a universal Logitech feature.
- Unconfigured targets preserve native behavior; configured targets are fully
  captured by Mac Mouse Fix.
- Logi Options+ conflicts are reported and require release/retry; Mac Mouse Fix
  does not continuously fight for ownership.
- The currently required CID set is one atomic session transaction; phase 1
  never exposes partial ownership.
- Phase 1 preserves the existing single global direct click-cycle behavior. It
  adds correct simultaneous HID++ edges, modifiers, and cleanup, not independent
  parallel direct-action engines.
- Phase 1 is complete only after automated tests, Release builds, and the BLE
  hardware acceptance matrix pass.

No design choice remains open in this specification. Implementation planning
begins only after the user confirms this written version.
