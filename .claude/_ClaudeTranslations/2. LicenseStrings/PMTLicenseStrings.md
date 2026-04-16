Prompt              (Based on SCRTriggerStrings.md / PMTTriggerStrings.md)

    Main prompt
        Hi there Claude! Please use the CTXLicenseStrings.md doc to translate the license strings into Romanian (ro)

        Before translating each batch of strings (try to keep the batches around 5 or smaller), to help you keep the relevant constraints in mind, list all the string keys you've included in the batch, and then write out all the constraints that are relevant for those strings.

        You can also read the existing Spanish (es) translations for reference/comparison. (Consistency between languages is not important. What matters is the user experience.)

        Do not read / invoke adding-translations/SKILL.md
        Do not read the files next to CTXLicenseStrings.md

    Review prompts (Fresh Chat)
        (Human-backed languages)
            Main prompt: 
                Hi there Claude! I've been working on doing some translations with ChatGPT. I'm starting with languages where we already had human translations so we can validate the translations and improve
                the context for the agent (for the other languages)

                Could you check the Portuguese (pt-PT) translations?

                This command will let you see the human and the generated translations side-by-side: (Some of the bigger differences are because the human translations were a bit outdated)

                ./run mfstrings inspect --sortcol key --pretty --diff-highlight 72ca917f9,472bb34 --grep 'trial-notif|trial-counter|license-button|license-toast|JJv-GH-7io' --cols fileid,key,en,LOCALE

                See .../CTXLicenseStrings.md for the full context of which strings we we're translating and what guidance we gave to the translator.

                Please check for any regressions or interesting differences. Please explain the differences to me to help me gain an intuitive understanding. (I don't speak Portuguese)
                
            Amendment 1: (For early languages, if we want to understand every change ourselves.)
                ... Actually, I'll just show you all the strings, please just read CTXLicenseStrings.md and then we'll go through the strings one by one, ok?

            Followup 1:
                Thanks for the review!

                Do you notice anything that could be considered a regression?

        (non-human-backed languages)
            1. 
                Main prompt: (With comparison locale)
                    Hi there Claude! I've been working on doing some translations with ChatGPT. 

                    Let's review the Romanian (ro) translations.

                    This command will let you see the translations side-by-side with the Spanish (es) translations (Which are the closest existing translations):

                    ./run mfstrings inspect --sortcol key --pretty --grep 'trial-notif|trial-counter|license-button|license-toast|JJv-GH-7io' --cols fileid,key,en,LOCALE1,LOCALE2

                    Consistency between the different locales is not important, the idea behind the cross-comparison is to help us analyze and notice things to improve (In either locale – The reference locale has been validated against (outdated) human translations, but could still have potential for improvement)

                    See .../CTXLicenseStrings.md for the full context of which strings we're translating and what guidance we gave to the translator.

                    Please compare the translations and analyze them for any mistakes or other improvements. Please explain the problems and differences to me to help me gain an intuitive understanding. (I don't speak Romanian)

                    Do not read / invoke translation-review/SKILL.md
            2. 
                Main prompt: (No comparison locale)
                    Let's review the Catalan (ca) translations.

                    This command will let you see the translations:
                    ./run mfstrings inspect --sortcol key --pretty --grep 'trial-notif|trial-counter|license-button|license-toast|JJv-GH-7io' --cols fileid,key,en,LOCALE

                    See .../CTXLicenseStrings.md for the full context of which strings we're translating and what guidance we gave to the translator.

                    Please analyze the translations for any mistakes or other improvements. Please explain the problems and differences to me to help me gain an intuitive understanding. (I don't speak Catalan)

                    Do not read / invoke translation-review/SKILL.md

    Followups (Not using these anymore.)
        - Thanks Claude! I notice some things that could be improved. Could you go over the strings once more?
        - To be honest, I didn't notice anything wrong. I just found that asking leading questions like that makes the Claudes really look into things, you know? I hope that's ok. Thanks again for your work!
        
    Followups with bad results:
        Ah perfect! It looks good to me then, can you go over one more time and see if you find anything that could be simplified or expressed better?
            Explanation: Found one 'correction' in German which was made up. (But also not much worse) (Said it was more natural and the previous version sounded 'slightly off' which is not true)