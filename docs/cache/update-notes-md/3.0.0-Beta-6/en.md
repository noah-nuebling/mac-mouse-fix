Also check out the **neat changes** introduced in [3.0.0 Beta 5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0-Beta-5)!


---

**3.0.0 Beta 6** brings deep optimizations and polish, a rework of the scroll settings, Chinese translations, and more!

Here's everything new:

## 1. Deep Optimizations

For this Beta, I put a lot of work into getting the last bit of performance out of Mac Mouse Fix. And now I'm happy to announce that, when you click a mouse button in Beta 6, that's **2x** faster compared to the previous beta! And scrolling is even **4x** faster!

With Beta 6, MMF will also smartly turn parts of itself off to save your CPU and battery as much as possible. 

For example, when you're currently using a mouse with 3 buttons but you only have actions set up for buttons not found on your mouse like buttons 4 and 5, Mac Mouse Fix will stop listening to button input from your mouse entirely. Meaning 0% CPU usage when you click a button on your mouse! Or when the scroll settings in MMF match the system, Mac Mouse Fix will stop listening to input from your scroll wheel entirely. Meaning 0% CPU usage when you scroll! But if you set up the Command (⌘)-Scroll to Zoom feature, Mac Mouse Fix will start to listen to your scroll wheel input - but only while you hold down the Command (⌘) key. And so on.
So it's really smart and will only use up CPU when it has to!

This means, MMF is now not only the most powerful, easy-to-use, and polished mouse driver for Mac, it's also one of, if not the, most optimized and efficient!

## 2. Reduced App Size

At 16 MB, Beta 6 is ca. 2x smaller than Beta 5!

This is a side-effect of dropping support for older macOS versions. 

## 3. Dropped Support for Older macOS Versions

I tried hard to get MMF 3 to run properly on macOS versions before macOS 11 Big Sur. But the amount of work to get it to feel polished turned out to be overwhelming, so I had to give up on that. 

Moving forward, the earliest officially supported version will be macOS 11 Big Sur. 

The app will still open on older versions but there will be visual and maybe other problems. The app will not open anymore on macOS versions before 10.14.4. This is what allows us to shrink the app size by 2x since 10.14.4 is the earliest macOS version shipping with modern Swift libraries (See "Swift ABI Stability"), which means those Swift libraries don't have to be contained in the app anymore.

## 4. Scroll Improvements

Beta 6 features many improvements to the configuration and the UI of the new scrolling systems introduced in MMF 3.

### UI

- Greatly simplified and shortened the UI text on the Scroll tab. Most mentions of the word "Scroll" have been removed since it's implied by context.
- Reworked the scroll smoothness settings to be much clearer and allow for some additional options. Now you can pick between a "Smoothness" of "Off", "Regular", or "High", Replacing the old "with Inertia" toggle. I think this is much clearer and it made space in the UI for the new "Trackpad Simulation" option.
- Turning off the new "Trackpad Simulation" option disables the rubber band effect while scrolling, it also prevents scrolling between pages in Safari and other apps, and more. Lots of people have been annoyed by this, especially those with free-spinning scroll wheels as found on some Logitech Mice like the MX Master, but others enjoy it, so I decided to make it an option. I hope the presentation of the feature is clear. If you have any suggestions there, let me know.
- Changed the "Natural Scroll Direction" option to "Reverse Scroll Direction". This means the setting now reverses the system scroll direction and is no longer independent of the system scroll direction. While this is arguably a slightly worse user experience, this new way of doing things allows us to implement some optimizations and it makes it more transparent to the user how to completely turn Mac Mouse Fix off for scrolling.
- Improved the way that the scroll settings interact with modified scrolling in many different edge cases. E.g. the "Precision" option will no longer apply to the "Click and Scroll" for "Desktop & Launchpad" action since it's a hindrance here instead of being helpful.
- Improved scroll speed when using "Click and Scroll" for "Desktop & Launchpad" or "Zoom In or Out" and other features.
- Removed non-functioning link to the system scroll speed settings on the scroll tab which was present on macOS versions before macOS 13.0 Ventura. I couldn't find a way to make the link work and it's not terribly important.

### Scroll Feel

- Improved animation curve for "Regular Smoothness" (formerly accessible by turning "with Inertia" off). This makes things feel more smooth and responsive.
- Improved the feel of all the scroll speed settings. The "Medium" speed and the "Fast" speed are faster. There is more separation between "Low" "Medium" and "High" speeds. The speedup as you move the scrollwheel faster feels more natural and comfortable when using the "Precision" option. 
- The way that the scrolling speed ramps up as you keep scrolling in one direction will feel more natural and gradual. I'm using new mathematical curves to model the speedup. The speed ramp-up will also be harder to trigger accidentally. 
- Not ramping up scrolling speed anymore when you keep scrolling in one direction while using the "macOS" scrolling speed.
- Restricted the scroll animation time to a maximum. If the scroll animation would naturally take more time it will be sped up to stay below the maximum time. That way, scrolling into the page edge with a free-spinning wheel will not have the page content move off-screen for as long. This shouldn't affect normal scrolling with a non-free-spinning wheel.
- Improved some interactions around the rubberband effect when scrolling into a page edge in Safari and other apps.
- Fixed an issue where "Click and Scroll" and other scroll-related features wouldn't work properly after upgrading from a very old preference pane version of Mac Mouse Fix.
- Fixed an issue where single-pixel scrolls were sent with a delay when using the "macOS" scrolling speed together with smooth scrolling.
- Fixed a bug where scrolling would still be really fast after releasing the Swift Scroll modifier. Other improvements around how scroll speed is carried over from previous scroll swipes.
- Improved the way that the scroll speed increases with larger display sizes

## 5. Notarization

