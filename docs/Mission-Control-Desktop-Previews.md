# Mission Control with Desktop Previews (Experimental)

This is a separate button action alongside ordinary Mission Control. It opens/toggles
Mission Control while asking macOS to show the desktop thumbnails in the upper Spaces
bar. Existing bindings and the click-and-drag Spaces gesture are unchanged.

## Implementation and tradeoffs

The action table in `RemapTableTranslator.m` serializes a new `missionControlPreviews`
action type. `Actions.m` receives it through the normal button action pipeline (end
phases remain ignored), hops to the main run loop with `mfrun`, and invokes
`MissionControlPreviews` with the existing Mission Control symbolic-hotkey action (32).
Ordinary Mission Control still serializes `symbolicHotkey` / 32.

No documented public API for expanding the Spaces bar was found. This implementation
uses a **visible temporary cursor workaround**, not a new private expansion API:

1. Find the display containing the pointer using Quartz global coordinates.
2. Warp to one point below that display's top edge, at its horizontal centre.
3. Immediately invoke the existing Mission Control toggle.
4. After 0.5 seconds, restore the original position only if the pointer is still at
   our target and the original display position still exists.

The pointer is never hidden, disconnected, held in place, or repeatedly moved. No
mouse-moved events are synthesized. User motion cancels restoration: in that case,
the pointer remains wherever the user moved it. A second invocation first completes
the previous restoration when safe, invalidates its timer, and toggles normally. The
timer only restores the pointer; it never opens Mission Control again, including
after Escape/Cancel. There is no persistent change to Dock, Spaces, keyboard shortcuts,
security/TCC or licensing in this new code.

**Side effects and limits:** the pointer jump may be visible for up to 0.5 seconds.
A crash/termination during that interval can leave it at the top edge, but still
visible and movable. The fixed delay is a best-effort allowance, not a Dock readiness
contract. Busy systems, future macOS changes, fullscreen transitions, display layouts,
hot corners or other window managers can interfere. Failed geometry/warp operations
fall back to the normal toggle. If the OS or another process moves the pointer during
opening, the conservative restoration guard may leave it at that new position.
Rapid toggles are sent normally; macOS may ignore toggles during its animation.

The trigger already used by MMF (`SymbolicHotKeys.m`) relies on private CGS/SkyLight
symbolic-hotkey APIs and can temporarily enable/rebind an unusable shortcut, then
restore it. This action reuses that existing behaviour; it does not introduce a new
private Spaces API or claim public-API-only operation. The new cursor code creates no
key events/modifiers; the existing trigger posts its normal balanced key-down/up pair.

## Sources

- [Apple: Work in multiple spaces](https://support.apple.com/en-by/guide/mac-help/mh14112/mac)
  documents moving the pointer to the top edge in Mission Control to reveal Spaces.
- [Apple: Controlling the Mouse Cursor](https://developer.apple.com/library/archive/documentation/GraphicsImaging/Conceptual/QuartzDisplayServicesConceptual/Articles/MouseCursor.html)
  documents that cursor warp APIs do not generate mouse events. This is why this
  implementation prepositions before opening rather than relying on hover events.
- [BTT official action catalog](https://folivora.ai/features/actions/) lists separate
  Mission Control and Mission Control & Show Desktop Preview actions.
- [BTT author on the cursor workaround](https://community.folivora.ai/t/mission-control-with-desktop-previews-broken-on-mojave/5475)
  explains moving the pointer to the top and back, and interference limitations.
- [BTT author on the necessary delay](https://community.folivora.ai/t/mission-control-has-a-delay-to-display-the-desktop-preview/26275).
- [BTT community prepositioning discussion](https://community.folivora.ai/t/better-mission-control-immediately-show-desktop-preview/22948)
  reports the before-open technique and intermittent failures. These are observations,
  not an OS API guarantee.

## Validation and reproduction

Run deterministic lifecycle tests without desktop interaction:

```sh
Tests/MissionControl/run.sh
```

Nine scenarios cover restoration/idempotence, user movement, overlapping invocations
and stale completions, a moved origin between invocations, negative display origins,
a removed display, missing geometry, warp failure, and no reopening after cancellation.
A separate check validates English UI strings and the independent ordinary binding.

Build the isolated visual harness (same production cursor implementation):

```sh
xcrun clang -fobjc-arc -fmodules -fmodules-cache-path=/tmp/mmf-spaces-modules \
  -framework Foundation -framework AppKit -framework CoreGraphics \
  -I Helper/Core/Actions Helper/Core/Actions/MissionControlPreviews.m \
  Tests/MissionControl/harness.m -o /tmp/mmf-spaces-harness
/tmp/mmf-spaces-harness --info
/tmp/mmf-spaces-harness 600 500
# Optional fourth argument: a second toggle after this many seconds
/tmp/mmf-spaces-harness 50 600 0.25
```

The harness uses `open -a 'Mission Control'` as its toggle callback. It tests the exact
cursor code with real Dock UI without starting another Helper. It does **not** test a
physical MMF binding or the symbolic-hotkey callback end to end. Use coordinates from
`--info`; run in a graphical session with existing access, without adding permissions.
Escape exits Mission Control normally. Do not run a second MMF Helper for this test.

### Local results (21 October 2026)

macOS 27.0.1 (26A434), Xcode 27.1 (27A9275), two active displays:
`(0, 0, 1728, 1117)` and `(-3008, -305, 3008, 1692)`.

- All nine deterministic scenarios and the UI mapping check passed.
- Unsigned Debug build of App and embedded Helper passed. No app was installed or
  launched and no new signing credentials/profiles were requested.
- Harness from `(600, 500)` and `(1200, 800)`: expanded thumbnails visible in local
  screenshots, exact pointer restoration with unchanged physical mouse-move count.
  The user independently confirmed the `(600, 500)` opening looked correct.
- Escape after opening: local screenshot confirmed the ordinary desktop returned.
- Two calls 0.25 seconds apart from `(50, 600)`: desktop returned and pointer restored
  exactly, with unchanged physical mouse-move count.
- External display origin `(-1500, 400)`: expanded thumbnails visible on both displays,
  exact pointer restoration. No display/Spaces settings were changed.
- First exploratory run observed a changed pointer position during the interval
  (cause not established); restoration was conservatively skipped. Deterministic tests cover that ownership rule precisely.

Not tested: physical button binding through the new Helper; full-screen app
transitions; hot corners; other macOS versions; separate-Spaces settings variants;
display hot unplug on hardware (covered by fake geometry). The running daily MMF
Helper and its bindings were preserved. Local screenshots contain unrelated user
windows and are intentionally not published.

## Related

- [#684](https://github.com/noah-nuebling/mac-mouse-fix/issues/684): adjacent request
  for moving windows between Spaces. This action does not implement window transport.
- [#1871](https://github.com/noah-nuebling/mac-mouse-fix/issues/1871): Spaces gesture
  compatibility report. This separate toggle does not fix that gesture path.
