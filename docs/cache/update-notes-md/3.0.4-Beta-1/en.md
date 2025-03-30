

Mac Mouse Fix **3.0.4 Beta 1** improves privacy, efficiency, and reliability.\
It introduces a new offline licensing system, and fixes several important bugs.

### Enhanced Privacy & Efficiency

- Introduces a new offline license validation system that minimizes internet connections.
- The app now connects to the internet only when absolutely necessary, protecting your privacy and reducing resource usage.
- The app operates completely offline during normal use when licensed.

<details>
<summary><b>Detailed Privacy Information</b></summary>
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
- Fixed a bug where keyboard shortcuts in System Settings would sometimes get deleted when using a 'Click' action defined in Mac Mouse Fix such as 'Mission Control'. 
- Fixed [a bug](https://github.com/noah-nuebling/mac-mouse-fix/issues?q=state%3Aopen%20label%3A%22%27Free%20days%20are%20over%27%20bug%22) where the app would sometimes stop working and show a notification that the 'Free days are over' to users who had already bought the app. 
    -  If you experienced this bug, I sincerely apologize for the inconvenience. You can apply for a [refund here](https://redirect.macmousefix.com/?message=&target=mmf-apply-for-refund). 



### Technical Improvements

- Implemented a new 'MFDataClass' system allowing for cleaner data modeling and human-readable configuration files.
- Built support for adding payment platforms other than Gumroad. So in the future, there might be localized checkouts, and the app might be sold to different countries!

### Dropped (Unofficial) Support for macOS 10.14 Mojave

Mac Mouse Fix 3 officially supports macOS 11 Big Sur and later. However, for users willing to accept some glitches and graphical issues, Mac Mouse Fix 3.0.3 and earlier could still be used on macOS 10.14.4 Mojave.

Mac Mouse Fix 3.0.4 drops that support and **now requires macOS 10.15 Catalina**. \
I apologize for any inconvenience caused by this. This change allowed me to implement the improved licensing system using modern Swift features. Mojave users can continue using Mac Mouse Fix [3.0.3](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3) or the [latest version of Mac Mouse Fix 2](https://redirect.macmousefix.com/?target=mmf2-latest). I hope that's a good solution for everyone. 

*Edited with excellent assistance from Claude.*

---

Also check out the previous release [**3.0.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.3).






