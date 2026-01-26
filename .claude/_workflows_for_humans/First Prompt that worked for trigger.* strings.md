
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


    Update: 
        ... [Jan 16 2026] This now produced totally wrong grammar for German xD (`Klicken Taste 4` instead of `Taste 4 klicken`). 
        
        This was the exact prompt that worked before for German: 

            Hi there Claude! Please use the TRANSLATION_CONTEXT.md doc to translate the trigger.* strings into German (de)

            The TRANSLATION_CONTEXT.md is the result of doing extensive research on the the existing strings and their comments, trust this and don't do extensive research yourself. 

            Use a glossary-research subagent for the Apple-specific terms. Explain to the subagent the context of how the strings you're requesting are used, so it can focus on relevant examples from the glossary. Think for yourself about whether the example translations that the subagent shows you are relevant here. If not, disregard Apple's translations and simply choose the translation that feels most natural and functional for its purpose.

            Do not read / invoke adding-translations/SKILL.md
        
        Testing this prompt again: 
            STILL works. 
            
            -> So those 2 extra sentences about not overindexing on the glossary (which were necessary for optimal Chinese output) makes it produce completely retarded translations for German... (Or maybe it's the formating? Nothing else changed.) I feel like sisyphus. How can this every scale to all 20+ languages.




    Attempt at **hybrid prompt** (That *actually* works for Chinese and German)

        Prompt:
            Hi there Claude! Please use the TRANSLATION_CONTEXT.md doc to translate the trigger.* strings into German (de)

            The TRANSLATION_CONTEXT.md is the result of doing extensive research on the the existing strings and their comments, trust this and don't do extensive research yourself. 

            Use a glossary-research subagent for the Apple-specific terms. Explain to the subagent the context of how the strings you're requesting are used, so it can focus on relevant examples from the glossary. Think for yourself about whether the example translations that the subagent shows you are relevant here. If not, disregard Apple's translations and simply choose the translation that feels most natural and functional for its purpose. When translating a group of related strings, favor a consistent pattern. Glossary research may return inconsistent terms from different Apple source files.

            Do not read / invoke adding-translations/SKILL.md

        Result:
            - Chinese -> Perfect
            - German -> Does about everything wrong (wrong grammar, idiotic word-choices)
                - Only difference to the prompt that works for German are these two small sentences "When translating a group..."
    

    **Extension** of the **hybrid prompt** that encourages German agent to not forget about like ALL of the constraints:

        Prompt: 
            Hi there Claude! Please use the CTXTriggerStrings.md doc to translate the trigger.* strings into Simplified Chinese (zh-Hans)

            The CTXTriggerStrings.md is the result of doing extensive research on the the existing strings and their comments, trust this and don't do extensive research yourself.

            Use a glossary-research subagent for the Apple-specific terms. Explain to the subagent the context of how the strings you're requesting are used, so it can focus on relevant examples from the glossary. Think for yourself about whether the example translations that the subagent shows you are relevant here. If not, disregard Apple's translations and simply choose the translation that feels most natural and functional for its purpose. When translating a group of related strings, favor a consistent pattern. Glossary research may return inconsistent terms from different Apple source files.

            Before translating each batch of strings (try to keep the batches around 5 or smaller), write out all the constraints that are relevant for the batch.

            Do not read / invoke adding-translations/SKILL.md
        
        Result: 
            Chinese -> Didn't follow consistency constraint. (`按钮 %@` vs `主键`)
            German  -> Didn't follow simplicity constraint (`Maustaste` instead of `Taste`)
            -> This seems hopeless.


    Trying to salvage this abysmal result via **Review** (translations-review/SKILL.md)
        Prompt: 
            Hello there Claude, please review the simplified Chinese (zh-Hans) trigger.* strings.
        Result:
            German -> Lists the moronic choice as under "one observation" but then rationalizes it away as the better choice. (It says Maustaste resolves 'ambiguity' of Taste)
            Chinese -> Lists the moronic choice under "Minor Observations (Not Issues)". And then moronically rationalizes it away. 
                Lists a second 'observation': `连按` (double click) vs `连按三次` (triple click) asymmetry. Also rationalizes this away. I think this one is reasonable. (Human translator also did it like this)
        Assessment:     
            If we get it to treat all the 'observations' as errors, we'd mostly get the desired results for German and Chinese. Except for `连按` vs `连按三次`. Where it would make `连按` longer to be consistent with `连按三次` ... I think that would be alright, though? ... Not sure this would scale to other languages,

    New idea: **micromanage desired translations** (And accept some imperfections)
        Taking a step back: The ` **Extension** of the **hybrid prompt**` translations for German and Chinese 
            - don't properly follow the specified constraints 
            - make some stupid decisions
       BUT. They're really close great. Chinese seems better than the human's translations (which also had some inconsistencies)
       -> Therefore: Why not roll with these translations?
            -> They're not perfect but perhaps (hopefully) better than volunteer human's translations (on average.)
            -> If we prefer some decisions by the humans (where we can't nudge the AI to make the right 'judgement calls' by itself) ... Then just tell the AI explicitly how to translate those terms.
            ->> It's labour intensive. It's not perfect. But it might be the best path forward.
        Update: It worked for de and zh-Hans!

