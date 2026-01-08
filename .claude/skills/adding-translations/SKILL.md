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
3. **Agent identifies dependencies** and adds them to the translation list (even if not requested)
4. **Agent either**:
   - Reports a context gap and stops immediately (if missing critical info)
   - Translates strings in dependency order (dependencies first, then requested strings)

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
When a comment says "See X" or mentions another string key, look up that string's comment. Comments may:
- Contain rules to follow (e.g., capitalization guidelines)
- Reference other strings that yours must be consistent with (these are translation dependencies)

**Example**: `capture-toast.button-name.numbered` says "capitalization should follow `trigger.substring.button-name.[...]` strings. See trigger.substring.button-modifier.2".
- `trigger.substring.button-modifier.2` contains the capitalization *rules*
- `trigger.substring.button-name.*` are the strings to *match* - if untranslated, add them to your list

```bash
# Look up a referenced string:
./run mfstrings inspect --fileid all --cols key,comment --sortcol key | grep -C 10 "trigger.substring.button-modifier.2"
```

### 2. Shared terminology
If your string uses a term that might appear elsewhere, check how it's already translated. If the term isn't translated yet, the strings that establish that terminology are dependencies - add them to your list.

```bash
./run mfstrings inspect --fileid all --cols key,en,LOCALE --sortcol key | grep -i "scroll"
```

### 3. Related strings (same key prefix)
Strings like `effect.click.*` share context - phrasing and terminology must be consistent within the group. Earlier strings may have comments that apply to later ones. If earlier strings in the group aren't translated, add them to your list.


**Tip**: Sort by `key` so strings with the same prefix appear together, then use `grep -C` to see them:

```bash
./run mfstrings inspect --fileid all --cols key,comment,en,LOCALE --sortcol key | grep -C 5 "effect.click"
```

If you can't see the beginning of the group, widen your search:
```bash
# If the earliest visible string was effect.click.secondary.hint, grep with more context:
./run mfstrings inspect --fileid all --cols key,comment,en,LOCALE --sortcol key | grep -B 10 -A 5 "effect.click"

Important Exception: Sort the `Main` file by `comment` instead of `key` (it has Interface Builder keys like `4gx-d0-WNb.title`).

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

### Translate in dependency order

When you find dependencies during analysis, you MUST add them to your translation list - even if not originally requested. Dependencies include:

1. **Strings referenced in comments** - If string A's comment says "See string B", look up string B
2. **Strings that must be consistent** - If a comment says "should match the style of X strings", those X strings are dependencies
3. **Shared terminology** - If multiple string groups use the same terms, establish the terminology first

**Always translate dependencies before the strings that depend on them.**

**Example**: `capture-toast.button-name.numbered` says "capitalization should follow the `trigger.substring.button-name.[...]` strings":
1. The `trigger.substring.button-name.*` strings are dependencies (they establish the style to follow)
2. Check if `trigger.substring.button-name.*` are translated for your locale
3. If not translated: add them to your list and translate them FIRST
4. Then translate `capture-toast.button-name.numbered` matching their style

**Key insight**: Dependencies aren't just for understanding rules - they're strings that must be translated first to establish consistent terminology and style. If string A says "match the style of string B", you cannot translate A correctly until B exists.

### Translation process

After analyzing context and resolving dependencies:

**Step 1: Write a Constraints Checklist**

Before translating anything, write out an explicit checklist of all constraints you discovered. Extract specific, actionable rules from comments. Example:

```
Constraints for this batch:
- [ ] Capitalization: adjectives lowercase, only nouns capitalized (from trigger.substring.button-modifier.2)
- [ ] Use "abfangen" for "capture" (established in earlier translation)
- [ ] Button names must match trigger.substring.button-name.* style
```

**Step 2: Make an ordered translation list**

List all strings to translate in dependency order (dependencies first, then requested strings).

(The goal is to translate the requested strings PLUS any strings they depend on. If you discover that translating `feature.enabled` requires first establishing terminology from `feature.name`, add `feature.name` to your translation list even if it wasn't originally requested.)

**Step 3: Translate in batches of 5 or fewer**

After each batch, STOP and verify against your checklist:

1. Re-read each constraint from your checklist
2. For each constraint, check every translation you just made
3. If any translation violates a constraint, fix it before continuing

This verification must be explicit - actually write out "Checking constraint X against translations Y, Z..."
