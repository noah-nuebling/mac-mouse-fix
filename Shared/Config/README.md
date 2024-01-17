#  Notes on config

- When you copy over a real `config.plist` to `default_config.plist`, make sure to reset the `State` values
- `Remaps` in `default_config.plist` should be empty.
    - It will be programmatically replaced with one of the `defaultRemaps`


## Version Changes

Here, we document, what exactly changed as we increased the configVersion

**21 -> 22**

- "License.trial.lastUseDate" is now stored in `SecureStorage` instead of config. 
    - This is to prevent bug where trial counter would go up too fast when the user switched between machines frequently (I think it resolves this) (See https://github.com/noah-nuebling/mac-mouse-fix/discussions/743#discussioncomment-8050398)
    - This should require any config repairing.

**22 -> 23**

- Changed the default remaps for 3-button-mice

**23 -> 24**

- Moved 'License' under 'State'
    - Renamed 'License' to 'license'
- Added 'Buttons'. 
    - Moved 'Remaps', 'defaultRemaps', and 'lockPointerDuringDrag' under 'Buttons'
    - Renamed 'Remaps' to 'remaps'   
