Human start here: (If you come back after a while and forgot context) [Apr 8 2026]
    - Find a batch of strings to translate
    - Create _ClaudeTranslations/ subfolder for that batch of strings. (E.g. TriggerStrings/)
    - Use PMT*.md file to find prompt template
        - (Don't just ask Claude, since it will use adding-translations/SKILL.md – which is currently outdated. TODO: Clean this all up)
    - Use SCR*.md file to find next language to translate into
    - Prompt Claude to translate into that language
    - Review and iterate
        - Use `# Supervise` bash commands to check against human translations
        - Maybe grep through glossary yourself. (See glossary-research.md)
        - Use follow-up/review prompts from PMT*.md file
        - Note mistakes/corrections/decisions under CTX*.md > Desired Translations

---

File naming convention:
- CTX prefix -> Context to have Claude read during translation
- PMT prefix -> Prompts to start Claude conversations
- SCR prefix -> Scratchpad files (for constructing prompts in different languages.?)
- CNC prefix -> Conclusion / reflection after working on this batch of strings.

From the end of CTXTriggerStrings.md: (Moving it here to not accidentally throw Claude off.)
(
    Note to self: None of Claude's translations into the other locales out of the human-translated ones (de, zh-Hans, ko, vi, cs, fr, pt-BR, ru, es, tr) had problems that I noticed. 
    NOTE2: All these translations were made before adding the 'Desired translations' so I don't know if Claude actually pays attention to them. 
)

To use Opus 4.5 instead of 4.6, use:
    ```
    claude --model claude-opus-4-5-20251101
    ```
    Why use 4.5? I haven't use 4.6 in Claude Code but in the Web interface I much prefer 4.5. It seems more reasonable and 'aligned'. [Feb 2026]

