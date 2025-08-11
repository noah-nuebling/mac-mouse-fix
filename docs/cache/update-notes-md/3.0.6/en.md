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

Mac Mouse Fix **3.0.6** makes the 'Back' and 'Forward' feature compatible with more apps.
It also addresses several bugs and issues.

### Improved 'Back' and 'Forward' Compatibility

The 'Back' and 'Forward' mouse button mappings now **work in more apps**, including:

- Visual Studio Code, Cursor, VSCodium, Windsurf, Zed, and other code editors
- Many built-in Apple apps such as Preview, Notes, System Settings, App Store, Music, TV, Books, and Freeform
- Adobe Acrobat
- Zotero
- And more!

The implementation is inspired by the great 'Universal Back and Forward' feature in [LinearMouse](https://github.com/linearmouse/linearmouse). It should support all apps that LinearMouse does. \
Furthermore it supports some apps that normally require keyboard shortcuts to go back and forward, such as System Settings, App Store, Apple Notes, and Adobe Acrobat. Mac Mouse Fix will now detect those apps and simulate the appropriate keyboard shortcuts.

Every app that's ever been [requested in a GitHub Issue](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aclosed%20label%3A%22Universal%20Back%20and%20Forward%22) should be supported now! (Thanks for the feedback!)
If you find any apps that don't work, yet, let me know in a [feature request](http://redirect.macmousefix.com/?target=mmf-feedback-feature-request).



### Addressing the 'Scroll Stops Working Intermittently' Bug

Some users experienced an [issue](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue%20state%3Aclosed%20stops%20working%20label%3A%22Scroll%20Stops%20Working%20Intermittently%22) where **smooth scrolling stops working** at random.

While I've never been able to reproduce the issue, I've implemented a potential fix:

The app will now retry multiple times when setting up display-synchronization fails. \
If it still doesn't work after retrying, the app will:

- Restart the 'Mac Mouse Fix Helper' background process, which may resolve the issue
- Produce a crash report, which may help diagnosing the bug

I hope the problem is finally fixed now! If not, let me know in a [bug report](http://redirect.macmousefix.com/?target=mmf-feedback-bug-report) or via [email](http://redirect.macmousefix.com/?target=mailto-noah).



### Improved Free-Spinning Scroll Wheel Behavior

Mac Mouse Fix will **no longer speed-up scrolling for you**, when you let the scroll wheel spin freely on the MX Master mouse. (Or any other mouse with a free-spinning scroll wheel.)

While this 'scroll speedup' feature is useful on regular scroll wheels, on a free-spinning scroll wheel it can make things harder to control.

**Note:** Mac Mouse Fix is currently not fully compatible with most Logitech mice, including the MX Master. I plan to add full support, but it will probably take a while. In the meantime, the best third-party driver with Logitech support that I know is [SteerMouse](https://plentycom.jp/en/steermouse/).





### Bug Fixes

- Fixed an issue where Mac Mouse Fix would sometimes re-enable keyboard shortcuts that were previously disabled in System Settings  
- Fixed a crash when clicking 'Activate License' 
- Fixed a crash when clicking 'Cancel' right after clicking 'Activate License' (Thanks for the report, Ali!)
- Fixed crashes when attempting to use Mac Mouse Fix while no display is attached to your Mac 
- Fixed a memory leak and some other under-the-hood issues when switching between tabs in the app 

### Visual Enhancements

- Fixed an issue where the About tab was sometimes too tall, which was introduced in [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5)
- Text on the 'Free days are over' notification is no longer cut off in Chinese
- Fixed a visual glitch on the '+' field's shadow after recording an input
- Fixed a rare glitch where the placeholder text on the 'Enter Your License Key' screen would appear off-center
- Disabled Touch Bar text completion on the 'Enter Your License Key' screen 
- Fixed an issue where some symbols displayed in the app  had the wrong color after switching between dark/light mode

### Other Improvements

- Made some animations, such as the tab-switch animation, slightly more efficient  
- Various smaller under-the-hood improvements

*Edited with excellent assistance by Claude.*

---

Also check out the previous release [3.0.5](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.5)

