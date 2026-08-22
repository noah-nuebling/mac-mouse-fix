# Mac Mouse Fix Revival — Planning Documents

Working documents for reviving Mac Mouse Fix on macOS Tahoe (26) and Golden Gate (27),
maintained in `matteoveglia/mac-mouse-fix` (fork of `noah-nuebling/mac-mouse-fix`).

**Created:** 2026-08-22 · **Status:** Planning phase (no code changes yet)

## Documents

| Doc | Purpose |
|---|---|
| [01-situation-assessment.md](01-situation-assessment.md) | Where things stand: upstream state, releases, fork state, local environment |
| [02-macos-compat.md](02-macos-compat.md) | Tahoe/Golden Gate compatibility matrix — what's broken, what's fixed, where |
| [03-backlog-triage.md](03-backlog-triage.md) | Triage of the 1185 open issues and 27 open PRs |
| [04-roadmap.md](04-roadmap.md) | Phased execution plan + immediate next actions |

## TL;DR

1. **Upstream is not fully abandoned but stalled.** Last real commits: 2026-06-22. Last release: 3.1.0 Beta 1 (updated Jan 2026).
2. **Crucially, upstream master already contains an unreleased fix for the main Golden Gate bug** (dock-swipe gestures broken on macOS 27) — commit `f92d2d53a`, 2026-06-21. It has never been shipped in any release.
3. Therefore our fastest path to a working app on Golden Gate is: **build master locally, verify it, then fix what remains broken on top of it.**
4. Blocker #0 for everything: **Xcode is not installed on this machine.**
5. The issue tracker is noisy (1185 open issues) but the Golden Gate–critical subset is small and well understood (see doc 02).
