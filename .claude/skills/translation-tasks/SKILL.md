---
name: translation-tasks
description: Review and edit translations in .xcstrings localization files. Use when working with translations, localization, reviewing strings for a locale (like pt-BR, de, fr), or using the mfstrings tool.
---

# Translation Review Workflow

## The mfstrings tool

Use `./run mfstrings` to inspect and edit .xcstrings localization files.

### Common commands

```bash
# List all available columns
./run mfstrings list-cols

# View translations for a locale (replace LOCALE with e.g., pt-BR, de, fr)
./run mfstrings inspect --pretty --cols LOCALE_state,fileid,key,en,LOCALE

# Find strings needing review
./run mfstrings inspect --pretty --cols LOCALE_state,fileid,key,en,LOCALE | grep "needs_review"

# Edit a translation value and mark as translated
./run mfstrings edit --path "fileid/key/LOCALE" --value "new text" --state "translated"

# Flag a string for review (without changing the value)
./run mfstrings edit --path "fileid/key/LOCALE" --state "needs_review"

# Check consistency of a term across all files
./run mfstrings inspect --cols en,LOCALE | grep "term"
```

### Sorting

- Default sorting is by the first column
- Use `--sortcol` to sort by a different column
- Some files (like 'Main') should be sorted by 'comment' - check the string comments for guidance

- When you sort by 'key' or 'comment', related strings will be grouped together naturally. When you then grep with context (` ... | grep -C ...`) you'll see important context, that you might miss otherwise.

## Review guidelines

### 1. Flag uncertainties about technical details
- If unsure about something technical (like CFBundleName behavior, whether .app filenames get localized, etc.), notify the user
- Ask if it should be documented in the localization context/comments
- Don't assume - document the uncertainty

### 2. Use grep/search to verify consistency
- When reviewing a term, grep for ALL occurrences across the project
- Check both the term being translated AND related terms
- Example: Searching "Mac Mouse Fix Helper" should show consistent translation everywhere

### 3. Check comments for critical context
Comments often contain important notes about:
- Technical limitations (CFBundleName, format specifiers, etc.)
- Related strings to check for consistency
- Layout constraints
- Where to find official Apple translations
- A lot of these comments are written with human translators in mind.
    - If there's a reference you'd like to follow but cannot easily do so 
    - (e.g. a string deep inside System Settings), mark the uncertainty
        with 'needs_review' and report back to the human later.

### 4. Strive for great translations, not just correct ones
- Don't *just* aim for consistency with existing translations
- Ask: "Could this be simpler? Does it need to deviate from the English?"
- Bias towards: **Keep things simple** and **match the English version, unless your deviation makes things better**
- Example: "5 ou mais botões" is correct, but "5+ botões" is simpler and matches the English "5+ buttons" better

### 5. Autonomous work with uncertainty flagging
- Work through translations autonomously, making fixes where confident
- When uncertain: fix it if you can, but mark as `needs_review` (not `translated`)
- Keep a mental list of uncertainties as you work

### 6. IMPORTANT: Report uncertainties when done
Before finishing, report ALL flagged uncertainties to the user:

```
I fixed N strings. M remain flagged as `needs_review`:
- `fileid/key`: [reason for uncertainty]
- `fileid/key`: [reason for uncertainty]
```

Common uncertainties worth flagging:
- macOS terminology you couldn't verify (e.g., "Is 'Login Items' called 'Itens de Início' in pt-BR System Settings?")
- App names that may or may not be localized by macOS
- Layout/length concerns you can't visually verify

## Common issues to watch for

- Inconsistent translation of specific terms across strings
- Inconsistent phrasing in strings that show up close to each other in the UI