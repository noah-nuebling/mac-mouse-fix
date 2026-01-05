---
name: file-editing
description: Conventions for editing files in this project. Use when writing or modifying code, documentation, or notes - NOT relevant for editing translations.
---

# File Editing Conventions

## Code Comments and Attribution

**Date tags** (`[Jan 2026]`): Use for comments that make time-sensitive assumptions or observations that may become outdated:
- Current state of the codebase/architecture (e.g., "18k+ files in website repo")
- Performance characteristics that depend on current implementation
- Workarounds for current limitations
- References to current versions/behaviors

**Attribution tags** (`(By Claude)`): Mark Claude-written code to distinguish it from human-written code:
- **File-level**: If a file has `(By Claude)` at the very top, the majority of the file is Claude-written. Individual functions/changes within that file don't need individual `(By Claude)` tags.
- **Change-level**: When making changes to human-written files (files without a top-level `(By Claude)` tag), mark your changes with `(By Claude)`.

**Example:**
```python
# Use git ls-files instead of glob.glob() as a performance optimization to speed up `./run mfstrings inspect` (18k+ files in website repo) [Jan 2026] (By Claude)
```
