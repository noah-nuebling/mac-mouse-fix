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

Everything licensing runs on `IOThread` (mainThread in the mainApp) as of [Sep 2026]. See `Threads.h` for overview/explanation of threading architecture.

# 'Free days are over' bug [Oct 2026]

Greppable tag: (in source code)
    'Free days are over'

History:
    3.0.4 rewrote the licensing system with great care. 
    But we still received some reports from paying users getting 'Free days are over' notification! (aka TrialNotification)
    (I don't know where we wrote about this or what greppable tag we used back then, if any [Oct 2026])
    
In [Oct 2026], (for the release after 3.1.0)
    I asked multiple Claude Opus 5.5 at maxEffort to review all the user reports and check the code for any bugs that could explain this.
    The only plausible thing the Claudes found is that the 'environment ingredients' for the hash validating the `licenseStateCache` (offline license) 
    fail sporadically, causing the `licenseStateCache` to be seen as invalid at the same time as there's no internet/Gumroad connection.

    This seems kind of far fetched, but none of the Claudes, nor me could come up with anything else. (At maxEffort, they overcomplicate things, but it boiled down to this)
    
    The 'environment ingredients' for the hash are: [Oct 2026]
        - The license key, loaded from the keychain via 'SecureStorage' abstraction
        - The deviceUID
    
    -> So in [Oct 2026], we
        1. Rewrote `SecureStorage.swift` to `SecureStorage.m` and made all callers be 'lenient' in case of keyChain errors, 
            - 'lenient' meaning erring on the side of not locking people out of the app
            - In the case of GetLicenseState, we even accept the offline license, if we can not retrieve a licenseKey at all.
                - We think this is ok because the offline license is still validated against the deviceUID, 
                    -> preventing the 'one 30 second crack shared on forum that works for everyone forever' which the whole licensing system is designed to 'barely' prevent. (Obviously you can use open source app without a license but it can't be too easy, probably wrote about this somewhere else when originally writing the licensing system [Oct 2026])
                    -> Another Opus 5.5 notes it's a little easier crack since you could have a script that generates the config.plist for your machine that works without licenseKey and it wouldn't break even when the app updates. Before, such a script would've had to write to keychain which requires disabling AMFI. Not sure if Opus is thinking clearly (was maxEffort, which makes them a little retarded [Oct 2026]). I think it should be fine. 
                - To facilitate this, we split the combined offline-license-validation hash into two So we can partially verify against whatever info we have
                    (`License.licenseStateCacheHash` -> `License.licenseStateCacheHash_AgainstLicenseKey` and `License.licenseStateCacheHash_AgainstDeviceUID`)
                    The app currently still reads the old `License.licenseStateCacheHash` and can validate it against the old `deviceUID_V1`, it then automatically migrates config.plist to the new format.
                        -> The migration avoids another internet connection for people who are already offline-licensed 
                            -> this might be worth it for Chinese users who'd have to use a VPN to re-activate and stff
                            -> After a few MMF releases it should be ok to delete the migration code (`License.licenseStateCacheHash` and `deviceUID_V1`)
        2. Changed `deviceUID_V1` (MAC address) -> `deviceUID_V2` ("IOPlatformUUID") since Opus 5.5 said it might be more stable
        3. Added some better debug logs, in case In case there are still errors after 3.1.0
            - Relevant logs contain 'secureStorage' OR 'GetLicenseState' OR 'TrialCounter'
            - We use `DDLogError` to always persist some important-seeming errors 
                (Though we currently don't have a good way to gather logs from users. [Oct 2026]. Have plans with `runningDebugMode` stuff)

TODO / BOOKMARK [Oct 18 2026]: (Done -> Delete this)
    - [x] Make sure all the possible failure paths log, and probably with DDLogError since that persists the logs or something.
    - [x] Do the `TODO:`s added in the worktree, 
        I think only in `LicenseSheetController.swift`
        No, also in `TrialCounter.swift` (re-enable the `handleUse()` debug log; the non-Sendable `self` capture warning in the daily timer),
    - [xxx] Maybe link Claude conversation here
    - [x] Maybe paste in Claude's list of user reports here
    - [x] Maybe add source code comment about double-loading of secureStorage in GetTrialState or whereever Claude said that was, and why it's ok.
    - Claude ideas for tests before release: (Also see TrialCounter.swift > Testing checklist)
        - Fresh install (no keychain item, no cache) -> no crash, trial active
        - Update from 3.1.0 with legacy `licenseStateCacheHash` -> migrates to the new hashes, both online and offline
        - Simulated keychain failure (e.g. make `readSecureStorage` return `UnexpectedError`) -> cached license is trusted, no lockdown; `handleUse()` hits the keychain at most once per day
        - Copy `config.plist` to another Mac without the key -> rejected via the deviceUID hash
        - Remove the license in the license sheet -> unlicensed afterwards
    
User reports that Opus 5.5 found [Oct 2026]
    
    About 30 reports since mid-2025 (when 3.0.4 shipped the current licensing code), from Apple Mail's local store and public GitHub issues. Nearly all are on 3.0.6–3.0.8, which makes sense since the code is the same as 3.1.0.

    **A. Pay prompt after a reboot, login or macOS update; the key is still there and re-enabling fixes it (largest group)**
    This fits Bug 2 (cache deleted) plus Bug 1 (offline at login) plus the one-way lockdown (section 4). See open question 1 for why "every login" isn't fully explained yet.
    - 2026-08-26 Brendon Scarano (3.0.8): after reboot, pay prompt, although the app says the license is active.
    - 2026-08-24 Bilal Kapadya (3.0.8): every reboot; toggling MMF off and on fixes it.
    - 2026-08-19 GitHub #1975 + braddurbin (3.0.8): "forgets" the license after a boot.
    - 2026-08-18 Jo Park: prompted to buy; key pre-filled; Activate does nothing.
    - 2026-04-19 Wendi Harvey (3.0.8): **every login**; clicking Activate on the pre-filled key fixes it.
    - 2026-03-16 GitHub #1781 (3.0.8): can't enable; a restart fixed it.
    - 2026-02-17 Leonardo Agraz (3.0.8): paid a second time, then noticed the key was already filled in.
    - 2025-12-13 Dan Kress (3.0.8): **every startup**.
    - 2025-12-05 GitHub #1663 + sgilder1 (3.0.8): started after a macOS update, then every restart.
    - 2025-09-30 Pablo Guerrero: right after updating to Tahoe 26.0.1; closing the popup fixed it.
    - 2025-08-21 Lyn Volkmann (3.0.6): after macOS updates; re-enabling fixes it.
    - 2025-09-17 Tim Otheo: after a macOS update the app showed the 30-day trial *again* and the key was missing. That is exactly what a failed read of the shared keychain item looks like (Bugs 2 and 5).

    **B. Offline or Gumroad blocked: locked out and can't reactivate ("No internet connection")**
    This is Bug 1. These users can't fix it by going online.
    - 2026-09-03 GitHub #1989 (3.1.0 Beta 1): blocks Gumroad; gets "Free days are over" about monthly, which matches the macOS update rhythm (group A's trigger).
    - 2026-08-09 and 2026-04-08 eliasfanli (China): license "becomes invalid after every system update"; needs a VPN to reactivate.
    - 2026-07-20 GitHub #1939: after a reboot, unusable, "No internet connection".
    - 2026-04-24 GitHub #1819 + 2 commenters: same; error `NSPOSIXErrorDomain 42` through a proxy; one fixed it with a specific VPN.
    - 2025-11-01 Gareth Mills: "Each time I go offline it disables the tool."
    - 2025-10-05 GitHub #1580: prompted again; reactivation says no internet.
    - 2025-09-30 Kevin (qq.com): after macOS 26 update, prompted to activate; activating does nothing.
    - 2026-07-21 GitHub #1941 and 2026-01-12 Matt Hocking: new buyers who can't activate, "offline" although online.

    **C. Key lost entirely; user had to find it again or ask for it**
    Possibly Bugs 2/5, but the reports don't say enough.
    - 2026-09-30 Jamison Shekter: bought in March, got "free days are over", had the key resent. **The only email report dated after 3.1.0's release.**
    - 2026-07-12 Atul Gautam (3.0.8): asked to pay for months.
    - 2026-05-25 Martin Rothen, 2026-03-13 Thomas Ottermann: bought earlier, now asked to pay; unclear which group.

    **D. Activation limit (Bug 3)**
    - 2026-09-03 Shawn Morse (follow-up 2026-09-16, no reply found): over the limit because every re-created macOS user account needs a new activation (keychain items are per user).
    - 2026-07-23 Daniel Venezian: after a reinstall, "license is already in use".
    - 2025-12-01 Tong Yu, 2025-09-21 Anirban Ain: "already activated" on a new Mac or after a reinstall. This may just be the old toast wording you changed in October 2025, not the real limit.

    **E. Probably a different bug: an old or duplicate helper**
    - GitHub #1843 (2026-05) and #1464 (2025-07, 3.0.5): activation succeeds and the About tab says licensed, but enabling still shows the trial notification. Only wiping the app's support files and login items fixed it. This points to an old helper still being registered, not to the license check.
    - GitHub #1939 also has 31 helper crash reports after the reboot; the helper aborts during `+load` at startup. Looks like a separate crash.

    **Older reports, already fixed**
    3.0.4-era reports (Peter Dubrivny, Sam Schnorr, Jukka Laaksonen who paid twice, GitHub #1462) were Intel Macs, traced to the decoding bug fixed in 3.0.5.

    **Limits of the search**
    Keyword-based, so differently worded reports may be missing. Only mail that Apple Mail had downloaded was searched, your own messages were skipped, and screenshots couldn't be read (so e.g. Filip Marak's "expired" key couldn't be grouped).
