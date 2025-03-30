Mac Mouse Fix **2.2.1** provides full **support for macOS Ventura** among other changes.

### Ventura support!
Mac Mouse Fix now fully supports and feels native to macOS 13 Ventura.
Special thanks to [@chamburr](https://github.com/chamburr) who helped with Ventura support in GitHub Issue [#297](https://github.com/noah-nuebling/mac-mouse-fix/issues/297).

Changes include:

- Updated the UI for granting Accessibility Access to reflect the new Ventura System Settings
- Mac Mouse Fix will be displayed properly under Ventura's new **System Settings > Login Items** menu
- Mac Mouse Fix will react properly when it's disabled under **System Settings > Login Items**

### Dropped support for older macOS versions

Unfortunately, Apple only lets you develop _for_ macOS 10.13 **High Sierra and later** when developing _from_ macOS 13 Ventura. 

So the **minimum supported version** has increased from 10.11 El Capitan to 10.13 High Sierra.

### Bug fixes

- Fixed an issue where Mac Mouse Fix changes the scrolling behaviour of some **drawing tablets**. See GitHub Issue [#249](https://github.com/noah-nuebling/mac-mouse-fix/issues/249).
- Fixed an issue where **keyboard shortcuts** including the 'A' key couldn't be recorded. Fixes GitHub Issue [#275](https://github.com/noah-nuebling/mac-mouse-fix/issues/275).
- Fixed an issue where some **button remappings** wouldn't work properly when using a non-standard keyboard layout.
- Fixed a crash in '**App-specific settings**' when trying to add an app without a 'Bundle ID'. Might help with GitHub Issue [#289](https://github.com/noah-nuebling/mac-mouse-fix/issues/289).
- Fixed a crash when trying to add apps which don't have a name to '**App-Specific settings**'. Resolves GitHub Issue [#241](https://github.com/noah-nuebling/mac-mouse-fix/issues/241). Special thanks to [jeongtae](https://github.com/jeongtae) who was very helpful in figuring out the problem!
- More small bug fixes and under-the-hood improvements.