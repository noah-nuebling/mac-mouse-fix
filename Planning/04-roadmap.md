# 04 — Roadmap

Date: 2026-08-22 · Owner: matteoveglia (with ox-alpha)

Goal: **a personally-built, working Mac Mouse Fix on macOS Golden Gate (27.0 public beta), tracking upstream, with fixes layered on top** — and ideally give fixes back upstream.

## Phase 0 — Environment setup (blocker for everything)

- [x] Install Xcode → **Xcode 27.0 beta (27A5237l)** at `/Applications/Xcode-beta.app`; use `DEVELOPER_DIR=` (no sudo available for xcode-select)
- [x] `git submodule update --init --recursive`
- [x] Build works: `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild -project "Mouse Fix.xcodeproj" -scheme App -configuration Debug -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO` → **BUILD SUCCEEDED** on macOS 27.0 SDK
- [x] Signing decision for now: fully unsigned local builds (keychain-access-groups entitlement blocks ad-hoc; revisit with a free Apple ID Personal Team cert if needed)
- [x] Sparkle neutralized for debug: `defaults write com.nuebling.mac-mouse-fix SUEnableAutomaticChecks -bool false` (app checks upstream feed on every start otherwise)

Exit criteria: `xcodebuild build` succeeds for App + Helper on this machine.

## Phase 1 — Baseline: does master already work on Golden Gate?

Status [2026-08-22]: Debug build (3.1.0 Beta 1, 24830 + June GG fixes) launched from DerivedData; main app running, no crashes; Helper pending Accessibility grant.
NOTE: unsigned builds → Accessibility grant likely resets after every rebuild.

- [ ] Build Release, install locally (clean machine — no prior MMF)
- [ ] Grant Accessibility; verify Helper stays alive at login (watch for #1926 crash signature in Console)
- [ ] Feature checklist on 26A5416b:
  - [ ] Button capture: every button reports (use Buttons tab "capture" UI)
  - [ ] Click actions (middle-click etc.)
  - [ ] Smart zoom, click-and-scroll
  - [ ] **Click-and-drag → Spaces & Mission Control / Move between Spaces / Desktop & Launchpad** ← the master fix
  - [ ] Smooth scrolling incl. momentum, horizontal scroll
  - [ ] Pointer speed / acceleration
  - [ ] License activation with paid key
- [ ] Record results in a test matrix file (`Planning/test-matrix.md`) — becomes our regression baseline

Exit criteria: honest matrix of what works on GG with current master.

## Phase 2 — Fix what's still broken on GG

Priority order:
1. **Stuck dock-swipe transitions** (known residual bug of master's fix). Approach: study `Tests/FixDockSwipes.m` + `TouchSimulator.m`; cross-check community PRs (#1936 claims rebound fix; compare event payloads/flags each PR attaches). Repro harness exists (Tests target).
2. **Helper startup crash** (#1926, `SLEventTapEnable → CFMachPortGetContext` PAC SIGSEGV): reproduce; inspect event-tap re-enable path (`GlobalEventTapThread.m`, enable/disable flows). If reproducible on master → root-cause; PAC check implies passing a stale/freed MachPort context.
3. **"Not working at all" on GG beta** (#1967/#1909): triage into either crash #2 or Accessibility/TCC behavior change; document workarounds.
4. Side-button click-and-drag/scroll on Logitech (#1932/#847): investigate capture path; evaluate pulling HID++ groundwork later.

Exit criteria: user's daily-driver features all work on their machine.

## Phase 3 — Hardening & hygiene for a sustainable fork

- [ ] Add GitHub Actions **build CI** (macOS runner, `xcodebuild` both targets, treat warnings policy) — none exists upstream
- [ ] Decide fork release policy: versioning scheme, DMG packaging (cf. PR #1814), own Sparkle appcast or updates-off
- [ ] Track upstream: periodic `git fetch upstream`; rebase-only policy on `master`; keep patches as small reviewable commits
- [ ] Upstream contribution: open polite PR(s) for whatever we fix that's generic (stuck-transition improvement, crash fix) — repo is dormant but not dead; issues get community comments daily

## Phase 4 — Opportunistic backlog (after compat)

See doc 03 buckets: per-app config (#1865), Logitech HID++ (#1710 family), gaming-mode toggle (#1859), scroll-direction splits (#1803), translation merges (#1836).

## Watch items

- GG beta cadence: public betas weekly-ish; final expected ~Sept–Oct 2026. Re-run Phase 1 matrix on each major beta bump.
- If Noah resumes activity, re-evaluate fork vs upstream strategy before duplicating work.

## Immediate next actions (this week)

1. Install Xcode → unblock everything else
2. Init submodules, first successful build
3. Run Phase 1 checklist on this Mac
4. Then start Phase 2 item 1 (stuck transitions) with the Tests harness
