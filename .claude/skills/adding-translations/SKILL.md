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
3. Claude does one of two things:
   1. If missing any info to ensure great translation quality – e.g. ANY of the "dependee strings" not yet translated.
      -> Claude **stops immediately** and asks for input. This is an error on the human's part. (The strings should be translated in dependency order with all the necessary context to ensure really good quality.)
   2. If Claude feels he has the necessary context to provide very good translations that satisfy all the constraints and are consistent within the project, then Claude proceeds to step 4. 
4. Claude spawns a subagent (Opus) and provides ALL the necessary context that it needs to write great translations.
   - Claude should not micromanage the agent, it should let it make its own decisions about the translations. That is except for existing translations discovered in the project. Those may be communicated to the subagent for consistency.
   -> This is important because Claude's mind will be preoccupied with lots of details from the thorough research he did. The subagent will better be able to see the big picture and make an good intuitive choices.
   - Claude should NOT research Apple's glossary, yet. The subagent has Apple's terminology in its training data and will be able to make better intuitive decisions by just understanding how and where the strings are used.
   - Claude will instruct the subagent to write its translations using the `./run mfstrings edit` tool. It will let it know about the `./run mfstrings inspect` tool, too, in case it wants to look anything up. But Claude will also tell the subagent that it has already explored the codebase and included any relevant constraints and context it could find. The goal is that the subagent can just focus on translating, without having to do research, but still CAN do research, if necessary. 
5. After the subagent is done, Claude will review and analyze the subagent's work. If necessary Claude will consult Apple's glossary (See below). Claude will report any constraints that aren't well satisfied, inconsistencies with established terminology in the glossary, inconsistencies with already-translated parts of the project, and any other things that Claude thinks could be improved.

## The mfstrings tool

Use `./run mfstrings` to inspect and edit .xcstrings localization files.

### Common commands

```bash
# List all source files (fileid + full path)
./run mfstrings list-files

# List all columns (includes locales)
./run mfstrings list-cols

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

After the subagent is done, Claude will review its work. 
If established terms from inside macOS are used, Claude may consult Apple's glossary:

Here are two example paths for Apple's glossary files:

~/Documents/Glossaries_For_Claude/macOS_10.15.2/German/
~/Documents/Glossaries_For_Claude/macOS_10.15.2/Simplified_Chinese/

(Note that we're translating for macOS 26, but 10.15.2 is the latest glossary version available. It may be out of date.)

Claude can search through the glossary files using ripgrep. For example:
```bash
rg -i -A 1 '\Whold\W'
```

(-A lets you see the translation which typically appears on the next line)
(`\W` is useful when searching for 'hold' so you don't get overwhelmed with matches for unrelated words like 'placeholder')

---

(This is the end of the skill.md file)