# Changelog

## 0.9.1

- Fixed compatiblity with Catalina by fixing a Bug that would occur when setting up a message port to communicate with the Mouse Fix Helper application from within the Mouse Fix prefpane.
- Added full support for Bluetooth Mice, by changing some device management code.
- Fixed scrolling and zooming in certain apps like Terminal, Launchpad, and Pixelmator, by adding a different type of scroll delta value to the artificial scroll events.
- Made smooth scrolling slightly more responsive, by only updating display synchronization and app specific configurations on the first of each series of consecutive scrollwheel ticks.
- Smooth scrolling now ignores all adobe apps.
- Added the ability to invert scrolling direction without enabling smooth scrolling.
- Removed the ability to remap to 'Launchpad' entirely. Sorry to everyone who used that feature. My reasoning behind this is that it's not really compatible with any of the other options for the Middle Button. Suppose that clicking the Middle Button is mapped to Mission Control, and holding it is mapped to Launchpad. After opening Launchpad with a long press, the user will likely expect a click of the Middle Button to dismiss Launchpad. Instead, it will trigger Mission Control, which is unexpected and confusing for some people (I tested this on my dad). Please consider using the Launchpad Dock icon to easily access Launchpad from your mouse, or use the excellent .

, the second reason is that Launchpad is already easily accessible with a mouse if you use the Dock Icon.
- Removed the ability to remap clicking and holding the middle button to 'Look Up', as this option might lead to a bad user experience. Suppose clicking the middle button is mapped to Mission Control, and holding it is mapped to Look Up. After opening the Look Up menu with a long press, the user will likely expect a click of the middle button to dismiss the menu. However, this would trigger Mission Control, which is unexpected and confusing for some people (I tested this on my dad).


## 0.9.0

- Initial release!
