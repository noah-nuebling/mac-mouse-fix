# Changelog

## 0.9.1

- Fixed scrolling and zooming in certain apps like Terminal, Launchpad, and Pixelmator, by adding non-point scroll delta values to artificial scroll events.
- Made smooth scrolling slightly more responsive, by only updating certain configurations on the first of each series of consecutive scrollwheel ticks.
- Smooth scrolling now ignores all adobe apps, as well as the the alt-tab app switcher, and the app switcher replacement Contexts.app.
- Added the ability to invert scrolling direction without enabling smooth scrolling.
- Removed the ability to remap clicking and holding the middle button to 'Lookup', as this option might lead to a bad user experience.
- Removed the ability to remap to 'Launchpad' entirely, because Launchpad is already easily accessible with a mouse, and because it led to a confusing user experience when used together with with Mission Control, Application windows, or Show Desktop.
- 

## 0.9.0

- Initial release!
