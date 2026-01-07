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

# Show translation progress (files × locales table)
./run mfstrings progress --files all --locales de,ko,tr

# View translations for a locale across all files
./run mfstrings inspect --fileid all --cols fileid,key,comment,en,LOCALE,state:LOCALE --sortcol key

# View translations for a specific file
./run mfstrings inspect --fileid Localizable --cols key,comment,en,LOCALE,state:LOCALE --sortcol key

# Find a string with context (use grep -C to see surrounding related strings)
./run mfstrings inspect --fileid all --cols fileid,key,comment,en,LOCALE,state:LOCALE --sortcol key | grep -C 5 "effect.click"

# Edit a translation value and mark as translated
./run mfstrings edit --path "fileid/key/LOCALE" --state "translated" --value "new text"
```

### Sorting to gather context

- Sorting by `key` groups related strings together (e.g., `effect.click.primary`, `effect.click.secondary`)
- When grepping, use `grep -C <lines_of_context>` to see surrounding strings
- Treat key-sorting as the default mode when exploring

- Sort the `Main` file by `comment` instead (it has non-sorting-friendly Interface Builder keys like `4gx-d0-WNb.title`)

- Look for earlier comments that apply to later strings in a group (e.g., `effect.click.primary` might have a comment that applies to `effect.click.secondary`)

## Context Gathering (Critical Step)

Before translating any string, thoroughly research its context:

### 1. Inspect the string with surrounding context

```bash
# See the string and related strings (sorted by key)
./run mfstrings inspect --fileid all --cols fileid,key,comment,en,LOCALE,state:LOCALE --sortcol key | grep -C 10 "your.string.key"
```

### 2. Read comments carefully

Comments often contain:
- Technical limitations (format specifiers, character limits)
- Related strings to check for consistency
- Where to find official Apple/macOS translations
- Layout constraints

### 3. Check existing translations of related terms

If the string uses terminology that appears elsewhere, check how it's already translated:

```bash
# See how a term is translated across all strings
./run mfstrings inspect --fileid all --cols key,en,LOCALE --sortcol key | grep -i "scroll"
```

### 4. Follow references in comments

If a comment says "effect.click.primary appears right above in the UI" follow that reference before translating.

## Handling Dependencies

Strings often depend on each other through shared terminology. Before translating:

1. **Identify the logical group** - strings with similar key prefixes or shared terms
2. **Find the "root" terms** - base terminology that other strings build on
3. **Translate in order** - root/independent terms first, dependent strings after

Example dependency chain:
- `scroll.smooth` ("Smooth scrolling") - root term, translate first
- `scroll.smooth.enabled` ("Smooth scrolling enabled") - depends on translation of "Smooth scrolling"
- `scroll.smooth.hint` ("Enable smooth scrolling for...") - depends on same term

## Context Gaps - When to Stop

**Stop immediately and ask the user** when you encounter:

- macOS/Apple terminology you can't verify (e.g., "What is 'Login Items' called in German System Settings?")
- Comments that require checking something external (e.g., "Match the wording in System Settings > Privacy")
- Technical terms or app names where localization status is unclear
- Ambiguous source strings where the meaning isn't clear from context
- Strings with format specifiers like %@ where you don't understand exactly what those format specifiers will be replaced with.

When stopping, report:
1. Which string(s) you're blocked on
2. What specific information you need
3. Why you couldn't find it yourself

**Do not guess** at official Apple terminology or make assumptions about ambiguous strings.

## Translation Guidelines

### Strive for great translations, not just correct ones
- Ask: "Could this be simpler? Does it need to deviate from the English?"
- Bias towards: **Keep things simple** and **match the English version, unless your deviation makes things better**
- Example: "5 ou mais botões" is correct, but "5+ botões" is simpler and matches English "5+ buttons"

### Consistency is critical
- When translating a term, grep for ALL occurrences across the project
- Check both the term being translated AND related terms
- Ensure consistent translation everywhere

### Batch edits

When making multiple edits, run them in a single command block:

```bash
./run mfstrings edit --path "Localizable/scroll.smooth/de" --state "translated" --value "Flüssiges Scrollen"
./run mfstrings edit --path "Localizable/scroll.smooth.enabled/de" --state "translated" --value "Flüssiges Scrollen aktiviert"
./run mfstrings edit --path "Localizable/scroll.smooth.hint/de" --state "translated"  --value "Flüssiges Scrollen aktivieren für..."
```

## Expanding Scope

The goal is to translate the requested strings PLUS any strings they depend on. If you discover that translating `feature.enabled` requires first establishing terminology from `feature.name`, add `feature.name` to your translation list even if it wasn't originally requested.

Document any strings you added beyond the original request when reporting back to the user.
