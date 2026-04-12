
Batch of strings to translate:
    trial-notif.*
    trial-counter.*
    license-button.*
    license-toast.*
    JJv-GH-7io.placeholderString

Languages to work on (Do human-backed first)          (Based on SCRTriggerStrings.md)

    Germanic
      - [x] de            (human-backed)
      - [ ] nl
      - [ ] sv

      Romance
      - [x] fr            (human-backed)
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

        Before translating each batch of strings (try to keep the batches around 5 or smaller), write out all the constraints that are relevant for the batch.

        Do not read / invoke adding-translations/SKILL.md
        Do not read the files next to CTXLicenseStrings.md

    Followups
        - Thanks Claude! I notice some things that could be improved. Could you go over the strings once more?
        - To be honest, I didn't notice anything wrong. I just found that asking leading questions like that makes the Claudes really look into things, you know? I hope that's ok. Thanks again for your work!
        
    Followups with bad results:
        Ah perfect! It looks good to me then, can you go over one more time and see if you find anything that could be simplified or expressed better?
            Explanation: Found one 'correction' in German which was made up. (But also not much worse) (Said it was more natural and the previous version sounded 'slightly off' which is not true)

    Review prompts (Fresh Chat)
        1. 
            Hi there Claude! I've been working on doing some translations with coding Agents. I'm starting with languages where we already had human translations so we can validate the translations and improve the context for the agent (for the other languages)

            Could you check the French (fr) translations?

            This command will let you see the human and the generated translations side-by-side: (Some of the bigger differences are because the human translations were a bit outdated)

            ./run mfstrings inspect --sortcol key --pretty --diff-highlight 72ca917f9,472bb34 --grep 'trial-notif|trial-counter|license-button|license-toast|JJv-GH-7io' --cols fileid,key,en,fr

            See CTXLicenseStrings.md for the full context of which strings we were translating and what guidance we gave to the translator.

Review 
    ./run mfstrings inspect --sortcol key --pretty --diff-highlight 72ca917f9,472bb34 --grep 'trial-notif|trial-counter|license-button|license-toast|JJv-GH-7io' --cols fileid,key,en,LOCALE