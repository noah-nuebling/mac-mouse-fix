---
name: adding-translations
description: Add new translations for a locale. Use when translating new strings or filling in missing translations.
---

# Adding Translations Workflow

## Overview

This skill is for adding new translations to a locale.

## Core Workflow

1. User provides a locale (e.g., `de`, `pt-BR`) and a list of string keys to translate.
2. Claude explores the project's translations using the `./run mfstrings` command and gathers context.
   -> The goal is for Claude to understand ALL the necessary information to make optimal decisions about the translations. What hints are provided in the comments? Which related strings are there? Etc.
3. Claude writes a thorough list of all the context (dependencies and other constraints) that it found, plus the constraints under `## Additional constraints` below.
4. Claude does one of two things:
   1. If missing any info to ensure great translation quality – e.g. ANY of the "dependee strings" not yet translated, or dependencies on Apple Terminology that Claude can't verify:
      -> Claude **stops immediately** and asks for input. This is an error on the human's part. (The strings should be translated in dependency order with all the necessary context to ensure really good quality.)
   2. If Claude feels he has the necessary context to provide very good translations that satisfy all the constraints and are consistent within the project as well as with the users environment (macOS, Apple support docs), then Claude proceeds to step 5. 
5. Claude translates the strings paying great attention that all the constraints he found are satisfied.

## The mfstrings tool

Use `./run mfstrings` to inspect and edit .xcstrings localization files.

### Common commands

```bash
# List all source files (fileid + full path)
./run mfstrings list-files

# View translations for a locale across all files
./run mfstrings inspect --fileid all --cols fileid,key,comment,en,LOCALE,state:LOCALE --sortcol key

# View translations for a specific file
./run mfstrings inspect --fileid Localizable --cols key,comment,en,LOCALE,state:LOCALE --sortcol key

# Find a string with context (use grep -C to see surrounding related strings)
#  (Tip: Use --sortcol comment for the 'Main' file, since it has non-sorting-friendly interface builder keys.)
./run mfstrings inspect --fileid all --cols fileid,key,comment,en,LOCALE,state:LOCALE --sortcol key | grep -C 5 "effect.click"

# Edit a translation value and mark as translated
#  (Tip: Use single quotes for `--value 'newValue'`. Double quotes can corrupt format specifiers (bash expands $@ to nothing))
./run mfstrings edit --path 'fileid/key/LOCALE' --state 'translated' --value 'new text'
```

## Referencing Apple's official terminology

When in doubt, Claude can view Apple's glossary files which are available locally. Here are two example paths:

~/Documents/Glossaries_For_Claude/macOS_10.15.2/German/
~/Documents/Glossaries_For_Claude/macOS_10.15.2/Simplified_Chinese/

Claude can search through the glossary files using ripgrep. For example:
```bash
rg -i -A 1 '\Whold\W'
```

(-A lets you see the translation which typically appears on the next line)
(`\W` is useful when searching for 'hold' so you don't get overwhelmed with matches for unrelated words like 'placeholder')

## Additional constraints

- **Prefer simplicity:** When multiple valid patterns exist in Apple's glossary, prefer the shorter, simpler one. Don't add extra words (like "gedrückt" in "gedrückt halten" vs just "halten") unless they add clarity. Shorter strings are easier to read, fit better in UI, and are less likely to contain errors.

---

(This is the end of the skill.md file)