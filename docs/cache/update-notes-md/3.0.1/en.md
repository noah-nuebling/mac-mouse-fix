Mac Mouse Fix **3.0.1** brings several bug fixes and improvements, along with a **new language**!

### Vietnamese was added!

Mac Mouse Fix is now available in 🇻🇳 Vietnamese. Big thanks to @nghlt [on GitHub](https://GitHub.com/nghlt)!


### Bug fixes

- Mac Mouse Fix now works properly with **Fast User Switching**!
  - Fast User Switching is when you log into a second macOS account without logging out of the first account. 
  - Before this update, scrolling stopped working after a fast user switch. Now everything should work correctly.
- Fixed a small bug where the layout of the Buttons tab was too wide after starting Mac Mouse Fix for the first time. 
- Made the '+' field work more reliably when adding several Actions in quick succession. 
- Fixed an obscure crash reported by @V-Coba in Issue [735](https://github.com/noah-nuebling/mac-mouse-fix/issues/735).

### Other improvements

- **Scrolling feels more responsive** when using the 'Smoothness: Regular' setting.
  - The animation speed now becomes faster as you move the scroll wheel faster. That way, it feels more responsive when you scroll fast while feeling just as smooth when you scroll slowly.
  
- Made the **scroll speed acceleration** more stable and predictable. 
- Implemented a mechanism to **keep your settings** when you update to a new Mac Mouse Fix version.
  - Before, Mac Mouse Fix would reset all your settings after updating to a new version, if the structure of the settings changed. Now, Mac Mouse Fix will attempt to upgrade the structure of your settings and keep your preferences. 
  - So far, this only works, when updating from 3.0.0 to 3.0.1. If you're updating from an older version than 3.0.0, or if you _downgrade_ from 3.0.1 _to_ a previous version, your settings will still be reset. 
- The layout of the Buttons tab now better adapts its width to different languages. 
- Improvements to the [GitHub Readme](https://github.com/noah-nuebling/mac-mouse-fix#background) and other documents.
- Improved localization systems. The translation files are now automatically cleaned up and analyzed for potential issues. There's a new [Localization Guide](https://github.com/noah-nuebling/mac-mouse-fix/discussions/731) which features any automatically detected issues along with other useful info and instructions for people who want to help translate Mac Mouse Fix. Removed dependency on the [BartyCrouch](https://github.com/FlineDev/BartyCrouch) tool which was previously used to get some of this functionality.
- Improved several UI strings in English and German.
- Lots of under-the-hood cleanup and improvements.

---

Also check out the release notes for [**3.0.0**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.0.0) - the biggest update to Mac Mouse Fix so far!