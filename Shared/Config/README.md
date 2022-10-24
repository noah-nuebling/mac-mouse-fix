#  Notes on config

- If you replace`default_config.plist` with an actual config, it's best to delete temporary stuff like caches.
    - Idea: restructure config to separate temporary state and actual permanent configuration. Make a separate root-level key "State" to hold all the temporary stuff, that shouldn't be in `default_config.plist` 
- `Remaps` in `default_config.plist` should be empty.
    - It will be programmatically replaced with one of the `defaultRemaps`
