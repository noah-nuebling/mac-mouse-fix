Mac Mouse Fix **2.2.4** is now notarized! It also includes some small bug fixes and other improvements.

### **Notarization**

Mac Mouse Fix 2.2.4 is now 'notarized' by Apple. That means no more messages about Mac Mouse Fix being potentially 'Malicious Software' when opening the app for the first time. 

#### Background

Notarizing your app costs $100 per year. I was always against this, since it felt hostile towards free and open source software like Mac Mouse Fix, and it also felt like a dangerous step towards Apple controlling and locking down the Mac like they do iPhones or iPads. But lack of notarization led to different problems, including [difficulties opening the app](https://github.com/noah-nuebling/mac-mouse-fix/discussions/114) and even [several situations](https://github.com/noah-nuebling/mac-mouse-fix/issues/95) where nobody could use the app anymore until I released a new version. 

For Mac Mouse Fix 3, I thought it was finally appropriate to pay the $100 per year to notarize the app, since Mac Mouse Fix 3 is monetized. ([Learn More](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0)) \
Now, Mac Mouse Fix 2 gets notarization as well, which should lead to an easier and more stable user experience.

 

### **Bug fixes**

- Fixed an issue where the cursor would disappear and then reappear in a different location when using a 'Click and Drag' Action during a screen recording or while using the [DisplayLink](https://www.synaptics.com/products/displaylink-graphics) software.  
- Fixed an issue with enabling Mac Mouse Fix under macOS 10.14 Mojave and possibly older macOS versions, too.  
- Improved memory management, potentially fixing a crash of the 'Mac Mouse Fix Helper' app, that would occur when detaching a mouse from your computer. See Discussion [#771](https://github.com/noah-nuebling/mac-mouse-fix/discussions/771).  

### **Other Improvements**

- The window that the app displays to inform you that a new version of Mac Mouse Fix is available now supports JavaScript. This allows for the update notes to be prettier and easier to read. For example, the update notes can now display [Markdown Alerts](https://github.com/orgs/community/discussions/16925) and more.
- Removed a link to the https://macmousefix.com/about/ page from the "Grant Accessibility Access to Mac Mouse Fix Helper" screen. That's because the About page no longer exists and has been replaced by the [GitHub Readme](https://github.com/noah-nuebling/mac-mouse-fix) for now.
- This release now includes dSYM files which can be used by anyone to decode crash reports of Mac Mouse Fix 2.2.4.
- Some under-the-hood cleanup and improvements.

---

Also check out the previous release [**2.2.3**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.3).