
# Translation Workflow for New Locales

Notes from translating Mac Mouse Fix into a new `_de` locale (blind translation, independent from existing `de`). [Jan 2026] (By Claude)

## Summary

- **504 strings** translated across **23 source files**
- The `mfstrings` tool automatically creates new locales when you edit a path that doesn't exist yet

## Workflow

### 1. Understand the scope

```bash
# List all source files
./run mfstrings list-files

# Count strings per file
./run mfstrings inspect --fileid all --cols fileid --sortcol fileid 2>/dev/null | cut -f1 | sort | uniq -c | sort -rn
```

Output shows file distribution:
```
158 Localizable
 80 Main
 70 index
 64 Readme
 50 Quotes
 22 CapturedButtonsMMF3
 11 Shared
  9 AuthorizeAccessibilityView
  9 Acknowledgements
  5 Support
  ... (smaller files)
```

### 2. Translate file by file

Start with small files to build momentum, then tackle larger ones.

```bash
# View strings for a specific file
./run mfstrings inspect --fileid FILEID --cols key,comment,en --sortcol key

# For Main.xcstrings (Interface Builder), sort by comment instead
./run mfstrings inspect --fileid Main --cols key,comment,en --sortcol comment
```

### 3. Batch edit translations

```bash
./run mfstrings edit --path "fileid/key/LOCALE" --value "translated text" --state "translated"
```

Multiple edits can be run in sequence:
```bash
./run mfstrings edit --path "DownloadButton/1: download-button/_de" --value "Herunterladen" --state "translated"
./run mfstrings edit --path "Navbar/2: navbar.links.overview/_de" --value "Übersicht" --state "translated"
./run mfstrings edit --path "Navbar/3: navbar.links.github/_de" --value "Mehr auf GitHub" --state "translated"
```

### 4. Verify progress

```bash
# Check if locale was created
./run mfstrings list-cols | grep "LOCALE"

# Count translated strings
./run mfstrings inspect --fileid all --cols key,LOCALE,state:LOCALE --sortcol key 2>/dev/null | grep -c "translated"

# Preview translations
./run mfstrings inspect --fileid all --cols fileid,key,en,LOCALE --sortcol key 2>/dev/null | head -20
```

## Translation Guidelines Used

### Preserve format specifiers
- `%@`, `%1$@`, `%2$d` - C format specifiers
- `{url}`, `{name}`, `{trialDays}` - Python format specifiers
- `&nbsp;` - Non-breaking space HTML entity

### Follow comments
Comments provide crucial context:
- Which macOS terminology to match
- Related strings to check for consistency
- Layout constraints
- Where to find official Apple translations

### Language-specific adaptations
- German uses gendered articles: `einem **Trackpad**` vs `einer **Maus**`
- Trigger substrings are lowercase in German (except nouns): `klicke %@ und *ziehe*`
- Currency adapted: `$10` → `10€`

### Consistency checks
Button names appear in multiple places - keep them consistent:
- `trigger.substring.button-name.middle` → `mittlere Taste`
- `trigger.y.group-row.button-name.middle` → `Mittlere Taste` (capitalized as header)
- `capture-toast.button-name.middle` → `Mittlere Taste`

## File Categories

| Category | Files | Notes |
|----------|-------|-------|
| App UI | Main, Localizable, AuthorizeAccessibilityView, ButtonOptionsViewController, MenuBarItem, LicenseSheetController | Core app interface |
| Website | index, Intro, Navbar, BottomNav, DownloadButton, NormalFeatureCard, [...slug] | macmousefix.com |
| Documentation | Readme, Acknowledgements, Support, CapturedButtonsMMF3, CapturedScrollWheels, Shared | Markdown docs |
| Misc | Quotes, InfoPlist_1, InfoPlist_2 | User testimonials, bundle names |

## Comparison: `_de` vs existing `de`

The `_de` locale was created as a "blind" translation without referencing the existing hand-written `de` locale. This allows comparison to:
1. Evaluate AI translation quality
2. Find potentially better phrasings in either version
3. Identify consistency issues

To compare:
```bash
./run mfstrings inspect --fileid all --cols key,de,_de --sortcol key 2>/dev/null | less
```

---

## Reflections & Ideas for Improvement

Raw notes from reviewing the workflow. To refine later. [Jan 2026]

### Problem: Wrong file order

I translated `Localizable.xcstrings` last, but it contains the "source of truth" strings:
- `effect.click.middle`, `effect.back`, `drag-effect.scroll-swipe`, etc.
- `trigger.substring.button-name.*`
- All the core terminology that other files reference

Comments in other files say things like "should match `effect.click.middle`" - but I translated those *before* deciding what `effect.click.middle` should be in German. Got lucky with consistency, but this was fragile.

**Idea:** Translate `Localizable.xcstrings` FIRST, especially the `effect.*`, `drag-effect.*`, `trigger.substring.*`, `scroll-effect.*` families. Build a mental glossary, then apply it.

### Problem: Missed contextual comments

Noah placed explanatory comments on the first string where a tip becomes relevant (assuming top-to-bottom reading in Xcloc Editor). I didn't follow that order, so I probably missed some of this context.

### Idea: Group files by category

The three categories have different contexts:
1. **Main app** (Main, Localizable, AuthorizeAccessibilityView, etc.) - tight macOS terminology
2. **GitHub docs** (Readme, Acknowledgements, Support, etc.) - explanatory, references app terms
3. **Website** (index, Intro, Navbar, etc.) - marketing copy, still needs consistency

Maybe translate in this order, within each category starting with the "core" terminology files.

### Idea: Dependency-aware jumping

Instead of linear file-by-file:
1. Start translating string in file A
2. See comment "should match `effect.click.middle`"
3. **Pause** - jump to Localizable, translate that term first
4. Come back with the established term

This mimics how a human translator would work with a termbase/glossary.

### Problem: Couldn't verify macOS terminology

Comments said things like "find official translation in System Settings > Trackpad". I couldn't actually do that. Made guesses for:
- "Bedienungshilfen" (Accessibility) - correct?
- "Schreibtisch" vs "Desktop"
- "Spaces" - left English, is that right?
- "Anmeldeobjekte" (Login Items)
- "Mission Control", "Launchpad", "App Exposé" - kept English

**Idea:** Track uncertainties like the translation-review skill does:
```bash
echo "- Localizable/effect.desktop: Used 'Schreibtisch' but unsure if macOS uses this" >> /tmp/uncertainties.md
```

Then surface these at the end for human review.

### Goal

Make the workflow produce high-quality, consistent translations that:
- Match macOS terminology exactly where needed
- Stay consistent across app UI, docs, and website
- Surface uncertainties for human review rather than guessing silently

---

NOAH'S EXTRA NOTES:
    - ~~Maybe add native filter --fileid Localizable~~ Done! [Jan 2026]
    - ~~Make it so you can query the 'needs_review' rows for any locale identifier, without adding a string first~~ DONE!
    - ~~Maybe add examples for grepping for 'needs_review' to track progress. (A Claude said he had to eyeball progress cause there was no good way to progress tracking – But I think he might have been making stuff up)~~ DONE
    - The Claude said he was running out of context – but he also didn't look anything up – so maybe we should instruct for that (But I suspect the Claude might have been making stuff up.)
      
For human review:
    - ~~Add a --locale-diff de,_de arg to help compare AI translations against hand-written ones.~~ DONE! 