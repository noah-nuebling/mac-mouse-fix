Human start here: (If you come back after a while and forgot context) [Apr 8 2026]
    - Find a batch of strings to translate
    - Create _ClaudeTranslations/ subfolder for that batch of strings. (E.g. `1. TriggerStrings/`)
    - Use SCR*.md (scratchpad file) or PMT*.md (prompt iteration file) to find prompt template
        - (Don't just ask Claude, since it will use adding-translations/SKILL.md – which is currently outdated. TODO: Clean this all up)
    - Use SCR*.md (scratchpad file) to find next language to translate into
    - Prompt Claude to translate into that language
    - Review and iterate
        - Use `PMTContextDebugging.md > # Supervise` (Update: or `SCR*.md`) bash commands to check against human translations
            - TODO: Distill the still-relevant bits from `PMTContextDebugging.md` and then move that file to Old/
        - Maybe grep through glossary yourself. (See glossary-research.md)
        - Use follow-up/review prompts from SCR*.md or PMT*.md file
        - Note mistakes/corrections/decisions under CTX*.md > Desired Translations

File naming convention:
- CTX*.md -> Context to have Claude read during translation
- PMT*.md -> Iterate on prompts for Claude
- SCR*.md -> Scratchpad files (for constructing prompts in different languages.?)
- CNC*.md -> Conclusion / reflection after working on this batch of strings.

Language list in SCR*.md files:
    Order: Copy from the first SCR*.md files (SCRTriggerStrings.md, SCRLicenseStrings.md) (From easy to hard languages)
    Included languages: Just the languages of our Xcode project – See old `Choice of Languages.md`
        - We considered dropping zh-HK (low population, similar to zh-Hant, lot of review work) but I don't want to drop human translator's work.

To use Opus 4.5 instead of 4.6, use:
    ```
    claude --model claude-opus-4-5 --dangerously-skip-permissions
    ```
    Why use 4.5? It seems more reasonable and 'aligned'. [Feb 2026]

---

Random stuff

From the end of CTXTriggerStrings.md: (Moving it here to not accidentally throw Claude off.)
(
    Note to self: None of Claude's translations into the other locales out of the human-translated ones (de, zh-Hans, ko, vi, cs, fr, pt-BR, ru, es, tr) had problems that I noticed. 
    NOTE2: All these translations were made before adding the 'Desired translations' so I don't know if Claude actually pays attention to them. 
)