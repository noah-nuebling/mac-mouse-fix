# Universal Back and Forward

[Aug 2025] The 'Back' and 'Forward' Actions in MMF simulate navigationSwipes. However, this doesn't work in all apps. (Most notably VSCode)
    So for 3.0.6, we're trying to do a hotfix to improve compatibility

Also see 
    - `linearmouse > UniversalBackForwardTransformer.swift`

Investigation - How to go back and forward in different apps?

    LinearMouse uses Button 4 and Button 5 by default and goes to navigationSwipes based on this whitelist: [Aug 2025]
    ```
    - "com.apple.*",
    - "com.binarynights.ForkLift*",
    - "org.mozilla.firefox",
    - "com.operasoftware.Opera"
    ```
    Based on all the mac-mouse-fix issues labeled with "Universal Back and Forward", the following apps _don't_ work with navigationSwipes (which MMF used so far) [Aug 2025]
    (I'm possibly missing many newer issues since it's been a while since I went through and labeled them – but I did a bit of searching for 'Back Forward' on GitHub and found a few newer ones.)
    ```
    - Chrome sometimes doesn't go back shortly after the page loads (#1337)
    - VSCode                #1333, #1165, #1012, #808,  > needs MB 4/5 [Aug 2025]
                            #592, #588, #581, #551,
                            #456, #85, #162
    - Edge                  #1333                       > navigationSwipes work now, MB 4/5 work [Aug 2025]
    - Slack                 #1333, #1199, #1165, #551   > navigationSwipes work now, MB 4/5 work [Aug 2025]
    - Cursor                #1165                       > needs MB 4/5  [Aug 2025]
    - Zotero                #696                        > needs ⌘[/⌘] [Aug 2025]
    - System Settings       #592                        > needs ⌘[/⌘] [Aug 2025]
    - App Store             #592                        > needs ⌘[/⌘] (Actually, it only has 'back' not 'forward' [Aug 2025]
    - windows in vmware     #456                        > Not addressing VMs since I'd have to download Windows, and VMs could also be running macOS [Aug 2025]
    - Apollo                #355                        > Not addressing iPad apps since I'm too lazy (I assume they mean the iPad Reddit app) [Aug 2025]
    - Adobe Acrobat         #85                         > needs ⌘LeftArrow/⌘RightArrow (Previous view/Next view) but navigationSwipes also do some weird stuff [Aug 2025]
    - Football Manager?     #162                        > Not addressing games now. App-specific settings for games is probably better. (Also idk which football manager they meant) [Aug 2025]
    - Finder                #156                        > Always worked for me
    - Notion                #156                        > navigationSwipes work now, MB 4/5 also work [Aug 2025]
    ```
    Other apps that are similar to the ones we're received reports about:
    (Meta: Notes are a bit scattered, but IIRC, for each app I checked if MB 4/5, or navigationSwipes or ⌘[/⌘] do sth, and then also looked for back/forward and next/previous in the menu bar.)
    ```
    - VSCode forks:
        - VSCodium          > MB 4/5 works
        - Windsurf          > MB 4/5 works
        - Firebase Studio   > In-browser-app
        - PearAI            > Doesn't run on my Intel
        - Trae              > MB 4/5 works
    - Other programming tools:
        - Zed editor        > navigationSwipes do nothing. MB 4/5 works
        - Warp              > navigationSwipes do nothing. ⌘[/⌘] switches between 'panes'
        - Atom editor       > Sunset [Aug 2025]
        - Sublime text      > navigationSwipes do nothing. ⌃-/⇪⌃- Go back and forward. MB 4/5 jump between open files (but can be reconfigured in-app) –––> I'm thinking we should use MB 4/5 even though it's not back/forward by default.
        - Jetbrains IDEs    > navigationSwipes work. MB 4/5 works.
    - Other text editors
        - BBEdit            > too lazy to test [Aug 2025]
        - CotEditor         > navigationSwipes do nothing. ⌘[/⌘] indents text. ⎇⌘UpArrow/⎇⌘DownArrow select next/previous outline item. (I think back/forward is only in editors with file browser?)
    - Other pro apps
        - Aseprite          > Don't see a back/forward option [Aug 2025]
        - Affinity Photo 2  > My trial has expired [Aug 2025]
    - Other
        - Spotify           > navigationSwipes work. MB 4/5 works.
        - iPhone mirroring  > Too lazy to investigate now [Aug 2025]
        - iPad/iPhone apps  > Too lazy to investigate now [Aug 2025]
    - Other Apple apps like System Settings:
        (Not going through all Apple apps, mostly looking at 'content focused' ones, and ones that appear in the default Dock [Aug 2025])
        - Music         > ⌘[ goes back. No forward.
        - Podcasts      > No back/forward
        - Messages      > No back/forward
        - Mail          > No back/forward. navigationSwipes flip through messages.
        - Maps          > No back/forward.
        - Photos        > No back/forward
        - Calendar      > navigationSwipes do nothing. ⌘[/⌘] is Previous/Next occurrence of event, ⌘LeftArrow/⌘RighArrow is Previous/Next week/day/...
        - Contacts      > navigationSwipes do nothing. ⌘[/⌘] flips through contacts.
        - Reminders     > navigationSwipes do nothing. ⌘[/⌘] indents reminders.
        - Notes         > navigationSwipes do nothing. ⌘[/⌘] indents lines. ⎇⌘[/⎇⌘] goes to the previously viewed note.
        - Freeform      > navigationSwipes do nothing. ⌘[/⌘] indents lines. ⎇⌘[/⎇⌘] goes to the previous/next scene.
        - TV            > navigationSwipes do nothing. ⌘[ goes back. No forward.
        - Books         > navigationSwipes do nothing. Menu shows a few navigation options including ⌘[/⌘] but they're always greyed out (Maybe only for audiobooks)
        - Preview       > navigationSwipes both go to previous page. ⌘[/⌘] goes back and forward.
        -
        ```
        
    [Aug 2025] I tested all the programs listed above and they all work with MMF now! (if they have a back/forward function)

Bundle IDs:
    [Aug 2025] I investigated some app's bundle IDs but didn't end up needing them:
    - "com.microsoft.VSCode"
    - "com.todesktop.230313mzl4w4u92"            /// [Aug 2025] Cursor 1.4.2. Confusing. Not sure if this will break with their next update.
    - "com.vscodium"
    - "com.exafunction.windsurf"
    - "com.trae.app"
    - "com.visualstudio.code"                    /// [Aug 2025] PearAI has bundle ID `com.visualstudio.code.oss`. Perhaps other VSCode forks as well?
