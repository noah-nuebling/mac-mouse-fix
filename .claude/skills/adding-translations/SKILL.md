---
name: adding-translations
description: Add new translations for a locale. Use when translating new strings or filling in missing translations.
---

# Adding Translations Workflow

## Overview

This skill is for adding new translations to a locale. The workflow emphasizes thorough context gathering before translating, and handling string dependencies correctly.

## Core Workflow

1. **User provides**: A locale (e.g., `de`, `pt-BR`) and a list of string keys to translate
2. **Agent researches context** for each string thoroughly
3. **Agent identifies dependencies** between strings (shared terminology, related strings)
4. **Agent either**:
   - Reports a context gap and stops immediately (if missing critical info)
   - Translates strings in dependency order (independent strings first)

## The mfstrings tool

Use `./run mfstrings` to inspect and edit .xcstrings localization files.

### Common commands

# List all source files (fileid + full path)
./run mfstrings list-files

# View translations for a locale across all files
./run mfstrings inspect --fileid all --cols fileid,key,comment,en,LOCALE,state:LOCALE --sortcol key

# View translations for a specific file
./run mfstrings inspect --fileid Localizable --cols key,comment,en,LOCALE,state:LOCALE --sortcol key

# Find a string with context (use grep -C to see surrounding related strings)
./run mfstrings inspect --fileid all --cols fileid,key,comment,en,LOCALE,state:LOCALE --sortcol key | grep -C 5 "effect.click"

# Edit a translation value and mark as translated
./run mfstrings edit --path "fileid/key/LOCALE" --state "translated" --value "new text"
```

## Resolving Dependencies (Critical Step)

**Before translating any string, resolve ALL its dependencies:**

### 1. Comment references
When a comment says "See X" or mentions another string key, look up that string's comment first.

**Example**: `capture-toast.button-name.numbered` says "See trigger.substring.button-modifier.2". That comment contains capitalization rules. Missing this → incorrect translations.

```bash
# Look up a referenced string:
./run mfstrings inspect --fileid all --cols key,comment --sortcol key | grep -C 10 "trigger.substring.button-modifier.2"
```

### 2. Shared terminology
If your string uses a term that might appear elsewhere, check how it's already translated:

```bash
./run mfstrings inspect --fileid all --cols key,en,LOCALE --sortcol key | grep -i "scroll"
```

### 3. Related strings (same key prefix)
Strings like `effect.click.*` share context. 
Phrasing and terminology needs to be consistent within the group. 
Earlier strings in a group may have comments that apply to later ones.

**Tip**: Sort by `key` so strings with the same prefix appear together, then use `grep -C` to see them:

```bash
./run mfstrings inspect --fileid all --cols key,comment,en,LOCALE --sortcol key | grep -C 5 "effect.click"
```

If you notice that you can't see the beginning of the group, yet, grep again until you find it, and read the comments.
```bash
# Earliest string you saw was effect.click.secondary.hint, you suspect effect.click.primary appears earlier, so you grep again:
./run mfstrings inspect --fileid all --cols key,comment,en,LOCALE --sortcol key | grep -B 10 -A 5 "effect.click"
```

Exception: Sort the `Main` file by `comment` instead of `key` (it has Interface Builder keys like `4gx-d0-WNb.title`).

### 4. Apple/macOS terminology
If a comment references Apple terminology (e.g., "match the wording in System Settings"), you can't resolve this yourself. Stop and ask the user.

## Context Gaps - When to Stop

**Stop and ask the user** when you encounter:

- Unresolvable dependencies (like Apple terminology in #4 above)
- Ambiguous source strings where the meaning isn't clear
- Format specifiers like %@ where you don't understand exactly what they'll contain

When stopping, report which string(s) you're blocked on and what you need.

**Do not guess** at official terminology or make assumptions about ambiguous strings.

## Translation Guidelines

- **Keep it simple** - match the English unless your deviation is better. Example: "5+ botões" beats "5 ou mais botões"
- **Batch edits** in a single command block:

```bash
./run mfstrings edit --path "Localizable/scroll.smooth/de" --state "translated" --value "Flüssiges Scrollen"
./run mfstrings edit --path "Localizable/scroll.smooth.enabled/de" --state "translated" --value "Flüssiges Scrollen aktiviert"
```

## Expanding Scope

The goal is to translate the requested strings PLUS any strings they depend on. If you discover that translating `feature.enabled` requires first establishing terminology from `feature.name`, add `feature.name` to your translation list even if it wasn't originally requested.

Document any strings you added beyond the original request when reporting back to the user.
