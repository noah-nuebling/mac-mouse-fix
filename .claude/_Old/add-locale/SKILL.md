---
name: add-locale
description: Add translations for a new locale. Use when translating Mac Mouse Fix into a new language (e.g., adding German, French, Japanese).
---

# Add Locale Workflow

This skill covers translating Mac Mouse Fix into a **new** locale from scratch. For reviewing/fixing existing translations, use the `translation-review` skill instead.

## Getting Oriented

Run `./run mfstrings list-files` to see all translation files. The files fall into three categories based on their paths:

- **Markdown translations** — Files under `Markdown/`. These are for GitHub documentation.
- **Website translations** — Files under `../mac-mouse-fix-website/`. These are for the project website.
- **App translations** — All other files. These are the core UI strings.

**Start with the app translations.** They form the foundation—terminology and phrasing established here is often referenced by the Markdown and website files. Within the app translations, begin with the largest files (`Localizable` and `Main`) since they contain the core UI vocabulary.

## Following References

Translation comments often reference other strings (e.g., "match the translation for key `xyz`"). When you encounter such a reference:

1. Jump to the referenced string's file
2. Read the surrounding context to understand the "logical group" it belongs to
3. Translate that group if needed (you may need to read earlier strings for context)
4. Return to complete your original file

Don't just translate file-by-file mechanically. Follow references as they arise—this ensures consistency across related strings. If you've translated a term before but it's no longer in your context, look it up to maintain consistency.

## Using mfstrings

Use `./run mfstrings` to inspect and edit translations. Key commands:

```bash
# View strings for a file
./run mfstrings inspect --fileid Localizable --cols key,comment,en --sortcol key

# For Main.xcstrings, sort by comment (its keys are non-descriptive Interface Builder IDs)
./run mfstrings inspect --fileid Main --cols key,comment,en --sortcol comment

# Edit a translation
./run mfstrings edit --path "fileid/key/LOCALE" --value "translated text" --state "translated"

# Check progress
./run mfstrings progress --files all --locales LOCALE
```

Batch multiple edits in a single command block:
```bash
./run mfstrings edit --path "Localizable/effect.click/de" --value "Klick" --state "translated"
./run mfstrings edit --path "Localizable/effect.scroll/de" --value "Scrollen" --state "translated"
```

## Tracking Uncertainties

Translation involves judgment calls. Track things you're unsure about:

```bash
echo "# Uncertainties" > /tmp/uncertainties.md
echo "- Localizable/effect.desktop: Used 'Schreibtisch' but unsure if macOS uses this" >> /tmp/uncertainties.md
```

Things worth noting:
- macOS terminology you couldn't verify
- Layout/length concerns
- Choices between equally valid options

When uncertain about a string, you can still translate it—just use `--state "needs_review"` instead of `"translated"`. At the end, share your uncertainties with the user.
