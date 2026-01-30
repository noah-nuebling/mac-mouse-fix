# Locales with human backing

    Germanic
    - de    
    
    Romance
    - fr
    - pt-BR
    - es

    Slavic
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

# Locales with no human backing

    Germanic
    - nl
    - sv
    
    Greek
    - el            (Indo European, I guess)

    Romance
    - pt-PT
    - ca
    - it
    - ro

    Slavic
    - pl
    - uk

    East Asian
    - hu            (Hungarian is sorta similar to Turkish I guess)
    - ja

    Southeast Asian
    - th
    - id
    - hi            (Hindi – closer to German than Southeast Asian languages, apparently)

    Middle Eastern
    - ar
    - he

# Locales to work on RN

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
    - [x] pl
    - [x] uk

    East Asian
    - [x] hu        
    - [x] ja
    
    Southeast Asian
    - [x] th
    - [x] id
    - [x] hi

    Middle Eastern
    - [x] ar
    - [ ] he

    Chinese
    - [ ] zh-Hant
    - [ ] zh-HK

---

# PROMPT

Hi there Claude! Please use the CTXTriggerStrings.md doc to translate the trigger.* strings into ar (Arabic)

The CTXTriggerStrings.md is the result of doing extensive research on the the existing strings and their comments, trust this and don't do extensive research yourself.

Use a glossary-research subagent for the Apple-specific terms. Explain to the subagent the context of how the strings you're requesting are used, so it can focus on relevant examples from the glossary. Think for yourself about whether the example translations that the subagent shows you are relevant here. If not, disregard Apple's translations and simply choose the translation that feels most natural and functional for its purpose. When translating a group of related strings, favor a consistent pattern. Glossary research may return inconsistent terms from different Apple source files.

Before translating each batch of strings (try to keep the batches around 5 or smaller), write out all the constraints that are relevant for the batch.

Do not read / invoke adding-translations/SKILL.md

# Followup
Thanks Claude! I notice some things that could be improved. Could you go over the strings once more?

# Followup 2
To be honest, I didn't notice anything wrong. I just found that asking leading questions like that makes the Claudes really look into things, you know? I hope that's ok. Thanks again for your work!

# Followup 3

Ok great, thanks for your work on that!
Finally, could you go over the strings once more and see if you can find any potential improvements or simplifications?

# Followup 4

Ok great, thanks for looking into that !
Are there any more things about the [[[Ukrainian]]] strings that could be simplified or improved?

# Followup 5

Hi Claude! Can you review this [[Arabic]] UI I've been working on with Gemini?

---

# TODO

- After these are done:
    - [ ] Ask this for all languages:
        One thing I just thought of that I'm not totally sure is explained in the translation context, is that the Click %@ + strings actually mean holding that button and then doing whatever comes after the +. In English we think this works partly because of context and because it draws on the established 'Click and Drag' phrase which also uses 'Click' to
        actually imply holding and then doing something else.

        Was that something you were thinking about?

        If not, does that change what you think the optimal translations for these strings would be?
    - [ ] Test / fix the ActionTable layouts
        - [ ] Saw it erroneously making space for 3 lines in Japanese (Text only took up 2 lines)