Mac Mouse Fix **3.0.7** addresses several important bugs.

### Bug Fixes

- App works again on **older macOS versions** (macOS 10.15 Catalina and macOS 11 Big Sur) 
    - Mac Mouse Fix 3.0.6 could not be enabled under those macOS versions because the improved 'Back' and 'Forward' feature introduced in Mac Mouse Fix 3.0.6 attempted to use macOS system APIs that weren't available.
- Fixed issues with **'Back' and 'Forward'** feature
    - The improved 'Back' and 'Forward' feature introduced in Mac Mouse Fix 3.0.6 will now always use the 'main thread' to ask macOS about which key-presses to simulate to go back and forward in the app you're using. \
    This can prevent crashes and unreliable behavior in some situations.
- Attempted to fix bug where **settings were randomly reset**  (See these [GitHub Issues](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue%20label%3A%22Config%20Reset%20Intermittently%22))
    - I rewrote the code that loads the config file for Mac Mouse Fix to be more robust. When rare macOS file-system errors occurred, the old code could sometimes mistakenly think that the config file was corrupt and reset it to default.
- Reduced chances of a bug where **scrolling stops working**     
     - This bug cannot be solved fully without deeper changes, which would likely cause other problems. \
      However, for the time being, I reduced the time-window where a 'deadlock' can happen in the scrolling system, which should at least lower the chances of encountering this bug. This also makes the scrolling slightly more efficient. 
    - This bug has similar symptoms – but I think a different underlying reason – to the 'Scroll Stops Working Intermittently' bug which was addressed in the last release 3.0.6.
    - (Thanks to Joonas for the feedback!) 

Thanks everyone for reporting the bugs! 

---

Also check out the previous release [3.0.6](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.6).





