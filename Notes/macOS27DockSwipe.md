# macOS 27 Dock Swipe Compatibility

## Context

On macOS 27 beta, synthetic dock-swipe gestures stopped working when Mac Mouse Fix posted only the public `CGEvent` gesture fields. The affected user-facing actions are Spaces, Mission Control, App Expose, Show Desktop, and Launchpad-style dock swipes.

The core approach is based on PR [#1895](https://github.com/noah-nuebling/mac-mouse-fix/pull/1895), which in turn references the reverse-engineering work around InstantSpaceSwitcher / FasterSwiper and the serialized `CGEvent` field `4205`.

## Root Cause

Dock no longer appears to treat the public synthetic gesture fields as sufficient input on macOS 27. It expects the raw IOKit HID gesture payload embedded in the serialized `CGEvent`. Without that payload, the event still posts, but Dock ignores it.

The fix augments dock-swipe events by:

- serializing the already-built `CGEvent`
- parsing the private big-endian field format
- inserting or replacing field `4205` with a raw HID payload
- rebuilding the event with `CGEventCreateFromData()`

## Multi-Display Handling

On macOS 27, Dock also appears to associate an in-flight dock-swipe stream with the display implied by the raw HID position fields. For modified-drag gestures, the synthetic dock-swipe event is therefore anchored to the drag origin instead of the live cursor position.

If the real pointer leaves the drag-origin display before button release, the current synthetic dock-swipe stream is ended once at the drag origin and then suppressed until the physical drag ends. This avoids continuing one gesture stream across two displays, which can leave Dock's gesture state stuck.

For this cross-display termination, `Ended` is used instead of `Cancelled` because it matches a normal gesture lifecycle and allows Dock to settle the in-progress transition instead of rolling it back.

## Validation

Validated locally on macOS 27 with:

- single-display modified drag to switch Spaces
- dual-display modified drag, including moving the real cursor across displays mid-drag
- repeated cross-display drags without losing subsequent modified-drag gestures
- cursor visibility and position after release
- scroll direction and other helper features after install

The local validation build was signed with the same App/Helper entitlements as the working 3.0.8-based test build.
