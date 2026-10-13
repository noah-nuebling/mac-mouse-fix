# Embedded InstantSpaceSwitcher

Source: https://github.com/jurplel/InstantSpaceSwitcher

Snapshot: `f7616e42651b1ed8d81625e3640eceed6efa8018`.

The C library and event serializer are distributed under the MIT license in
`InstantSpaceSwitcher-LICENSE.txt`. That license is also copied into the app and
helper resource bundles. Mac Mouse Fix's existing license still applies to its
own code.

Mac Mouse Fix calls `iss_switch()` directly for the optional instant drag action.
It does not call `iss_init()`, install the library's global gesture tap, intercept
trackpad swipes, or require the InstantSpaceSwitcher app to be running.

Changes to the upstream snapshot are confined to `iss_switch()`:

- Lazily initialize the per-display prediction dictionary, without a global tap.
- Refresh the cached natural scrolling setting for each switch.
- Return false when Space information cannot be read, rather than sending an
  unbounded fling. This avoids passing the last Space on macOS 27.

The near-zero progress, high-velocity Began/Changed/Ended sequence, macOS 27 HID
payload serialization, display selection, and boundary predictions come from
InstantSpaceSwitcher. The original interception and overlay APIs remain in the
snapshot for comparison but are not activated by Mac Mouse Fix.

## Using the option

In Buttons, select **Spaces & Mission Control (Instant)** for a Click and Drag
action. A horizontal drag switches one Space when it crosses Mac Mouse Fix's
existing activation threshold. Release and drag again to switch another Space.
Direction follows the system natural scrolling setting, just like the existing
Spaces action. Up still enters Mission Control and down still enters App Exposé
through the original continuous gesture code. The existing dropdown choice and
saved mappings retain their behavior.

## Verification

Run `Tests/InstantSpaces/run.sh` on macOS with the command-line developer tools.
The tests capture posted events instead of sending them to the desktop. They
cover the legacy and macOS 27 event sequences, end-of-Spaces boundaries, rapid
switch predictions, prediction expiry, missing Space data, and per-display
active Space selection.

Build the complete application with Xcode using the shared `App` scheme. Full
application builds also verify the dropdown, helper integration, localization,
and resource dependencies. On-device acceptance should check both natural
scrolling settings, horizontal release/cancellation, Mission Control, App
Exposé, fullscreen Spaces, and multiple displays.
