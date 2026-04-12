
Batch of strings to translate:
    trial-notif.*
    trial-counter.*
    license-button.*
    license-toast.*
    JJv-GH-7io.placeholderString

Languages to work on (Do human-backed first)          (Based on SCRTriggerStrings.md)

    Germanic
      - [ ] de            (human-backed)
      - [ ] nl
      - [ ] sv

      Romance
      - [ ] fr            (human-backed)
      - [ ] pt-BR         (human-backed)
      - [ ] es            (human-backed)
      - [ ] pt-PT
      - [ ] ca
      - [ ] it
      - [ ] ro

      Greek
      - [ ] el

      Slavic
      - [ ] cs            (human-backed)
      - [ ] ru            (human-backed)
      - [ ] pl
      - [ ] uk

      East Asian
      - [ ] tr            (human-backed)
      - [ ] ko            (human-backed)
      - [ ] hu
      - [ ] ja

      Southeast Asian
      - [ ] vi            (human-backed)
      - [ ] th
      - [ ] id
      - [ ] hi

      Middle Eastern
      - [ ] ar
      - [ ] he

      Chinese
      - [ ] zh-Hant       (human-backed)
      - [ ] zh-HK         (human-backed)
      - [ ] zh-Hans       (human-backed)

Generating CTXLicenseStrings.md             
    Just handwrite it.
    (For CTXTriggerStrings.md we had Claude gather all the information from referenced comments, so the real translator Claudes would not do 'research' on existing translations – but for this batch there are no such references – simpler)


Prompt              (Based on SCRTriggerStrings.md / PMTTriggerStrings.md)

    Main prompt

        Hi there Claude! Please use the CTXLicenseStrings.md doc to translate the license strings into German (de)

        The CTXLicenseStrings.md is the result of doing research on the the existing strings and their comments, trust this and don't do extensive research yourself.

        If necessary, use a glossary-research subagent for the Apple-specific terms. Explain to the subagent the context of how the strings you're requesting are used, so it can focus on relevant examples from the glossary. Think for yourself about whether the example translations that the subagent shows you are relevant here. If not, disregard Apple's translations and simply choose the translation that feels most natural and functional for its purpose. When translating a group of related strings, favor a consistent pattern. Glossary research may return inconsistent terms from different Apple source files.

        Before translating each batch of strings (try to keep the batches around 5 or smaller), write out all the constraints that are relevant for the batch.

        Do not read / invoke adding-translations/SKILL.md

    Followups

        Followup
            Thanks Claude! I notice some things that could be improved. Could you go over the strings once more?

        Followup 2
            To be honest, I didn't notice anything wrong. I just found that asking leading questions like that makes the Claudes really look into things, you know? I hope that's ok. Thanks again for your work!

Review 
    ./run mfstrings inspect --sortcol key --pretty --diff-highlight 72ca917f9,472bb34 --grep 'trial-notif|trial-counter|license-button|license-toast|JJv-GH-7io' --cols fileid,key,en,LOCALE