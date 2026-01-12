
# PROMPT:

We're prototyping a bulk-translation workflow. The goal is to validate that a single context document can enable subagents to produce high-quality translations across multiple languages.

## Configuration

**Target languages** (in order): zh-Hans, de, ko, tr, ru, vi

**Strings to translate**:
- capture-toast.button-name.middle
- capture-toast.button-name.numbered
- capture-toast.button-name.primary
- capture-toast.button-name.secondary
- capture-toast.buttons.captured.body|==|one
- capture-toast.buttons.captured.body|==|other
- capture-toast.buttons.captured.hint|==|one
- capture-toast.buttons.captured.hint|==|other
- capture-toast.buttons.link
- capture-toast.buttons.uncaptured.body|==|one
- capture-toast.buttons.uncaptured.body|==|other
- capture-toast.scroll.captured.body
- capture-toast.scroll.link
- capture-toast.scroll.uncaptured.body

## Workflow

1. **Research & test translation**: Use the adding-translations skill to research context and translate into the FIRST language in the target list. This validates your understanding of the constraints.

2. **Prepare a language-agnostic context document**: Write a single document at ./TRANSLATION_CONTEXT.md containing all the context a subagent would need to translate the strings (including dependencies) into ANY language. Do NOT include language-specific translations - the doc should work for any target language.

3. **Delete your test translations**: The subagents need to translate "blind" without seeing your work.

4. **Spawn subagents sequentially**: For each target language (in the order listed), spawn a Claude Opus subagent. Pass it only:
   - (a) the path to your context doc
   - (b) the target language code

   Run sequentially, NOT in parallel (to avoid .xcstrings file corruption).

5. **Review**: For the FIRST language, compare the subagent's output against your own test translation. Note:
   - Any unfulfilled constraints
   - Missing strings
   - Suboptimal stylistic choices
   - Any decisions that could negatively impact usability for app users

Later, we'll validate the work of the other subagents, and if everything is good, then we'll have more subagents write translations into ALL the languages with the help of your context doc.

---

# NOTES:  (For human prompter)

**Recommended validation locales**: zh-Hans, de, ko, tr, ru, vi
- de:       Developer speaks German
- ko:       SOV grammar, honorifics, unique script (replaces ja – no human trans.)
- tr:       Agglutinative, vowel harmony (replaces ar – no human trans.)
- ru:       Cyrillic, grammatical cases, gendered nouns
- vi:       Tonal, isolating language, very different structure
- zh-Hans:  Logographic, no plurals, classifier system

Full locale list:
en, de, zh-Hant, zh-HK, zh-Hans, ko, vi, ar, ca, cs, nl, fr, el, he, hu, it, ja, pl, pt-BR, pt-PT, ro, ru, es, sv, tr, uk, th, id, hi

Locales with pre-existing human translations:
de, ko, vi, cs, fr, pt-BR, ru, es, tr, zh-Hant, zh-HK, zh-Hans

**Model size tests** for subagents: (All Claudes were of the 4.5 variant)

    (Claude Haiku) subagents produce translation errors in Chinese -> Use 4.5 Sonnet instead 
        (Should we use Opus?)

    (Claude Sonnet) subagents were mostly good, but didn't follow recommendation around translating as 'intercept' rather than 'capture', and in Chinese, didn't follow Apple's terminology as closely as the human translator.

    (Claude Opus) subagents matched the Chinese and German human translations extremely closely – it matched human Chinese much MORE closely than even the coordinator Claude (Even though they were both the same model) The coordinator first flagged these as inconsistencies, but later decided the subagent's / human's translations were more natural, and his were more literal.



---

# PROBLEM [Jan 11 2026]

Translated `capture-toast.*` strings into 11 locales:
de, zh-Hans, zh-Hant, ko, vi, fr, pt-BR, ru, es, tr, cs

Then have Claude compare against human translations.

**Overall quality**: Claude says it's excellent. Looks like: Better grammar and consistency, even understood some nuances better, paid better attention to comment hints (capitalization and 'intercept' terminology)

**Only Problem**

The `capture-toast.*` translations depend on `trigger.substring.button-name.*` which ITSELF DEPENDS on `trigger.substring.*` 

-> ALL `trigger.substring.*` should be translated first.

But the coordinator Claudes never find this 'transitive dependency'

If we don't do `trigger.substring.*` first, we may give buttons names that don't work right in the Action Table. 

Claude's analysis for tr and ko:

| Language | Machine | Human | Issue |
|----------|---------|-------|-------|
| Korean | 버튼 %@ | %@번 버튼 | Human's counter "번" is more natural Korean |
| Turkish | %@. tuş | Düğme %@ | Machine's ordinal could confuse if buttons aren't sequential |

**Action needed**: (Accoding to Claude) Add note to context document clarifying that trigger.substring.* are the "primary" button names, and capture-toast.* should match them exactly.

(**Caveat**: I might have nudged the Claude to make this into a bigger problem than it is – should verify. ... Yes after pushing back the Claude says it 'may be perfectly natural'.)

**Prompt used**

Hey there Claude! We just translated the first batch of strings of the app into the following languages.

de, zh-Hans, zh-Hant, ko, vi, fr, pt-BR, ru, es, tr, cs

The Claudes doing these translations did them all by themselves! But there were actually already human-written translations for these languages. Lets compare the translations in detail to see if we can find any mistakes or other interesting patterns. 

Let's go through each of the locales one-by-one and analyze them in detail, starting with 'de'. 

You can use this command to compare the human translations to the new machine generated ones:

./run mfstrings inspect --cols key,fileid,en,LOCALE,state:LOCALE --sortcol key --diff-filter HEAD --diff-highlight 72ca917f9,472bb34 --pretty
