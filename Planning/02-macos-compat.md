# 02 — macOS Tahoe (26) / Golden Gate (27) Compatibility

Date: 2026-08-22 · Local test OS: macOS 27.0 (26A5416b)

## Compatibility matrix (feature × OS status)

Legend: ✅ works · ⚠️ partial/regressions · ❌ broken · ❓ unknown/unverified

| Feature | macOS 26.x Tahoe | macOS 27.x Golden Gate (beta) |
|---|---|---|
| Install / launch / Accessibility prompt | ⚠️ startup crash reported on 26.5.2 (#1923) | ⚠️ "not working" reports on public beta (#1967); helper crash #1926 |
| Button capture & remapping (basic clicks) | ✅ (mostly) | ✅ per multiple GG beta reports (#1931 comment, #1961) |
| Click actions via side buttons (Logitech etc.) | ⚠️ #847 family: click&scroll/drag broken for buttons 4/5 on some Logitech devices; reopened as #1932 | ❌ same reports on GG (#1926 comments: 点按 works, drag/scroll variants don't) |
| Smooth scrolling | ✅ mostly; intermittent "scroll stops working" class bugs (Aug 2025 bug log in repo; #1915, #1922) | ❓ likely OK where capture works; needs verification |
| **Dock-swipe gestures** (Spaces & Mission Control, Move between Spaces, Desktop & Launchpad) via click-drag/click-scroll | n/a (worked until 26.x) | ❌ broken in ALL releases; ✅ **fixed on master** (`f92d2d53a`, 2026-06-21) but unreleased; fix has known issue: transitions sometimes get stuck |

## The Golden Gate dock-swipe breakage (primary blocker)

**Symptom:** Any mapping that triggers Mission Control / Spaces switching / Desktop & Launchpad does nothing on macOS 27. Plain clicks still work.

**Root cause:** macOS 27 changed how synthesized Dock-swipe events are validated. MMF posts CGEvents to simulate trackpad swipes; under GG the Dock ignores them unless the events carry attached **IOHIDEvent** payloads (the kernel-level event representation).

**Fix on master (unreleased):**
- `f92d2d53a` reworks `Helper/Core/Touch/TouchSimulator.m` (`postDockSwipeEventWithDelta:`) to attach IOHIDEvents to the posted CGEvents, bridged via `Shared/IOKit/CGEventHIDEventBridge.h`.
- `Tests/FixDockSwipes.m` is the standalone reproduction/validation harness Noah used.
- Known remaining problems, quoted from the commit message:
  1. *"Dock swipe transitions sometimes get stuck and you can't unstick it with the same dock-swipe – this is pretty bad! … doesn't happen with a Trackpad."*
  2. Untested whether the legacy double/triple end-event workaround helps or harms on 27.
  3. Translation hint `scroll-effect.4-pinch.hint` confuses up/down under natural scrolling.

**Independent evidence the approach is right:** 8 community PRs implement variations of the same IOHIDEvent-attach strategy (#1895, #1912, #1916, #1918, #1924, #1936, #1950 + #1938 which adds DPI-button detection). One shipped standalone companion app exists too (`timmyagentic/mac-mouse-fix-macos-27-fix`) — useful as a comparison implementation, not something we need.

## Other Golden Gate / Tahoe issues to chase

| Issue | Class | Notes |
|---|---|---|
| #1926 (+ #1919, #1967) | **Helper crash at startup** | SIGSEGV in `SLEventTapEnable → CFMachPortGetContext → __CFCheckCFInfoPACSignature` (SkyLight/CoreFoundation). Reported from build 24310 (pre-June master?) on 27.0 beta. Must reproduce on current master; may already be fixed or may be the "not working" reports. PAC-signature check suggests stale MachPort context handling — our top crash candidate. |
| #1915, #1923, #1922 | Scroll dead / app crash on **26.5.x** | Matches the in-repo "Bug Log [Aug 2025] - Scroll Stopped Working" (SkyLight SLEventPost weirdness, `IOServiceOpen failed: e00002e2`). Suspected macOS-side bug + possible deadlock; needs repro harness. |
| #1932 / #847 | Logitech buttons 4/5 click-and-scroll/drag | Long-standing device-specific capture problem; several PRs attempt fixes (#1928, #1856, #1710 HID++ support). |
| #1961 | Click+Drag Spaces on GG beta | Same root cause as dock-swipe blocker; should be resolved by master's fix — verify. |

## Things that will need attention for a fork release

1. **Code signing**: can't sign with Noah's identity. Options: ad-hoc signing (local use), or user's own Apple ID cert. Sparkle EdDSA signatures on appcasts are separate from Developer ID; for personal builds disable Sparkle auto-update pointing at upstream feed to avoid update loops/corruption.
2. **Bundle IDs collide** with the official app (`com.nuebling.mac-mouse-fix*`). Since this machine never had MMF installed, first install is clean; later side-by-side with the official app will conflict over Accessibility/login-item records — decide policy (keep same bundle id = in-place replacement of official app vs. renamed fork ids).
3. **License activation** is per-machine server check — user has a paid license; verify it activates on a locally-built copy (it should; license checks live in `Shared/License`).
4. Deployment target now 12.0 — acceptable (Monterey+). The `Tests` target requires the macOS 27 SDK (deployment target 27.0).
