
TODO: 
    - [ ] [Apr 13 2026] One of the recent locales had a string with \ or ' corruption at the start. (Looked like Claude messed up the '\'' trick) I forgot to address it.
    - [ ] [Apr 14 2026] Added some spaces in Chinese vs human translations – forgot to review that.
    - [ ] [Apr 15 2026] Check all languages for captialization mistakes
        - I noticed pt-BR has some random upper case (Relatório de **B**ug)
    - [ ] [Apr 16 2026] AI often chose especially 'warm' tone for trial-notif.body (following Turkish translator, I think) – maybe that's annoying for a 'bad news, paywall' message like this? (Only part of the app that is not designed in user interest I think – because I have to eat somehow)
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
      - [x] nl            (reference: de)
      - [ ] sv            (reference: de)

      Romance
      - [x] fr            (human-backed)
      - [x] pt-BR         (human-backed)
      - [x] es            (human-backed)
      - [x] pt-PT         (reference: pt-BR)
      - [x] ca            (reference: es)
      - [x] it            (reference: es)
      - [x] ro            (reference: es) (it if we use non-human-backed)

      Greek
      - [ ] el            (reference: es)

      Slavic
      - [x] cs            (human-backed)
      - [x] ru            (human-backed)
      - [x] pl            (reference: cs)
      - [x] uk            (reference: ru)

      East Asian
      - [x] tr            (human-backed)
      - [x] ko            (human-backed)
      - [ ] hu            (reference: cs [not same language family but same region?])
      - [ ] ja            (reference: ko [not same language family but same region?])

      Southeast Asian
      - [x] vi            (human-backed)
      - [ ] th            (reference: vi)
      - [ ] id            (reference: vi)
      - [ ] hi            (reference: de)

      Middle Eastern
      - [ ] ar            (reference: de [not very close but wrote de by hand])
      - [ ] he            (reference: de [not very close but wrote de by hand])

      Chinese
      - [x] zh-Hant       (human-backed)
      - [x] zh-HK         (human-backed)
      - [x] zh-Hans       (human-backed)

Generating CTXLicenseStrings.md             
    Just handwrite it.
    (For CTXTriggerStrings.md we had Claude gather all the information from referenced comments, so the real translator Claudes would not do 'research' on existing translations – but for this batch there are no such references – simpler)


Prompt
    Main prompt
        Hi there Claude! Please use the CTXLicenseStrings.md doc to translate the license strings into Swedish (sv)

        Before translating each batch of strings (try to keep the batches around 5 or smaller), to help you keep the relevant constraints in mind, list all the string keys you've included in the batch, and then write out all the constraints that are relevant for those strings.

        You can also read the existing German (de) translations for reference/comparison. (Consistency between languages is not important. What matters is the user experience.)

        Do not read / invoke adding-translations/SKILL.md
        Do not read the files next to CTXLicenseStrings.md
            
    Review prompt (fresh chat)

        Hi there Claude! I've been working on doing some translations with ChatGPT. 

        Let's review the Swedish (sv) translations.

        This command will let you see the translations side-by-side with the German (de) translations (Which are the closest existing translations):

        ./run mfstrings inspect --sortcol key --pretty --grep 'trial-notif|trial-counter|license-button|license-toast|JJv-GH-7io' --cols fileid,key,en,LOCALE1,LOCALE2

        Consistency between the different locales is not important, the idea behind the cross-comparison is to help us analyze and notice things to improve (In either locale – The reference locale has been validated against (outdated) human translations, but could still have potential for improvement)

        See .../CTXLicenseStrings.md for the full context of which strings we're translating and what guidance we gave to the translator.

        Please compare the translations and analyze them for any mistakes or other improvements. Please explain the problems and differences to me to help me gain an intuitive understanding. (I don't speak Swedish)

        Do not read / invoke translation-review/SKILL.md

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