# Changelog

## 0.9.1

- Fixed compatiblity with Catalina by fixing a bug that would occur when setting up a message port to communicate with the Mouse Fix Helper application from within the Mouse Fix prefpane.
- Added full support for Bluetooth mice, by improving device management code.
- Fixed scrolling and zooming in certain apps like Terminal, Launchpad, and Pixelmator, by adding a different type of scroll delta value to the artificial scroll events.
- Made smooth scrolling slightly more responsive by only updating display synchronization and app specific configurations on the first of each series of consecutive scrollwheel ticks.
- Smooth scrolling now ignores all adobe apps.
- Added the ability to invert scrolling direction without enabling smooth scrolling.
- Removed the ability to remap to 'Launchpad' entirely. Sorry to everyone who used that feature. Please check out the excellent [Steer Mouse](http://plentycom.jp/en/steermouse/) to replicate this functionality. Other great alternatives are USBOverdrive, BetterTouchTool or ControllerMate.
    - My reasoning behind this is that the Launchpad option was not really compatible with any of the other options for the Middle Button. Suppose that clicking the Middle Button is mapped to Mission Control, and holding it is mapped to Launchpad. After opening Launchpad with a long press, the user will likely expect a click of the Middle Button to dismiss Launchpad, but instead, it will immediately switch to Mission Control, which is unexpected and confusing for some people (I tested this on my dad). I might add Launchpad back in, if I find a solution for this Problem. In the meantime, please consider one of the alternatives mentioned above.
- Removed the ability to remap clicking and holding the middle button to 'Look Up', as this option might lead to a bad user experience. The problems with this option were similar to the problems with the Launchpad option described above. 


## 0.9.0

- Initial release!
