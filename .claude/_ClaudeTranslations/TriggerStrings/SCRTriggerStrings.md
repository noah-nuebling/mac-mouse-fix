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
    - [x] he

    Chinese
    - [x] zh-Hant
    - [ ] zh-HK

---

# PROMPT

Hi there Claude! Please use the CTXTriggerStrings.md doc to translate the trigger.* strings into zh-Hant (Traditional Chinese)

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
    - [x] Ask about Click and Drag semantic oddity (should be 'Hold and Drag' to be pedantic)

        Agents didn't find issues with 'click/hold' semantics, but found other related concerns:
            - [x] pt-BR     │ Minor grammatical mixing (noun + infinitive) but acceptable as convention                                                              │
                -> This was a deliberate choice. see CTXTriggerStrings.md
            - [x] pt-PT     │ "deslocar" for scroll might be less idiomatic than "rolar"                                                                             │
                -> This matches Apple's glossary
            - [x] zh-Hant   | Suggests changing "按下" to "按一下" for single-click cases to match the established Apple/Microsoft convention and maintain pattern consistency with the double/triple click strings (which already use 按兩下/按三下)
                - Deliberate decision. See CTXTriggerStrings.md
            - [x] Ukrainian │ Notably verbose (~2x English character count) - could affect UI spacing. Could consider shorter "клік" instead of formal "клацання"    │
                -> Claude backpedaled. uk and ru are same length. It says using shorter "клік" (loanword) would feel 'lower quality' and not match what Apple/Microsoft use. (It hallucinated glossary research commands, so not sure this is trustworthy. Seufz.) (Also we often accepted slightly less polished sounding things for conciseness)
            - [x] Polish    │ Uses infinitive verb forms which is slightly unusual for UI labels. Imperative forms ("Kliknij i przeciągnij") might feel more natural │
                - After learning about 'descriptive' context and doing more research, Claude backpedals on imperatives and suggests noun-forms instead: "The current infinitives seem to be the odd choice - neither matching Apple's imperatives for commands nor their nouns for descriptions."

        - (Used in Thai and Korean)

    Specific problems I notice: 
        - [x] Hindi for 'hold' is super long.
            - Update: [Feb 2026] I don't see that. 'hold' is not very long (anymore?)
        - [x] Russian,Polish,Ukrainian strings are generally really long
            - Czech also sometimes
            - Greek sometimes
            - Hungarian sometimes
            -> review result: 
                - cs and ru had human translations that were very similar in length and in general.
                - Claude says there isn't much to improve
                - Claude suggests small improvements:
                    - [ ] cs: 
                        - kliknutí-> kliknutí, dvojí kliknutí → dvojklik, trojí kliknutí → trojklik
                            - (Introduces a slight grammatical 'inconsistency' for shortness. But the human did it this way. Claude says it's ok.)
                    - [ ] ru: нажатие -> клик, uk: клацання -> клік
                        - Loanword that could feel less 'professional' but is more concise.
                    - [ ] ru: удерживание -> удержание 
                        - Slightly shorter and that's what the human chose.
                        - Apple's glossary contains удерживание 2x (holding), удержание 0x (retention), удерживайте >30x (hold)
                    - [ ] pl: It says switching infinitives -> nouns is actually longer (but more Apple-standard (true – we told it that in the initial prompt.))
                    - [ ] el: πρωτεύοντος κουμπιού → κύριου κουμπιού (primary button -> main button)
                        - Says it's more 'apple aligned'. This is hallucination. It didn't have access to the glossary.
        - [ ] One of the modifier lines wraps in Russian and it looks weird.
        - [ ] ` + ` vs `＋` in Chinese (Human chose `＋` IIRC)
        - [ ] Inconsistent space across languages at end of strings like `trigger.substring.button-modifier.1`
            - We recently removed the part where our code manually adds a space there – for some reason.

    - [ ] Test / fix the ActionTable layouts
        - [ ] Saw it erroneously making space for 3 lines in Japanese (Text only took up 2 lines)
    - [ ] Check all languages for unnecessary spaces around the format specifiers.
    - [x] TODO: `NSColor.textColor` doesn't flip when rows are selected! UGHGHAGHAGHAHAHA