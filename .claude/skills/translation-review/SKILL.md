---
name: translation-review
description: Review and edit existing translations. Use when reviewing, fixing, or updating translations for an existing locale (like pt-BR, de, fr), or when discussing mfstrings.py.
---

# Translation Review Workflow

## The mfstrings tool

Use `./run mfstrings` to inspect and edit .xcstrings localization files.

### Common commands

```bash

# List all available columns (Also lists locales)
./run mfstrings list-cols

# See the number of translated/untranslated strings per file and locale in a TSV (rows: fileids, cols: locales) 
./run mfstrings progress --files all --locales all

# List all source files (fileid + full path)
./run mfstrings list-files

# Show translation progress (files × locales table)
./run mfstrings progress --files all --locales de,ko,tr

# View translations for a locale across all files (replace LOCALE with e.g., pt-BR, de, fr)
./run mfstrings inspect --cols fileid,key,comment,en,LOCALE,state:LOCALE --sortcol key

# View translations for a specific file
./run mfstrings inspect --cols key,comment,en,LOCALE,state:LOCALE --sortcol key --filter fileid=Localizable

# Find strings needing review (state is binary: 'translated' or 'needs_review')
./run mfstrings inspect --cols fileid,key,comment,en,LOCALE,state:LOCALE --sortcol key | grep "needs_review"

# Find a string with context
./run mfstrings inspect --cols fileid,key,comment,en,LOCALE,state:LOCALE --sortcol key | grep -C 3 "effect.click.primary"

# Edit a translation value and mark as translated
./run mfstrings edit --path 'fileid/key/LOCALE' --value 'new text' --state 'translated'

# Flag a string for review (without changing the value)
./run mfstrings edit --path 'fileid/key/LOCALE' --state 'needs_review'

# ⚠️ Use single quotes for --value! Double quotes corrupt format specifiers:
#    "%2$@" becomes "%2" (bash expands $@ to nothing)
```

### Sorting to gather context

- Sorting by `key` groups related strings together (e.g., `effect.click.primary`, `effect.click.secondary`)
    - When grepping, use `grep -C <lines_of_context>` to see surrounding context
    - Treat this as the default mode when exploring.

- Sort the `Main` file by `comment` instead. (It's an Interface Builder file that has non-sorting-friendly keys like `4gx-d0-WNb.title`)

- You may want to look for earlier comments that apply to similar later strings. (e.g., `effect.click.primary` might have a comment that applies to `effect.click.secondary`). Usually, the first string in a 'logical group' will have a comment that applies to the whole group.

### Batch edits

When making multiple edits, consider running them in a single command (separated by newlines) to speed things up:

```bash
./run mfstrings edit --path 'Localizable/trigger.substring.click.2/pt-BR' --value 'duplo clique %@' --state 'translated'
./run mfstrings edit --path 'Localizable/trigger.substring.click.3/pt-BR' --value 'triplo clique %@' --state 'translated'
./run mfstrings edit --path 'Localizable/trigger.substring.drag.2/pt-BR' --value 'clique duas vezes e *arraste* %@' --state 'translated'
```

## Review guidelines

### 0. Follow Apple's style
This is a macOS app. Follow Apple's terminology and style guides where possible. Use the same terms that appear in System Settings, Finder, and other Apple apps for your locale.

### 1. Use grep/search to verify consistency
- When reviewing a term, grep for ALL occurrences across the project
- Check both the term being translated AND related terms
- Example: Searching "Mac Mouse Fix Helper" should show consistent translation everywhere

### 2. Check comments for critical context
Comments often contain important notes about:
- Technical limitations (format specifiers, etc.)
- Related strings to check for consistency
- Layout constraints
- Where to find official Apple translations

### 3. Strive for great translations, not just correct ones
- Don't *just* aim for consistency with existing translations
- Ask: "Could this be simpler? Does it need to deviate from the English?"
- Bias towards: **Keep things simple** and **match the English version, unless your deviation makes things better**
- Example: "5 ou mais botões" is correct, but "5+ botões" is simpler and matches the English "5+ buttons" better

### 4. Jot down uncertainties as you go

Translation involves lots of small judgment calls. As you work through strings, jot down anything you're not 100% sure about in a scratch file:

```bash
# Start of your session
echo "# Uncertainties" > /tmp/uncertainties.md

# As you encounter things you're unsure about
echo "- Localizable/some-key: Used 'arrastar' but maybe 'arraste' is more natural?" >> /tmp/uncertainties.md
```

Things worth jotting down:
- macOS terminology you couldn't verify ("Is 'Login Items' called 'Itens de Início' in pt-BR System Settings?")
- Comments written for human translators that you can't fully follow (e.g., "Check System Settings > Privacy for exact wording")
- Layout/length concerns ("This is much longer than the English")
- Choices between equally valid options ("Kept original translator's 'arraste' vs my instinct for 'arrastar'")
- App names or technical terms that may or may not be localized

When uncertain about a string, you can still fix it - just mark it `needs_review` instead of `translated`.

When you're done, read back your notes (`cat /tmp/uncertainties.md`) and share them with the user. This helps them know what to double-check.

## Important issues to watch for

- Inconsistent translation of specific terms across strings
- Inconsistent phrasing in strings that show up close to each other in the UI