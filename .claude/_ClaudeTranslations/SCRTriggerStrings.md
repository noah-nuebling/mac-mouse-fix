Locales with human backing

    Germanic
    - de    
    
    Romance
    - fr
    - pt-BR    
    - es

    Slavik
    - cs
    - ru

    East Asian
    - tr                (Turkish is closest to Korean I guess)
    - ko
    - zh-Hant
    - zh-HK
    - zh-Hans

    Southeast Asian
    - vi

Locales with no human backing

    Germanic
    - nl
    - sv
    - hi            (Hindi – closer to German than Southeast Asian languages, apparently)
    - el            (Indo European, I guess)

    Romance
    - ca
    - it
    - pt-PT
    - ro

    Slavic
    - hu
    - pl
    - uk

    Middle Eastern
    - ar
    - he

    East Asian
    - ja

    Southeast Asian
    - id
    - th

Locales to work on RN

    Germanic
    - [x] nl
    - [x] sv

    Romance
    - [x] pt-PT
    - [x] ca
    - [x] it
    - [x] ro

    Greek
    - [x] el

    Slavic
    - [ ] hu
    - [ ] pl
    - [ ] uk

    Chinese
    - [ ] zh-Hant
    - [ ] zh-HK

    Other Asian
    - [ ] th
    - [ ] ja
    - [ ] hi
    - [ ] id

    Middle Eastern
    - [ ] ar
    - [ ] he


---

# PROMPT

Hi there Claude! Please use the CTXTriggerStrings.md doc to translate the trigger.* strings into el (Greek)

The CTXTriggerStrings.md is the result of doing extensive research on the the existing strings and their comments, trust this and don't do extensive research yourself.

Use a glossary-research subagent for the Apple-specific terms. Explain to the subagent the context of how the strings you're requesting are used, so it can focus on relevant examples from the glossary. Think for yourself about whether the example translations that the subagent shows you are relevant here. If not, disregard Apple's translations and simply choose the translation that feels most natural and functional for its purpose. When translating a group of related strings, favor a consistent pattern. Glossary research may return inconsistent terms from different Apple source files.

Before translating each batch of strings (try to keep the batches around 5 or smaller), write out all the constraints that are relevant for the batch.

Do not read / invoke adding-translations/SKILL.md