# 03 — Backlog Triage (issues & PRs)

Date: 2026-08-22 · Snapshot: 1185 open issues, 27 open PRs upstream

Strategy: don't drown in the tracker. The Golden Gate–critical set is small. Everything else is triaged into buckets so we can work through it opportunistically after the compat work.

## PRs — the interesting part

### A. macOS 27 dock-swipe fixes (8 competing, all against the same bug)

Upstream fixed this on master in June 2026 but never merged/released anything. The PRs are valuable as **alternative implementations** to compare when we attack the "stuck transitions" residual bug:

| PR | Author | Date | Angle |
|---|---|---|---|
| #1950 | tsonubin | 2026-07-27 | Spaces & Mission Control click-and-drag |
| #1938 | nikuscs | 2026-07-19 | + Lift DPI button detection & drag support |
| #1936 | timmyagentic | 2026-07-18 | "without release rebound" — claims to fix the stuck/rebound artifact |
| #1924 | zhaoqiman | 2026-07-14 | dock-swipe gestures |
| #1918 | SalmonC | 2026-07-09 | dock-swipe gestures |
| #1916 | thiagotfroes | 2026-07-08 | Spaces & Mission Control |
| #1912 | Nothing1024 | 2026-07-05 | Mission Control / Spaces / Show Desktop |
| #1895 | megyland | 2026-06-19 | earliest dock-swipe fix (predates Noah's!) |

**Action:** diff each against master's `postDockSwipeEventWithDelta:`; extract ideas for stuck-transition handling (especially #1936's rebound fix).

### B. Feature PRs worth keeping warm (post-compat)

| PR | What | Value |
|---|---|---|
| #1710, #1856, #1928 | Logitech HID++ support (hidapi / ReprogControlsV4 / M720) | Would properly fix the #847/#1932 side-button family; big effort |
| #1865 | App-specific configuration + UI-thread crash fixes | Top-voted feature class in issues (whitelist/per-app requests everywhere) |
| #1859 | 'Toggle Mac Mouse Fix' action (gaming mode) | Small, popular ask |
| #1779 | Universal Control fix | Verify still needed on GG |
| #1803 | Separate vertical/horizontal scroll direction controls | Common request |
| #1854–1862, #1904 | miguelAngelo1999 batch (momentum arrest, volume/brightness, rotate/zoom, move/resize window…) | Mixed bag; cherry-pick later |
| #1814 | GH Action building DMG from release assets | Useful for our fork releases |
| #1836 | zh-Hans translation fix | Trivial merge candidate |

## Issues — buckets

### Bucket 1: Golden Gate blockers (work now)
- Dock-swipe gestures dead → covered by master fix; verify + polish (#1919, #1931, #1935, #1954, #1961, #1967)
- Helper startup crash `SLEventTapEnable` (#1926) → reproduce, root-cause
- "Not working at all" reports on GG public beta (#1967, #1909) → likely = crash above or Accessibility TCC change; needs repro

### Bucket 2: Tahoe regressions (26.x)
- Scroll stops working / dead scroll (#1915, #1922, plus repo's internal Aug 2025 bug log)
- Startup crash on 26.5.2 (#1923)
→ Lower priority for us (user is on GG) but same code paths as Bucket 1; keep in scope.

### Bucket 3: Device-specific capture problems
- Logitech buttons 4/5 click-and-scroll/drag (#1932 → #847 family), DPI-button mice (#1938), wireless interference glitches (#1925)

### Bucket 4: Feature requests (the long tail — ~90% of tracker)
Recurring themes worth noting for later: per-app config/whitelist (#1921, #1908, #1953, #1966, #1971), more button actions (volume #1914, keypress toggle #1929, hold-and-drag #1911, quick-tap shortcuts #1907), Link-to-Mac/iPad (#1934), zoom speed separate from scroll (#1956), dark menu-bar icon (#1958).

### Bucket 5: Non-issues
Trial/licensing questions (#1957, #1959), translation nits (#1973, #1963), empty/vague reports (#1976, #1968…). Skip.

## Hygiene observations

- No labels seem consistently applied upstream; triage by search only.
- Many duplicates of the dock-swipe bug in Chinese/Russian — consolidate when answering.
- Upstream CI doesn't build/test anything → first fork-side improvement is a build workflow (see roadmap Phase 4).
