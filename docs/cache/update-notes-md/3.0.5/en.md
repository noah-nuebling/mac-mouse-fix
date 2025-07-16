**ℹ️ Note to Mac Mouse Fix 2 Users**

 With the introduction of Mac Mouse Fix 3, the pricing model of the app has changed:
 
 - **Mac Mouse Fix 2**\
 Remains 100% free, and I plan to keep supporting it.\
**Skip this update** to keep using Mac Mouse Fix 2. Download the latest version of Mac Mouse Fix 2 [here](https://redirect.macmousefix.com/?target=mmf2-latest).
 - **Mac Mouse Fix 3**\
 Free for 30 days, costs a few dollars to own.\
 **Update now** to get Mac Mouse Fix 3!

You can learn more about the pricing and features of Mac Mouse Fix 3 on the [new website](https://macmousefix.com/).

Thanks for using Mac Mouse Fix! :)

---

**ℹ️ Note to Mac Mouse Fix 3 Buyers**

If you accidentally updated to Mac Mouse Fix 3 without knowing that it's not free anymore, I'd like to offer you a [refund](https://redirect.macmousefix.com/?target=mmf-apply-for-refund).

The latest version of Mac Mouse Fix 2 stays **entirely free**, and you can download it [here](https://redirect.macmousefix.com/?target=mmf2-latest).

I'm sorry for the hassle, and I hope everyone is ok with this as a solution!

---

Mac Mouse Fix **3.0.5** fixes several bugs, improves performance, and adds a bit of polish to the app. \
It's also compatible with macOS 26 Tahoe.

### Improved Simulation of Trackpad Scrolling

- The scrolling system can now simulate a two-finger tap on the trackpad to make applications stop scrolling.
    - This fixes an issue when running iPhone or iPad apps, where scrolling would often keep going after the user chose to stop.
- Fixed inconsistent simulation of lifting fingers off the trackpad.
    - This may have caused suboptimal behavior in some situations.



### macOS 26 Tahoe Compatibility

When running the macOS 26 Tahoe Beta, the app is now usable, and most of the UI works correctly.



### Performance Enhancement

Improved performance of the Click and Drag to "Scroll & Navigate" gesture. \
In my testing, CPU usage has been reduced by ~50%!

**Background**

During the "Scroll & Navigate" gesture, Mac Mouse Fix draws a fake mouse cursor in a transparent window, while locking the real mouse cursor in place. This ensures that you can keep scrolling the UI element that you started scrolling on, no matter how far you move your mouse. \

The improved performance was achieved by turning off the default macOS event handling on this transparent window, which wasn't used anyway.





### Bug Fixes

- Now ignoring scroll events from Wacom drawing tablets.
    - Before, Mac Mouse Fix was causing erratic scrolling on Wacom tablets, as reported by @frenchie1980 in GitHub Issue [#1233](https://github.com/noah-nuebling/mac-mouse-fix/issues/1233). (Thanks!)
    
- Fixed a bug where the Swift Concurrency code, which was introduced as part of the new licensing system in Mac Mouse Fix 3.0.4, didn't run on the correct thread.
    - This caused crashes on macOS Tahoe, and it also likely caused other sporadic bugs around licensing.
- Improved robustness of the code that decodes offline licenses.
    - This works around an issue in Apple's APIs that caused offline license validation to always fail on my Intel Mac Mini. I assume that this happened on all Intel Macs, and that it was the reason why the "Free days are over" bug (which was already addressed in 3.0.4) still occurred for some people, as reported by @toni20k5267 in GitHub Issue [#1356](https://github.com/noah-nuebling/mac-mouse-fix/issues/1356). (Thank you!)
     
     

### UX Improvements

- Disabled dialogs that provided step-by-step solutions for macOS bugs that prevented users from enabling Mac Mouse Fix.
    - These issues only occurred on macOS 13 Ventura and 14 Sonoma. Now, these dialogs only appear on those macOS versions where they are relevant. 
    - The dialogs are also a bit harder to trigger – before, they sometimes showed up in situations where they weren't very helpful.
    
- Added an "Activate License" link directly on the "Free days are over" notification. 
    - This makes activating a Mac Mouse Fix license even more nice and easy.

### Visual Enhancements

- Slightly improved the look of the "Software Update" window. Now it fits better with macOS 26 Tahoe. 
    - This was done by customizing the default look of the "Sparkle 1.27.3" framework which Mac Mouse Fix uses to handle updates.
- Fixed issue where the text at the bottom of the About tab was sometimes cut off in Chinese, by making the window slightly wider.
- Fixed centering of the text at the bottom of the About tab.
- Fixed a bug that caused the space under the "Keyboard Shortcut..." option on the Buttons tab to be too small. 

### Under-The-Hood Changes

- Removed dependency on the "SnapKit" framework
    - This slightly lowers the size of the app from 19.8 to 19.5 MB
- Various other small improvements in the codebase.

*Edited with excellent assistance from Claude.*

---

Also check out the previous release [**3.0.4**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.4).