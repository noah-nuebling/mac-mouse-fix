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

Mac Mouse Fix **3.0.4** improves privacy, efficiency, and reliability.\
It introduces a new offline licensing system, and fixes several important bugs.

### Enhanced Privacy & Efficiency

3.0.4 introduces a new offline license validation system that minimizes internet connections as much as possible.
This improves privacy and saves your computer's system resources.
When licensed, the app now operates 100% offline!

<details>
<summary><b>Click here for more details</b></summary>
Previous versions validated licenses online at every launch, potentially allowing connection logs to be stored by third-party servers (GitHub and Gumroad). The new system eliminates unnecessary connections – after the initial license activation, it only connects to the internet if local license data is corrupted.
<br><br>
While no user behavior was ever recorded by me personally, the previous system theoretically allowed third-party servers to log IP addresses and connection times. Gumroad could also log your license key and potentially correlate it to any personal info they recorded about you when you bought Mac Mouse Fix. 
<br><br>
I didn't consider these subtle privacy issues when I built the original licensing system, but now, Mac Mouse Fix is as private and internet-free as possible!
<br><br>
Also see <a href=https://gumroad.com/privacy>Gumroad's privacy policy</a> and this <a href=https://github.com/noah-nuebling/mac-mouse-fix/issues/976#issuecomment-2140955801>GitHub comment</a> of mine.

</details>

### Bug Fixes

- Fixed a bug where macOS would sometimes get stuck when using 'Click and Drag' for 'Spaces & Mission Control'. 
- Fixed a bug where keyboard shortcuts in System Settings would sometimes get deleted when using Mac Mouse Fix 'Click' actions such as 'Mission Control'. 
- Fixed [a bug](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aopen%20label%3A%22%27Free%20days%20are%20over%27%20bug%22) where the app would sometimes stop working and show a notification that the 'Free days are over' to users who had already bought the app. 
    -  If you experienced this bug, I sincerely apologize for the inconvenience. You can apply for a [refund here](https://redirect.macmousefix.com/?message=&target=mmf-apply-for-refund). 
- Made it impossible to enter spaces and linebreaks in the text field on the 'Activate License' screen. 
    - This was a common point of confusion, because it is very easy to accidentally select a hidden linebreak when copying your license key from Gumroad's emails.  
- Improved the way the application retrieves its main window, which may have fixed a bug where the 'Activate License' screen sometimes fails to appear. 

### Dropped (Unofficial) Support for macOS 10.14 Mojave

Mac Mouse Fix 3 officially supports macOS 11 Big Sur and later. However, for users willing to accept some glitches and graphical issues, Mac Mouse Fix 3.0.3 and earlier could still be used on macOS 10.14.4 Mojave.

Mac Mouse Fix 3.0.4 drops that support and **now requires macOS 10.15 Catalina**. \
I apologize for any inconvenience caused by this. This change allowed me to implement the improved licensing system using modern Swift features. Mojave users can continue using Mac Mouse Fix [3.0.3](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3) or the [latest version of Mac Mouse Fix 2](https://redirect.macmousefix.com/?target=mmf2-latest). I hope that's a good solution for everyone. 

### Under-the-hood Improvements

- Implemented a new 'MFDataClass' system allowing for more powerful data modeling while keeping Mac Mouse Fix's config file human-readable and human-editable.
- Built support for adding payment platforms other than Gumroad. So in the future, there might be localized checkouts, and the app could be sold to different countries.
- Improved logging which allows me to create more effective "Debug Builds" for users who experience hard-to-reproduce bugs. 
- Many other small improvements and cleanup work.

*Edited with excellent assistance from Claude.*

---

Also check out the previous release [**3.0.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3).



