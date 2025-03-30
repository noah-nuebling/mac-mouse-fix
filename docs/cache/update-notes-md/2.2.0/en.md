Also check out the **cool stuff** introduced in [Mac Mouse Fix 2](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.0.0)!

---

Mac Mouse Fix **2.2.0** features various usability improvements and bug fixes!

### Remapping to Apple-Exclusive function keys is better now

The last update, 2.1.0, introduced a cool new feature that lets you remap your mouse buttons to any key on your keyboard - even function keys that are only found on Apple keyboards. 2.2.0 features further improvements and refinements to that feature:

- You can now hold Option (⌥) to remap to keys that are only found on Apple keyboards - even if you don't have an Apple keyboard at hand.
- The function key symbols feature an improved appearance, making them fit in better with other text.
- The ability to remap to Caps Lock has been disabled. It did not work as expected.

### Add / remove Actions more easily

Some users had trouble figuring out that you can add and remove Actions from the Action Table. To make things easier to understand, 2.2.0 features the following changes and new features:

- You can now delete Actions by right-clicking them. 
  - This should make it easier to discover the option to delete Actions.
  - The right-click menu features a symbol of the '-' button. This should help draw attention to the '-' _button_, which should then draw attention to the '+' button. This hopefully makes the option to **add** Actions more discoverable as well.
- You can now add Actions to the Action Table by right-clicking an empty row.
- The '-' button is now only active when an Action is selected. This should make it clearer that the '-' button deletes the selected Action.
- The default window height has been increased so that there's a visible empty row which can be right-clicked to add and Action.
- The '+' and '-' buttons have tooltips now.

### Click and Drag improvements

The threshold for activating Click and Drag has been increased from 5 pixels to 7 pixels. This makes it harder to accidentally activate Click and Drag, while still letting users switch Spaces etc. by using small, comfortable flicks.


### Other UI changes

- The appearance of the Action Table has been improved.
- Various other UI enhancements.


### Bug fixes

- Fixed an issue where the UI wasn't greyed out when starting MMF while it was disabled.
- Removed hidden "Button 3 Click and Drag" option. 
  - When selecting it, the app would crash. I built this option to make Mac Mouse Fix better compatible with Blender. But in its current form, it is not very useful for Blender users because you can’t combine it with keyboard modifiers. I plan to improve Blender compatibility in a future release.