# Changelog

### 1.0.0 

- Mac Mouse Fix is now an App instead of a Preference Pane
- Updated and optimized for macOS 11 BigSur
- Added support for macOS 10.11 El Capitan
- Added compatibilty to many mice including the Logitech MX Master
- You can now swap the side buttons functions if they happen to be inverted on your mouse (Shoutouts to @divadretlaw!)
- Added Dark Mode support (Thank you @stevenguh!)
- Mac Mouse Fix will now completely uninstall itself automatically after you move it to the trash (Just make sure that 'Enable Mac Mouse Fix' is checked before you do so) 
- Mac Mouse Fix now takes even less space and is lighter on your CPU
- Keyboard modifier interception is now completely disabled when no mice are attached to your computer
- You can now zoom in and out by holding Command (⌘) while scrolling
- Updated App Icon
- You can now disable smooth scrolling for specific apps
- Added 'Look Up' and 'Launchpad' options, which were removed in 0.9.1, back in
- New and improved 'More...' screen
- Even more responsive scrolling through use of multi-threading and other techniques
- Various other bug fixes and under-the-hood improvements 

### 0.9.1

- Fixed compatiblity with Catalina by fixing a bug that would occur when setting up a message port to communicate with the Mouse Fix Helper application from within the Mouse Fix prefpane.
- Added full support for Bluetooth mice, by improving device management code.
- Fixed scrolling and zooming in certain apps like Terminal, Launchpad, and Pixelmator, by adding a different type of scroll delta value to the artificial scroll events.
- Made smooth scrolling slightly more responsive by only updating display synchronization and app specific configurations on the first of each series of consecutive scrollwheel ticks.
- Smooth scrolling now ignores all adobe apps.
- Added the ability to invert scrolling direction without enabling smooth scrolling.
- Removed the ability to remap to 'Launchpad' entirely. Sorry to everyone who used that feature. Please check out the excellent [Steer Mouse](http://plentycom.jp/en/steermouse/) to replicate this functionality. Other great alternatives are USBOverdrive, BetterTouchTool or ControllerMate.
    - My reasoning behind this is that the Launchpad option was not really compatible with any of the other options for the Middle Button. Suppose that clicking the Middle Button is mapped to Mission Control, and holding it is mapped to Launchpad. After opening Launchpad with a long press, the user will likely expect a click of the Middle Button to dismiss Launchpad, but instead, it will immediately switch to Mission Control, which is unexpected and confusing for some people (I tested this on my dad). I might add Launchpad back in, if I find a solution for this Problem. In the meantime, please consider one of the alternatives mentioned above.
- Removed the ability to remap clicking and holding the middle button to 'Look Up', as this option might lead to a bad user experience. The problems with this option were similar to the problems with the Launchpad option described above. 


### 0.9.0

- Initial release!
