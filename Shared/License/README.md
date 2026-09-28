#  License Readme

## Fallback File

    Keep the `fallback_licenseinfo_config.json` file in sync with /licenseinfo/config.json on the mmf website.

## Future Plans – Fully Offline Licenses (Bought From Stripe) [Jan 2026]
    (Not sure I wrote about this somewhere else [Jan 2026])
    
    Scheme: 
        First  part of the license key is a license id (counter)
        Second part of the license key is a signature
        (The app itself would contain a public key, that could verify the counter against the signature.)
    
        Length
            - Claude says 128 bits is enough for very good security.
                - Examples / encodings
                    - Hex:        7A3F9C2E8B1D4F6A7C3E9B2D8F1A4C6E            (-> 32 chars, -> Nice)
                    - Emoji:      🦆🌵🔥🎺🦑🌙🍕🎸🐙🪐🦋🎭🌺                (-> 13 chars, -> Fun, -> Recognizable, -> Somewhat hand-enterable)
                    - Braille:    ⠓⠊⠑⠗⠕⠛⠇⠽⠏⠓⠊⠑⠎⠂⠃⠁                          (-> 16 chars, -> Spooky, -> Compact)
                    - Dashes:     7A3F-9C2E-8B1D-4F6A-7C3E-9B2D-8F1A-4C6E     (-> 32 chars, -> hand-typeable, -> Feels too busy at this length)
            - Lower than 128?: If we go lower than 128 it might be somewhat easy to keygen says Claude. Not sure what the right tradeoff is. 
                Thought: Keygen is worse than people uploading cracked app (since cracked app won't get cracked updates)
                Also see: Windows XP discussion below.
                
        Notes: 
            - Windows XP used a similar scheme for their license keys (Says Claude)
                - Length: 25 (XXXXX-XXXXX-XXXXX-XXXXX-XXXXX – I think this is the MS key format to this day)
                - Bits: 55 (Says Claude, I don't really understand)
                - Cracking difficulty: Private keys was computed in "6 hours on a Celeron 800".
                    -> Does that mean we also shouldn't care as much about cracking / keygen? 
                - "Sparsity" stuff: "Microsoft limited the value of the signature to 55 bits in order to reduce the amount of matching product keys"
                    -> I don't understand this. 

        Sources:
            - This Claude conversation: https://claude.ai/share/cc16b141-f206-4c0a-a4f1-07cf5cf74515
                -> At the end, Claude says it was confused the whole time, and was saying wrong things about the length and security of the keys.
            - XPKeygen: https://github.com/Endermanch/XPKeygen
            
        Update: [Jan 2026]
            New Idea: 
                - Use a short, normal-looking license key, but embed a zero-width character sequence that serves as the signature. 
                     -> Normal, length, normal-looking keys
                     -> Can offline validate in the usual case, where ppl just copy-paste from their email
                     -> If zero-width validation fails (e.g. due to ppl hand-copying the key, or email-client corrupting zero-width chars), we can still validate with the server.
            Problem:
                We can't do activation counting at all. 
                    -> If a key is publicly shared, we can't really detect that or do anything about it.
                        ... Except maybe if we make server-validation the default and offline validation the fallback? 
            
            Clarity: The whole motivation behind this is a person who emailed us about not being able to activate due to corporate network.
                -> Maybe we can find a better solution to that problem. 
                Ideas:
                    -> Maybe Stripe won't be blocked anyways?
                    -> Maybe the app could export an offline license or something? (which could consume an activation) 
                    -> Maybe we could provide special offline license for corporate users (instead of making it the default)
                    -> Maybe we just send corporate users a special build with no license activation?

# Threading

Everything licensing runs on `GlobalEventTapThread` (mainThread in the mainApp) as of [Sep 2026]. See `Threads.h` for overview/explanation of threading architecture.