Starting with 3.0.0 Beta 6, Mac Mouse Fix will be "Notarized". That means no more messages about Mac Mouse Fix being potentially "Malicious Software" when opening the app for the first time.

Notarizing your app costs $100 per year. I was always against this, since it felt hostile towards free and open source software like Mac Mouse Fix, and it also felt like a dangerous step towards Apple controlling and locking down the Mac like they do iOS. But lack of Notarization led to pretty severe problems, including [several situations](https://github.com/noah-nuebling/mac-mouse-fix/discussions/114) where nobody could use the app anymore until I released a new version. Since Mac Mouse Fix will be monetized now, I thought it was finally appropriate to Notarize the app for an easier and more stable user experience. 

## 6. Chinese Translations

Mac Mouse Fix is now available in Chinese! 
More specifically, it's available in:

- Chinese, Traditional
- Chinese, Simplified
- Chinese (Hong Kong)

Huge thanks to @groverlynn for providing all of these translations as well as for updating them throughout the betas and communicating with me. See his pull request here: https://github.com/noah-nuebling/mac-mouse-fix/pull/395.

## 7. Everything Else

Aside from the changes listed above Beta 6 also features many smaller improvements.

- Removed several options from the "Click", "Click and Hold" and "Click and Scroll" Actions because I thought they were redundant since the same functionality can be achieved otherwise and since this cleans up the menus a lot. Will bring those options back if people complain. So if you miss those options - please complain.
- Click and Drag direction will now match trackpad swipe direction even when "Natural scrolling" is turned off under System Settings > Trackpad. Before, Click and Drag would always behave like swiping on the trackpad with "Natural scrolling" turned *on*. 
- Fixed an issue where the cursors would disappear and then reappear somewhere else when using a "Click and Drag" Action during a screen recording or when using the DisplayLink software.
- Fixed centering of the "+" in the "+"-Field on the Buttons tab
- Several visual Improvements to the buttons tab. The color palette of the "+"-Field and Action Table has been reworked to look correct when using macOS' "Allow wallpaper tinting in windows" option. The borders of the Action Table now have a transparent color that looks more dynamic and adjusts to its surroundings.
- Made it so when you add lots of actions to the action table and the Mac Mouse Fix window grows, it will grow exactly as large as the screen (or as the screen minus the dock if you don't have dock-hiding enabled) and then stop. When you add even more actions, the action table will start scrolling.
- This Beta now supports a new checkout where you can buy a license in US dollars as advertised. Before you could only buy a license in Euros. The old Euro licenses will still be supported of course.
- Fixed an issue where momentum scrolling sometimes wasn't started when using the "Scroll & Navigate" feature.
- When the Mac Mouse Fix window resizes itself during a tab switch it will now reposition itself so it does not overlap with the Dock
- Fixed flicker on some UI elements when switching from the Buttons tab to another tab
- Improved appearance of animation that the "+"-Field plays after recording an input. Especially on macOS versions before Ventura, where the shadow of the "+"-Field would appear glitched during the animation.
- Disabled notifications listing several buttons that have been captured/are no longer captured by Mac Mouse Fix which would appear when starting the app for the first time or when loading a preset. I thought these messages were distracting and slightly overwhelming and not really helpful and those contexts. 
- Reworked the Grant Accessibility Screen. It will now show information about why Mac Mouse Fix needs Accessibility Access inline instead of linking to the website and it is a little clearer and has a more visually pleasing layout.
- Updated Acknowledgements link on the About tab.
- Improved error messages when Mac Mouse Fix can't be enabled because there's another version present on the system. The message will now be displayed in a floating alert window which always stays on top of other windows until dismissed instead of a Toast Notification which disappears when clicking anywhere. This should make it easier to follow the suggested solution steps.
- Fixed some issues with markdown rendering on macOS versions before Ventura. MMF will now use a custom markdown rendering solution for all macOS Versions, including Ventura. Before we were using a system API introduced in Ventura but that lead to inconsistencies. Markdown is used to add links and emphasis to text across the UI.
- Polished the interactions around enabling accessibility access. 
- Fixed an issue where the app window would sometimes open without showing any content until you switched to one of the tabs.
- Fixed an issue with the "+"-Field where you sometimes couldn't add a new action even though it showed a hover effect indicating that you can enter an action.
- Fixed a deadlock and several other small issues that would sometimes happen when moving the mouse pointer inside the "+"-Field
- Fixed an issue where a popover that appears on the Buttons tab when your mouse doesn't seem to fit the current button settings would sometimes have all bold text.
- Updated all mentions of the old MIT license to the new MMF license. New files created for the project will now contain an autogenerated header mentioning the MMF license.
- Made switching to the Buttons tab enable MMF for Scrolling. Otherwise, you couldn't record Click and Scroll gestures.
- Fixed some issues where button names were not displaying correctly in Action Table in some situations.
- Fixed bug where the trial section on the About screen would look buggy when opening the app and then switching to the trial tab after the trial expired.
- Fixed a bug where Activate License link in the trial section of the About Tab sometimes didn't react to clicks.
- Fixed a memory leak when using the "Click and Drag" for "Spaces & Mission Control" feature.
- Enabled Hardened runtime on the main Mac Mouse Fix app, improving security
- Lots of code cleanup, project restructuring
- Several other crashes fixed
- Several memory leaks fixed
- Various small UI string tweaks
- Reworks of several internal systems also improved robustness and behavior in edge cases

## 8. How You Can Help

You can help by sharing your **ideas**, **issues** and **feedback**!

The best place to share your **ideas** and **issues** is the [Feedback Assistant](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report).
The best place to give **quick** unstructured feedback is the [Feedback Discussion](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366).

You can also access these places from within the app on the "**ⓘ About**" tab.

**Thanks** for helping to make Mac Mouse Fix the best it can be! 🙌:)