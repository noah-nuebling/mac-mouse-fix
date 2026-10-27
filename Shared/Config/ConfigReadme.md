#  Notes on config

- When you copy over a real `config.plist` to `default_config.plist`, make sure to reset the `State` values
- `Remaps` in `default_config.plist` should be empty.
    - It will be programmatically replaced with one of the `defaultRemaps`
- `AppExclusions` is optional and isn't in `default_config.plist` (so adding it didn't require a configVersion bump). It's an array of dicts with the keys `identifier` (bundleID, or executable path for apps without a bundleID), `name`, `path`, `disableSmoothScrolling`, `disableReverseDirection`, `disableScrollModifiers`, `disableButtons`.
    - Edited by `AppsTabController.swift`, applied by `AppExclusions.m`


## Version Changes

Here, we document, what exactly changed as we increased the configVersion

**21 -> 22**

- "License.trial.lastUseDate" is now stored in `SecureStorage` instead of config. 
    - This is to prevent bug where trial counter would go up too fast when the user switched between machines frequently (I think it resolves this) (See https://github.com/noah-nuebling/mac-mouse-fix/discussions/743#discussioncomment-8050398)
    - This should require any config repairing.


    Update: [Jun 7 2025] ... Oup we forgot to ever update this. It's probably better to keep comments like these local to the updating code. 
