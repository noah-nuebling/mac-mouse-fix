

Bug Experience [Sep 13 2025, Tahoe RC]
    I already tried to fix 'config reset' bugs by rewriting `Config.m > -[_loadAndRepair]`. See the notes there. However I just experienced similar bug where all the Remaps from the Remap Table were deleted:
        Memories:
            - IIRC the problem happened right after (or pretty soon after) I started my computer in the morning. 
                - Did I start different version of MMF or something first? Don't remember.
            - At first I noticed that only scrolling worked, button mappings no longer worked
            - I opened the MMF app and the mappings were still on the buttons tab. But when I tried to add an action the AddField got into this weird glitchy state.
                - IIIRC I restarted the mainApp several times and it always behaved this way.
            - Not totally sure about the order of these:
                - I tried to switch-off stuff from the helper's menubar item
                - Then I attached a debugger to the helper and figured out that the Remaps loaded from the config were completely empty.
                - Then I re-opened the mainApp and now the buttons tab was completely empty. (Not totally )
        Interpretations:
            - Perhaps the "Remaps" section in the config got corrupted, such that the helper couldn't read it anymore, but the mainApp still could.
                Then when I toggled stuff in the helper's menubar item, the helper called commitConfig() and deleted all the Remaps, because to it, the Remaps looked empty. (Cause it couldn't read them)
                - Next Questions:
                    - How does the helper end up just reading "no remaps" when the remaps are corrupted.
                        TODO: [ ] Investigate how the helper reads the Remaps from the config, and maybe install asserts / debug logs. (Look for place where it could fall back to empty Remaps) (See Remap.m) [Sep 13 2025]
                    - How did the Remaps get corrupted in the first place?
            - Perhaps there's a race condition where commitConfig() is called while config is still being loaded or something?
                - Next investigation steps:
                    TODO: [ ] Audit Config.m and make sure every entry point has an assert(NSThread.isMainThread)
        If I encounter this bug again, I should: `(If we find the bug again, we may not have to do the TODOs above.)`
            1. Immediately make a copy of the config in the 'corrupted' state. (Where the mainApp still displays the Remaps, but the helper doesn't apply them anymore)
            2. Then immediately attach a debugger to the helper right where it starts loading the config, or where it starts loading the Remaps from the config.
            3. Use a debugger to figure out why AddMode becomes glitchy
            3. Avoid toggling menuBarItem options since I suspect that it may delete the 'corrupted' Remaps.
