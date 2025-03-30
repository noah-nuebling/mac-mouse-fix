Also check **what was new** in [3.0.0 Beta 3](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-3)!

---

**3.0.0 Beta 4** brings a new **"Restore defaults..." option** as well as many **quality-of-life** improvements and **bug fixes**!

Here's **everything** that's **new**:

## 1. "Restore Defaults..." option

There's a "**Restore Defaults...**" button on the "Buttons" tab now. 
This allows you to feel even more **comfortable** while **experimenting** with settings.

There are **2 defaults** available: 

1. The "Default setting for  mice with **5+ buttons**" is super powerful and comfortable. In fact It lets you do **everything** you do on a **trackpad**. All using the 2 **side buttons** that are right where your **thumb** rests! But of course it's only available on mice with 5 or more buttons.
2. The "Default setting for mice with **3 buttons**" still lets you do the **most important** things you do on a trackpad - even on a mouse that only has 3 buttons.

I tried hard to make this feature **smart**:

- When you start MMF for the first time it will **automatically select** the preset that **best fits your mouse**.
- When you go to restore defaults, Mac Mouse fix will **show you** which **mouse model** you are using and its **number of buttons**, so you can easily make a choice about which of the two presets to use. It will also **pre-select** the preset that **best fits your mouse**.
- When you switch to a **new mouse** that doesn't fit your current settings, a popup on the Buttons tab will **remind you** how to **load** the recommended settings for your mouse!
- All the **UI** surrounding this is very **simple**, **beautiful** and it **animates** nicely.

I hope you find this feature **useful** and **simple to use**! But let me know if you have any issues. 
Is something **weird** or **unintuitive**? Do the **popups** show up **too often** or in **inappropriate situations**? **Let me know** about your experience!

## 2. Mac Mouse Fix temporarily free in some countries 

There are some **countries** where the Mac Mouse Fix's **payment provider** Gumroad **doesn't work** currently. 
Mac Mouse Fix is now **free** in **those countries** until I can provide an alternative payment method!

If you're in one of the free countries, information about this will be **displayed** on the **About tab** and when **entering a license key**

If it is **impossible to purchase** Mac Mouse Fix in your country, but it's also **not free** in your country, yet - then let me know and I'll make Mac Mouse Fix free in your country, too!

## 3. A good time to start translating!

With Beta 4, I've **implemented all the UI changes** that I have planned for Mac Mouse Fix 3. So I expect there to be no more large changes to the UI until Mac Mouse Fix 3 releases.

If you've been holding off because you expected the UI to still change, then **this is a good time** to start **translating** the app into your language!

For **more info** on translating the app see **[3.0.0 Beta 1 Release Notes](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-1.1) > 9. Internationalization**

## 4. Everything else

Beside the changes listed above, Beta 4 features many more small **bug fixes**, **tweaks**, and **quality-of-life** improvements:

### UI

#### Bug fixes

- Fixed bug where links from the About Tab would open over and over again when clicking anywhere in the window. Credits to GitHub user [DingoBits](https://github.com/DingoBits) who fixed this!
- Fixed some in-app symbols not displaying correctly on older macOS versions
- Hid scrollbars in Action Table. Thanks to GitHub user [marianmelinte93](https://github.com/marianmelinte93) who made me aware of this issue in [this comment](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366#discussioncomment-3728994)!
- Fixed issue where feedback about features being re-enabled automatically when you open the respective tab for that feature in the UI (after you disabled that respective feature from the menu bar) wasn't displayed on macOS Monterey and below. Thanks again to  [marianmelinte93](https://github.com/marianmelinte93) for making me aware of the issue.
- Added missing localizability and German translations for "Click to Scroll to Move Between Spaces" option
- Fixed more small localizability issues
- Added more missing German translations
- Notifications that display when a button is captured / no longer captured now work properly when some buttons have been captured and others have been uncaptured at the same time.

#### Improvements

- Removed "Click and Scroll for App Switcher" option. It was a bit buggy and I don't think it was very useful.
- Added in "Click and Scroll to Rotate" option.
- Tweaked layout of the "Mac Mouse Fix" menu in the menu bar. 
- Added "Buy Mac Mouse Fix" button to the "Mac Mouse Fix" menu in the menu bar.
- Added a hint text below the "Show in Menu Bar" option. The goal is to make it more discoverable that the menu bar item can be used to quickly turn off or on features
- The "Thank you for buying Mac Mouse Fix" messages on the about screen can now be fully customized by localizers.
- Improved hints for localizers
- Improved UI strings around trial expiration
- Improved UI strings on the About tab
- Added bold highlights to some UI strings to improve legibility
- Added alert when clicking "Send Me an Email" link on the About tab.
- Changed sorting order of Action Table. Click and Scroll actions will now display before Click and Drag actions. This feels more natural to me because the rows of the table are now sorted by how powerful their triggers are (Click < Scroll < Drag).
- The app will now update the actively used device when interacting with the UI. This is useful because some of the UI is now based on the device you're using. (See the new "Restore defaults...") feature.
- A notification that displays which buttons have been captured / are no longer captured now displays when you start the app for the first time. 
- More improvements to notifications that display when a button has been captured / is no longer captured
- Made it impossible to accidentally enter extraneous whitespace when activating a license key

### Mouse

#### Bug fixes

- Improved scrolling simulation to properly send "fixed point deltas". This solves an issue where scrolling speed was too slow in some apps like Safari with smooth scrolling turned off.
- Fixed issue where the "Click and Drag for Mission Control & Spaces" feature would get stuck sometimes when the computer was slow
- Fixed an issue where the CPU would always be used by Mac Mouse Fix when moving the mouse after having used the "Click and Drag to Scroll & Navigate" feature

#### Improvements

- Greatly improved scroll to zoom responsivity in Chromium-based browsers like Chrome, Brave, or Edge

### Under-the hood 

#### Bug fixes

- Fixed an issue where Mac Mouse Fix wouldn't work properly after moving it to a different folder while it was enabled
- Fixed some issues with enabling Mac Mouse Fix while another instance of Mac Mouse Fix was still enabled. (This is because Apple let me change the bundle ID from "com.nuebling.mac-mouse-fixxx" which was used in Beta 3 back to the original "com.nuebling.mac-mouse-fix". Not sure why.)

#### Improvements

- This and future betas will output more detailed debugging info
- Under the hood cleanup and improvments. Removed old pre-10.13 code. Cleaned up frameworks and dependencies. The source code is now easier to work with, more future-proof.