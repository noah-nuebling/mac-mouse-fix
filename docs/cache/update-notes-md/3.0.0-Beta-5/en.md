Also check out the **neat changes** introduced in [3.0.0 Beta 4](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-4)!

---

**3.0.0 Beta 5** restores **compatibility** with some **mice** under macOS 13 Ventura and it **fixes scrolling** in many apps. 
It also features several other small fixes and and quality of life improvements.

Here's **everything new**:

### Mouse

- Fixed scrolling in Terminal and other apps! See GitHub Issue [#413](https://github.com/noah-nuebling/mac-mouse-fix/issues/413).
- Fixed incompatibility with some mice under macOS 13 Ventura by moving away from using unreliable Apple APIs in favor of low level hacks. Hope this doesn't introduce new issues - let me know if it does! Special thanks to Maria and GitHub user [samiulhsnt](https://github.com/samiulhsnt) for helping to figure this out! See GithHub Issue [#424](https://github.com/noah-nuebling/mac-mouse-fix/issues/424) for more infos.
- Will not use any CPU when clicking Mouse Button 1 or 2 anymore. Slightly lowered CPU usage when clicking other buttons.
    - This is a "Debug Build" so the CPU usage can be around 10 times higher when clicking buttons in this beta vs the final release
- The trackpad scrolling simulation that is used for Mac Mouse Fix' "Smooth Scrolling" and "Scroll & Navigate" features is now even more accurate. This might lead to better behaviour in some situations.

### UI

- Automatically fixing issues with granting Accessibility Access after updating from an older version of Mac Mouse Fix. Adopts the changes described in the [2.2.2 Release Notes](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.2).
- Added a "Cancel" button to the "Grant Accessibiliy Access" screen
- Fixed an issue where configuring Mac Mouse Fix wouldn't work properly after installing a new version of Mac Mouse Fix, because the new version would connect to the old version of "Mac Mouse Fix Helper". Now, Mac Mouse Fix will not connect to the old "Mac Mouse Fix Helper" anymore and disable the old version automatically when appropriate.
- Giving the user instructions on how to fix an issue where Mac Mouse Fix can't be enabled properly due to another version of Mac Mouse Fix being present on the system. This issue only occurs under macOS Ventura.
- Polished behaviour and animations on the "Grant Accessibiliy Access" screen
- Mac Mouse Fix will be brought to the foreground when it it's enabled. This improves the UI interactions in some situations like when you enable Mac Mouse Fix after it's been disabled under System Settings > General > Login Items.
- Improved UI strings on the "Grant Accessibiliy Access" screen
- Improved UI strings that show when trying to enable Mac Mouse Fix while it is disabled in System Settings
- Fixed a German UI string

### Under-the-hood

- The build number of "Mac Mouse Fix" and the embedded "Mac Mouse Fix Helper" are now synchronised. This is used to prevent "Mac Mouse Fix" from accidentally connecting to old versions of "Mac Mouse Fix Helper".
- Fixed issue where some data around your license and trial period would sometimes display incorrectly when starting the app for the first time by removing cache data from the initial configuration
- Lots of cleanup of the project structure and source code
- Improved debug messages

---

### How You Can Help

You can help by sharing your **ideas**, **issues** and **feedback**!

The best place to share your **ideas** and **issues** is the [Feedback Assistant](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report).
The best place to give **quick** unstructured feedback is the [Feedback Discussion](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366).

You can also access these places from within the app on the "**ⓘ About**" tab.

**Thanks** for helping to make Mac Mouse Fix better! 💙💛❤️