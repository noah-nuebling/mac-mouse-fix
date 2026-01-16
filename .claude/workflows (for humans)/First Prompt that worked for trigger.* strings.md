
Below is the FIRST approach that ever produced a reasonable set of translations for a batch of strings (trigger.* strings) into two different languages (zh-Hans, de). This was on [Jan 14 2026] IIRC.

1. Ran adding-translations/SKILL.md (On trigger.* strings for Chinese) which produces ./TRANSLATION_CONTEXT.md.
2. Spawn a new Claude (Opus 4.5, WITH thinking) which uses TRANSLATION_CONTEXT.md and spawns a glossary-research.md subagent. 
    I used the following **prompt**: 

        Hi there Claude! Please use the TRANSLATION_CONTEXT.md doc to translate the trigger.* strings into Chinese (zh-Hans)

        The TRANSLATION_CONTEXT.md is the result of doing extensive research on the the existing strings and their comments, trust this and don't do extensive research yourself. 

        **Glossary**

        Use a glossary-research subagent for the Apple-specific terms. Explain to the subagent the context of how the strings you're requesting are used, so it can focus on relevant examples from the glossary. 

        When translating a group of related strings, ensure they follow a consistent pattern. Glossary research may return different terms from different Apple source files — use judgment to unify them within your UI context.

        Don't blindly copy from the glossary. Most of the examples from the glossary come from different apps with different UI context and different constraints from yours. Use these to inform your translations, but ultimately choose the most natural and simple translations.

        Do not read / invoke adding-translations/SKILL.md

    Model I used:
        Opus 4.5 in Claude Code, WITH thinking. (Never turned on thinking before. Also didn't A/B test whether thinking makes a difference.)
