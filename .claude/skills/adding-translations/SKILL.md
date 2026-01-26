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
   1. If missing any info to ensure great translation quality – e.g. ANY of the "dependee strings" not yet translated.
      -> Claude **stops immediately** and asks for input. This is an error on the human's part. (The strings should be translated in dependency order with all the necessary context to ensure really good quality.)
   2. If Claude feels he has the necessary context to provide very good translations that satisfy all the constraints and are consistent within the project, then Claude proceeds to step 5. 
5. Claude writes translations for all the strings. 
   -> This is so Claude really internalizes the constraints. It will also be used later, for reviewing the subagents' work.
6. Claude writes a `./TRANSLATION_CONTEXT.md` file that provides a subagent with ALL the necessary information to write great translations for any language. 
   - **Letting the subagent think for itself:** Claude does not micromanage the subagent. It just provides the subagent with the necessary context for making its own good decisions about the translations – just without having to do detailed research.
      - Reason 1: This is important because Claude's mind will be preoccupied with lots of details after doing thorough research. The subagent with its fresh context will be better able to see the big picture and make good intuitive choices.
      - Reason 2: If the subagent DOES come up with the right strings, we can be reasonably confident that it can also come up with good strings for OTHER languages. This is helpful for validating the approach and than scaling it to many languages (The human speaks German so that is the easiest to validate)
   - **mfstrings tool:** Claude will instruct the subagent to write its translations using the `./run mfstrings edit` tool. It will let it know about the `./run mfstrings inspect` tool, too, in case it wants to look anything up. The goal is that the subagent can just focus on translating, without having to do research, but still CAN do research, if necessary. The subagent should be instructed NOT to invoke the adding-translations skill.
   - **Terminology:** Claude should tell the subagent that we're translating for a macOS app, and that Apple's terminology in System Settings and elsewhere should be matched. But the subagent should do this from memory, without accessing the internet. Later there will be a review pass that checks consistency with Apple's glossary. 
7. Then Claude spawns a subagent (Must be Opus, not Sonnet or Haiku) and gives it two pieces of information and nothing else: 1. A link to ./`TRANSLATION_GUIDE.md` 2. The target language it should translate into.
8. After the subagent is done, Claude will review and analyze its work. If necessary. Claude will report any constraints that aren't well satisfied, inconsistencies with established terminology in the glossary, inconsistencies with already-translated parts of the project, and any other things that Claude thinks could be improved. Claude will be very critical, and will not try to justify or rationalize questionable decisions or unfulfilled constraints. Unfulfilled constraints or mistakes in the first pass are normal. Pointing them out is a very helpful thing. Claude will report his findings and ask for input before making proceeding.
9.  After this, the user may request to spawn more subagents that translate into even more languages using the `./TRANSLATION_CONTEXT.md`.
   -> This way, translations into all sorts of languages can be written efficiently while leveraging Claude's existingcontext-research work.

## The mfstrings tool

Use `./run mfstrings` to inspect and edit .xcstrings localization files.

### Common commands

```bash
# List all source files (fileid + full path)
./run mfstrings list-files

# List all columns (includes locales)
./run mfstrings list-cols

# View translations for a locale across all files
./run mfstrings inspect --cols fileid,key,comment,en,LOCALE,state:LOCALE --sortcol key

# View translations for a specific file
./run mfstrings inspect --cols        key,comment,en,LOCALE,state:LOCALE --sortcol key --filter fileid=Localizable

# Find a string with context (use grep -C to see surrounding related strings)
#  (Tip: Use --sortcol comment for the 'Main' file, since it has non-sorting-friendly interface builder keys.)
./run mfstrings inspect --cols fileid,key,comment,en,LOCALE,state:LOCALE --sortcol key | grep -C 5 "effect.click"

# Edit a translation value and mark as translated
#  (Tip: Use single quotes for `--value 'newValue'`. Double quotes can corrupt format specifiers (bash expands $@ to nothing))
./run mfstrings edit --path 'fileid/key/LOCALE' --state 'translated' --value 'new text'
```

## Referencing Apple's official terminology

After the subagent is done, Claude will review its work. 
If established terms from inside macOS are used, Claude may consult Apple's glossary by spawning a glossary-research subagent.

## Additional constraints

- **Strongly prefer simplicity:** When multiple valid patterns exist in Apple's glossary, the shorter, simpler one MUST be used unless there is a strong reason against this. There shouldn't be any extra words (like "gedrückt" in "gedrückt halten" vs just "halten") unless they add clarity. Shorter strings are easier to read and work better for UI.

---

(This is the end of the skill.md file)