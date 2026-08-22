# 01 — Situation Assessment

Date: 2026-08-22

## Upstream project state (`noah-nuebling/mac-mouse-fix`)

### Releases

| Release | Date | Notes |
|---|---|---|
| **3.0.8** (latest stable) | 2025-09-12 | Shipped ~1 week before macOS 26 Tahoe GA. No Tahoe/GG fixes guaranteed. |
| **3.0.7** | 2025-08-25 | |
| **3.1.0 Beta 1** (latest pre-release) | 2025-11-29 | Localization overhaul (xcloc system). Asset updated through 2026-01-01 (build 24830). **Does not contain the June 2026 macOS 27 fixes.** |

### Commit activity

- HEAD of `master` = `98fa6631e` (2026-08-22) — but that's a bot commit ("GitHub Actions Workflow automatically regenerated Acknowledgements.md", runs continuously).
- **Last real commits: 2026-06-21/22**, by Noah Nuebling:
  - `f92d2d53a` — **"Fix DockSwipes under macOS 27 (Beta 2)"** + new `Tests` target with `Tests/FixDockSwipes.m` (the fix works by attaching IOHIDEvents to posted CGEvents). Also raised deployment target 10.15 → 12.0.
  - `aefc3ce3a` — Removed CocoaLumberjack, replaced with os_log.
  - `b495ccbaa` — NULL checks in `postDockSwipeEventWithDelta:`.
  - `1f9518c0b` — note re: thread priority in `GlobalEventTapThread.m`.
- Interpretation: Noah did a focused burst of Golden Gate compatibility work in June 2026, then went quiet again (~2 months as of today).

### Tracker state

- **1185 open issues** (huge; mostly feature requests, duplicates, and non-English reports)
- **27 open PRs** — notably **~8 competing community PRs** all fixing the same macOS 27 dock-swipe bug independently (see doc 03)
- 37 open issues mentioning Tahoe; 13 mentioning "Golden Gate"; several macOS 27 crash reports

## Fork state (`matteoveglia/mac-mouse-fix`)

- `master` identical to upstream `master` @ `98fa6631e`. Clean tree.
- Remotes: `origin` = fork, `upstream` = noah-nuebling (added locally for tracking).
- Submodule `mac-mouse-fix-scripts` (used by the `./run` dev script) is **not initialized** yet.

## Local environment (this machine)

| Item | State |
|---|---|
| OS | **macOS 27.0 Golden Gate, build 26A5416b** (public beta track) |
| Xcode | **NOT INSTALLED** — only Command Line Tools. `xcodebuild` unusable. ← Blocker #0 |
| gh CLI | Authenticated as `matteoveglia`, repo scope ✓ |

Note: this machine has **never had MMF installed** — clean slate, no stale Accessibility/login-item state to untangle.

## Codebase orientation (what lives where)

```
App/          Main (UI) app — tabs, config UI, licensing UI
Helper/       Mac Mouse Fix Helper — the actual engine, runs as login item:
  Core/Buttons    button capture/remapping (event tap)
  Core/Scroll     smooth scrolling engine (virtual trackpad emulation)
  Core/Touch      TouchSimulator.m — dock-swipe/trackpad simulation (GG fix site)
  Core/Drag       click-and-drag
Shared/       code shared by both targets (Config, License, IOKit bridges, Sparkle glue)
Frameworks/   vendored deps incl. cmark-gfm (prebuilt static lib)
Tests/        NEW: scratch target from the June 2026 GG debugging (FixDockSwipes.m)
Markdown/     localized docs; Localization/ strings (new xcloc system in 3.1.0)
mac-mouse-fix-scripts/  python dev tooling behind ./run (submodule)
```

Build facts:

- Targets: `Mac Mouse Fix` (app), `Mac Mouse Fix Helper`, new `Tests` target (deployment target 27.0), `XCStringsDummyApp`, `Localization Screenshot Taker`.
- Deployment targets: App/Helper = 12.0 (raised from 10.15 in June 2026); Swift 5; ObjC-dominant codebase.
- CI (GitHub Actions) only regenerates Acknowledgements/localization state — **no build/test CI exists**.
- Signing: upstream signs with Noah's cert (`LM5Z78756B`). Local builds must use our own identity or ad-hoc; see `Various Notes/notes.md` warnings (do NOT touch his certificates).
- Licensing: server-activated paid license (user owns one). Sparkle is used for updates; fork builds must not fight with the official Sparkle feed/appcast or an officially installed copy.

## Key strategic conclusion

The single most important discovery: **the main Golden Gate breakage already has a fix sitting unreleased on master.** We do not need to reverse-engineer it from scratch — we need to build master, verify the fix on 26A5416b, and then close the remaining gaps (helper startup crash #1926, scroll regressions on 26.x, stuck dock-swipe transitions, Logitech side buttons). Community PRs provide alternative implementations to cross-check against.
