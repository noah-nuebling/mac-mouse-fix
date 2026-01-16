
Below is the FIRST approach that ever produced a reasonable set of translations for a batch of strings (trigger.* strings) into two different languages (zh-Hans, de). This was on [Jan 14 2026] IIRC.

1. Ran adding-translations/SKILL.md (On trigger.* strings for Chinese) which produces ./TRANSLATION_CONTEXT.md.
2. Spawn a new Claude which uses TRANSLATION_CONTEXT.md and spawns a glossary-research.md subagent. I used the following **prompt**: 

    Hi there Claude! Please use the TRANSLATION_CONTEXT.md doc to translate the trigger.* strings into Chinese (zh-Hans)

    The TRANSLATION_CONTEXT.md is the result of doing extensive research on the the existing strings and their comments, trust this and don't do extensive research yourself. 

    Use a glossary-research subagent for the Apple-specific terms. Explain to the subagent the context of how the strings you're requesting are used, so it can focus on relevant examples from the glossary. Think for yourself about whether the example translations that the subagent shows you are relevant here. If not, disregard Apple's translations and simply choose the translation that feels most natural and functional for its purpose.

    When translating a group of related strings, ensure they follow a consistent pattern. Glossary research may return different terms from different Apple source files — use judgment to unify them within your UI context.

    Do not read / invoke adding-translations/SKILL.md
