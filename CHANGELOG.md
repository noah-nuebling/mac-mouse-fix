# Changelog

## 0.9.1

- Fixed scrolling and zooming in certain apps like Terminal, Launchpad, and Pixelmator, by adding a different type of scroll delta value to the artificial scroll events.
- Made smooth scrolling slightly more responsive, by only updating display synchronization and app specific configurations on the first of each series of consecutive scrollwheel ticks.
- Smooth scrolling now ignores all adobe apps, as well as the the alt-tab app switcher, and the app switcher replacement Contexts.app.
- Added the ability to invert scrolling direction without enabling smooth scrolling.
- Removed the ability to remap clicking and holding the middle button to 'Look Up', as this option might lead to a bad user experience. Suppose clicking the middle button is mapped to Mission Control, and holding it is mapped to Look Up. After opening the Look Up menu with a long press, the user will likely expect a click of the middle button to dismiss the menu. However, this would trigger Mission Control, which is unexpected and confusing for some people (I tested this on my dad).
- Removed the ability to remap to 'Launchpad' entirely. Launchpad is already easily accessible with a mouse if you use the Dock Icon.

## 0.9.0

- Initial release!
