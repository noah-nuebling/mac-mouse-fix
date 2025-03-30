







 





 




Mac Mouse Fix **3.0.2** brings several improvements, including **smoother scrolling**, improved translations, and more!

### Scrolling

- You can now stop scroll animations by scrolling one step in the opposite direction. This allows you to **'throw'** and **'catch' the page** when using 'Smoothness: High', similar to a Trackpad.
- Mac Mouse Fix now sends scroll events earlier in the display refresh cycle, giving apps more time to process the scroll events and display scrolling smoothly. This **improves framerates**, especially on complex websites like YouTube.com.
- Improved the responsiveness of the 'Smoothness: High' setting, making scrolling easier to control. 
- Improved on a mechanism introduced in 3.0.1 where the animation speed becomes faster as you move the scroll wheel faster when using 'Smoothness: Regular'. In 3.0.2 the speedup of the animation should appear more consistent and predictable, making it easier on the eyes while providing great control. 
- Fixed a problem where the scrolling speed was too slow, especially when using the 'Precision' option. This problem was introduced in 3.0.1. Thanks to @V-Coba for drawing attention to it in [795](https://github.com/noah-nuebling/mac-mouse-fix/issues/795).
    
- Improved behaviour inside the Arc browser when using 'Click and Scroll' to 'Zoom In or Out'.

### Localization

- Updated 🇻🇳 Vietnamese translations. Credits to @nghlt! 
- Improved some 🇩🇪 German translations.
- Text inside Mac Mouse Fix that doesn't have a translation for the current language will now show a placeholder value instead of just being blank. This should make it less confusing to navigate the app when there are missing translations.

### Other

- Mac Mouse Fix will now show a notification with a link to [this guide](https://github.com/noah-nuebling/mac-mouse-fix/discussions/861) to users who might be experiencing a bug in macOS 13 Ventura and later that can prevent Mac Mouse Fix from being enabled. 
- Changed the default settings for mice with 3 buttons. The default settings no longer feature a 'Click and Scroll' action for the Scrollwheel Button, since that is pretty hard to perform. Instead, the default settings now feature a 'Hold' and a 'Double Click' action. 
- Added a tooltip to the Mac Mouse Fix icon on the About tab. It tells you how to reveal Mac Mouse Fix's config file in the Finder.
- Lots of under-the-hood cleanup and improvements.





---

Also check out the previous release [**3.0.1**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.1).

 




















