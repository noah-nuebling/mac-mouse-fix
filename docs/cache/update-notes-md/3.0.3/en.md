Mac Mouse Fix **3.0.3** is ready for macOS 15 Sequoia. It also fixes some stability issues and provides several small improvements.

### macOS 15 Sequoia support

The app now works properly under macOS 15 Sequoia!

- Most UI animations were broken under macOS 15 Sequoia. Now everything's working properly again!
- The source code is now buildable under macOS 15 Sequoia. Before, there were issues with the Swift compiler preventing the app from building.

### Addressing scroll crashes

Since Mac Mouse Fix 3.0.2 there were [multiple reports](https://github.com/noah-nuebling/mac-mouse-fix/issues/988) of Mac Mouse Fix periodically disabling and re-enabling itself while scrolling. This was caused by crashes of the 'Mac Mouse Fix Helper' background app. This update attempts to fix these crashes, with the following changes:

- The scrolling mechanism will try to recover and keep running instead of crashing, when it encounters the edge case that seems to have led to these crashes. 
- I changed the way that unexpected states are handled in the app more generally: Instead of always crashing immediately, the app will now try to recover from unexpected states in many cases. 
    
    - This change contributes to the fixes for the scroll crashes described above. It might also prevent other crashes.
  
Sidenote: I could never reproduce these crashes on my machine, and I'm still not sure what caused them, but based on the reports I received, this update should prevent any crashes. If you still experience crashes while scrolling or if you *did* experience crashes under 3.0.2, it would be valuable if you shared your experience and diagnostic data in GitHub Issue [#988](https://github.com/noah-nuebling/mac-mouse-fix/issues/988). This would help me understand the issue and improve Mac Mouse Fix. Thank you!

### Addressing scroll stutters

In 3.0.2 I made changes to how Mac Mouse Fix sends scroll events to the system in an attempt to reduce scroll stutters likely caused by issues with Apple's VSync APIs.

However, after more extensive testing and feedback, it seems that the new mechanism in 3.0.2 makes scrolling smoother in some scenarios but more stuttery in others. Especially in Firefox it seemed to be noticeably worse. \
Overall, it was not clear that the new mechanism actually improved scroll stutters across the board. Also, it might have contributed to the scroll crashes described above.

That's why I disabled the new mechanism and reverted the VSync mechanism for scroll events back to how it was in Mac Mouse Fix 3.0.0 and 3.0.1. 

See GitHub Issue [#875](https://github.com/noah-nuebling/mac-mouse-fix/issues/875) for more info.

### Refund

I am sorry for the trouble related to the scrolling changes in 3.0.1 and 3.0.2. I vastly underestimated the problems that would come with that, and I was slow to address these issues. I'll do my best to learn from this experience and be more careful with such changes in the future. I'd also like to offer anyone affected a refund. Just click [here](https://redirect.macmousefix.com/?target=mmf-apply-for-refund) if you're interested.

### Smarter update mechanism

These changes were brought over from Mac Mouse Fix [2.2.4](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4) and [2.2.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.5). Check out their release notes to learn more about the details. Here's a summary:

- There's a new, smarter mechanism that decides which update to show the user.
- Switched from using the Sparkle 1.26.0 update framework to the latest Sparkle [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3).
- The window that the app displays to inform you that a new version of Mac Mouse Fix is available now supports JavaScript, which allows for nicer formatting of the update notes.

### Other Improvements & Bug Fixes

- Fixed an issue where the app price and related info would be displayed incorrectly on the 'About' tab in some cases.
- Fixed an issue where the mechanism for syncing the smooth scrolling with the display refresh rate didn't work properly while using multiple displays.
- Lots of minor under-the-hood cleanup and improvements.

---

Also check out the previous release [**3.0.2**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.2).



