

Ran this Skill on German with Opus 4.5.  [Jan 6 2026]

Conclusion: 
    Having Claude translate a whole locale in bulk does not work.
    The context window is too small. 
    I think the repetitive task makes it go crazy a little bit. 

    Makes bad mistakes.
    Doesn't follow instructions to do periodic reviews. 
    Doesn't read comments properly.
    Translations inconsistent and sloppy. 

    Worse than 90% of volunteer human translators I've worked with. 
        (Although the feedback cycle is faster)

    Afterwards I try to discuss and it starts hallucinating. 
    
    (My mental model for the hallucinations is that either the context is too 
        full or the repetive work or something in the translations 
        made it misaligned – not sure that makes sense.)
    
    Observation: It's not just about context deterioration. 
        Lots of really bad mistakes happened in the first file 
        it worked on (Localizable.xcstrings)

    -> This does not work

Caveat:
    - I did interrupt it when it was almost done with Localizable.xcstrings, because I had to fix some bugs with mfstrings plural handling. Maybe that threw it off? But many bad mistakes had already happened at that point.

Improvement ideas for the next cycle:
    - Do the translations 'laterally' instead of 'vertically'
        - -> Translate a small set of interdependent strings in 
        a short session.
        Once it's good for German, apply the exact same prompt & 
        context to all other languages. 
        - -> Benefit: Short session per Claude, no repetive work. 
            Maybe more 'fun' and 'engaging' for the Claude. Short 
            iteration / review cycle for me to improve the context.
        Other ideas:
            - Maybe have a review Claude run after a batch of strings.
            - Maybe have planning Claude find an 'interdependent' set 
                of strings to pass to a subclaude as a batch, (and decide the order of them.)
                Counterpoint: 
                    - To do this well, the Claude will already have to understand all the context, which the translator Claudes will also have to understand.
                    - The translator Claudes will have very small session length – so I think there's no benefit to this?
---

# Evidence


Diff between the Claude's translations and my handwritten ones (German) in [diff.txt](diff.txt)
    (Output for `./run mfstrings inspect --fileid all --cols key,fileid,en,de,comment --sortcol fileid --diff`)
    (We could extend mfstrings to pretty print this if we need to review again later.)

Specific problems I noticed in the diff:

    1. Terminology: Changed "abfangen" (intercept) to "erfassen" (capture/detect)
       - Localizer hint specifically instruct to translate as 'intercept'.

    2. Terminology: Changed "Sondertasten" to "Tastaturmodifikatoren"
       - "Sondertasten" is the standard macOS term (used throughout System Settings)
       - "Tastaturmodifikatoren" is an awkward literal translation
       - AI later argued I was wrong and "Sondertasten" means function keys (hallucination)

    3. Grammatical consistency broken in trigger.substring.* strings:
       - My version: consistent infinitives ("%@ doppelklicken und *ziehen*")
       - AI version: mixed noun + imperative ("Doppelklick und *ziehe* %@")
       - "Doppelklick und ziehe Taste 4" is grammatically broken German
         (can't connect a noun with a conjugated verb using "und")
       - AI ignored the translator note about these strings being joined programmatically

    4. Ignored translator notes telling it to check System Settings for official terms
       - Several UI terms mistranslated where notes explicitly said "look in System Settings"

    5. Didn't use uncertainties.md as instructed
       - Didn't write anything into uncertainties.md as instructed in SKILL.md
       - When I interrupted to pointed out errors mid-translation and told it to note them, it noted those specific errors, but never anything else.
       - Told it to write something, at least <no uncertainties> after every batch of translated strings.
       - It only ever wrote <no uncertainties> and then stopped doing even that after like 10 strings.

    6. Minor inconsistencies:
       - Quote marks: 'single' → „German" (consistency with app UI matters more)
       - Currency: "$10 mouse" → "10-Euro-Maus" (maybe undesirable)
       - "Tempo" → "Geschwindigkeit" (Longer)
       - "Regulär" → "Normal" (Avoided 'Normal' in English to avoid judgement connotation.)

Suggestions that Claude made to improve SKILL.md:

    1. Add explicit instruction: "Read every translator comment completely. 
       If it says to check System Settings, do so before translating."

    2. Add guidance on grammatical consistency across related string groups
       (e.g., trigger.substring.* strings must share the same grammatical structure)

    3. Include a pre-populated glossary of confirmed macOS terminology 
       (Sondertasten, Schreibtisch, etc.) directly in SKILL.md

    4. Make uncertainty tracking mandatory, not optional
       - Require specific observations, not just "no uncertainties"
       - Add batch checkpoints: after every N strings, require the agent to 
         review work, log observations, and verify consistency within string groups

    5. Break translation into separate sessions per file
       - Summarize established terminology between sessions
       - Keeps context smaller, prevents "working frenzy" autopilot mode

