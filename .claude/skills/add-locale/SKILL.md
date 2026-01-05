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
