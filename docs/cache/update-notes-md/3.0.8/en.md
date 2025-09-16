Mac Mouse Fix **3.0.8** solves UI issues and more.

### **UI Issues**

- Disabled the new design on macOS 26 Tahoe. Now the app will look and function like it did on macOS 15 Sequoia. 
    - I did this because some of Apple's redesigned UI elements still have issues. For example, the '-' buttons on the 'Buttons' tab weren't always clickable.
    - The UI may look a little outdated on macOS 26 Tahoe now. But it should be fully functional and polished just like before.
- Fixed a bug where the 'Free days are over' notification would get stuck in the top-right screen corner.
    - Thanks to [Sashpuri](https://github.com/Sashpuri) and others for reporting it!

### **UI Polish**

- Disabled the green traffic light button in the main Mac Mouse Fix window.
    - The button didn't do anything, since the window cannot be resized manually.
- Fixed an issue where some of the horizontal lines in the table on the 'Buttons' tab were too dark under macOS 26 Tahoe.
- Fixed a bug where the "Primary Mouse Button can't be used" message on the 'Buttons' tab would sometimes be cut off under macOS 26 Tahoe.
- Fixed a typo in the German interface. Courtesy of GitHub user [i-am-the-slime](https://github.com/i-am-the-slime). Thanks!
- Solved an issue where the MMF window would sometimes briefly flash at the wrong size when opening the window on macOS 26 Tahoe.

### **Other Changes**

- Improved behavior when trying to enable Mac Mouse Fix while multiple instances of Mac Mouse Fix are running on the computer. 
    - Mac Mouse Fix will now try to disable the other instance of Mac Mouse Fix more diligently. 
    - This may improve edge cases where Mac Mouse Fix could not be enabled.
- Under-the-hood changes and cleanup.

---

Also check out what's new in the previous version [3.0.7](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.7).

