# Localization Readme

## Also See

- NotePlan [[MMF - i18n]]

## Tips for Localizers

- Enter a linebreak in .stringsdict using option + enter. '\n' doesn't work.

## Memory helpers

- Don't change the keys for NSLocalizedString()! Otherwise all the existing translations will be deleted.
- Use `bartycrouch update -v` and `bartycrouch lint` from Terminal. These are also executed by a build script.
- To test layout
    - In build scheme, set argument `-NSConstraintBasedLayoutVisualizeMutuallyExclusiveConstraints YES`
    - In build scheme set pseudo language (e.g. double length)
- NSLocalizedString() convention: Example: `NSLocalizedString("enabled-toggle.hint", comment: "First draft: Mac Mouse Fix will stay enabled after you close it || Note: Some useful note")`
- In the `.bartycrouch.toml -> [update.code]` routine, we don't really want the __additive__ option. (It prevents cleanup of unused keys), but without it, bartycrouch started deleting all our translations from `Localizable.strings` when we added the `Shared` folder to the search folders in commit c540b4fe88f832ba5364c70587c670a38e42c753.

## Notes

TODO: We're using `en` as language ID for English and `de` as language ID for German. It might be be better to use `en-US` and `de-DE`? Because that's more accurate and clear if ppl add regional variants such as `de-CH`? We're also using `en-US` and `de-DE` as identifiers on the mmf website and the `markdown_generator.py`. Update: We changed all German translations to lang code `de`, so it shows up neatly in State of Localization.

## Basic guide

- https://medium.com/@mds6058/localization-in-ios-and-how-to-make-it-not-suck-3adcbc3ec08f
- Covers all the (confusing) basics and setup
- Barty crouch: 
    - https://github.com/Flinesoft/BartyCrouch
    - Autogenerates and updates `.strings` files. Super handy!
    - Also supports machine translation, and other cool stuff

## Auto-translate menu items

- 1. https://stackoverflow.com/questions/4206008/avoid-translating-standard-menus-items-in-xcode-project
    - No good answers
    - https://github.com/core-code/MiscApps/tree/master/Translator
        - "Use at your own risk"
- 2. https://stackoverflow.com/questions/11784716/localizing-the-edit-menu-and-other-standard-menus
    - Localization using Apple Glossaries: https://douglashill.co/localisation-using-apples-glossaries/
        - Is a lot of hacky effort
- 3. Maybe I could use Barty Crouch machine translations as a base and then just do the rest by hand
    - It uses Azure Translation. Should be free or extremely cheap but is a bit of work to set up. 
