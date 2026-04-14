
TODO: 
    - [ ] [Apr 13 2026] One of the recent locales had a string with \ or ' corruption at the start. (Looked like Claude messed up the '\'' trick) I forgot to address it.

---

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
      - [x] pt-BR         (human-backed)
      - [x] es            (human-backed)
      - [ ] pt-PT
      - [ ] ca
      - [ ] it
      - [ ] ro

      Greek
      - [ ] el

      Slavic
      - [x] cs            (human-backed)
      - [x] ru            (human-backed)
      - [ ] pl
      - [ ] uk

      East Asian
      - [x] tr            (human-backed)
      - [x] ko            (human-backed)
      - [ ] hu
      - [ ] ja

      Southeast Asian
      - [x] vi            (human-backed)
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
        Hi there Claude! Please use the CTXLicenseStrings.md doc to translate the license strings into Vietnamese (vi)

        Before translating each batch of strings (try to keep the batches around 5 or smaller), to help you keep the relevant constraints in mind, list all the string keys you've included in the batch, and then write out all the constraints that are relevant for those strings.

        Do not read / invoke adding-translations/SKILL.md
        Do not read the files next to CTXLicenseStrings.md

    Review prompts (Fresh Chat)
        1. 
            Hi there Claude! I've been working on doing some translations with ChatGPT. I'm starting with languages where we already had human translations so we can validate the translations and improve
            the context for the agent (for the other languages)

            Could you check the Vietnamese (vi) translations?

            This command will let you see the human and the generated translations side-by-side: (Some of the bigger differences are because the human translations were a bit outdated)

            ./run mfstrings inspect --sortcol key --pretty --diff-highlight 72ca917f9,472bb34 --grep 'trial-notif|trial-counter|license-button|license-toast|JJv-GH-7io' --cols fileid,key,en,LOCALE

            See CTXLicenseStrings.md for the full context of which strings we we're translating and what guidance we gave to the translator.

            Please check for any regressions or interesting differences. Please explain the differences to me to help me gain an intuitive understanding. (I don't speak Vietnamese)
            
            [
            ... Actually, I'll just show you all the strings, please just read CTXLicenseStrings.md and then we'll go through the strings one by one, ok?
            ]

    Followups (Not using these anymore.)
        - Thanks Claude! I notice some things that could be improved. Could you go over the strings once more?
        - To be honest, I didn't notice anything wrong. I just found that asking leading questions like that makes the Claudes really look into things, you know? I hope that's ok. Thanks again for your work!
        
    Followups with bad results:
        Ah perfect! It looks good to me then, can you go over one more time and see if you find anything that could be simplified or expressed better?
            Explanation: Found one 'correction' in German which was made up. (But also not much worse) (Said it was more natural and the previous version sounded 'slightly off' which is not true)

Review 
    ./run mfstrings inspect --sortcol key --pretty --diff-highlight 72ca917f9,472bb34 --grep 'trial-notif|trial-counter|license-button|license-toast|JJv-GH-7io' --cols fileid,key,en,LOCALE


---

Removed from CTXLicenseStrings.md

    Turkish
        Desired translation: Use 3rd person possessive suffixes for 'free day' ('Ücretsiz günü'/'Ücretsiz günleri')
            Explanation: This is what a previous human translator chose, so we defer to that.
            Removal reason: Apparently a subtle grammatical case implying "*your* license key" based on context. Claude didn't follow this, used full formal second person possessive forms instead. Added long unrequested second person possessive elsewhere, too I think. Review Claude took forever to explain what is even going on here and contradicted itself/flip flopped based on my questions. And it's just a minor stylistic thing - Waste of time.

---

(Yet inconclusive) observations on formality
    - German    - macOS: Informal (du), Us: Informal (du)
    - Czech     - macOS: Formal (vy),   Us: Informal (ty)
    - Turkish   - macOS: Formal (siz),  Us: Formal (siz)
    - French    - macOS: Formal (vous), Us: Formal (vous)
-> Thoughts behind this: 
    - We want to use what feels common/natural for software addressing the user.
    - But the tone of the app is a bit more casual than macOS, I think. 
    - In some cases we deferred to what the human translator chose.