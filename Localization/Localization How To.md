# Localization How To

## Also See

- NotePlan [[MMF - i18n]]

## Memory helpers

- Don't change the keys for NSLocalizedString()! Otherwise all the existing translations will be deleted.
- Use `bartycrouch update -v` and `bartycrouch lint` from Terminal. These are also executed by a build script.
- To test layout
    - In build scheme, set argument `-NSConstraintBasedLayoutVisualizeMutuallyExclusiveConstraints YES`
    - In build scheme set pseudo language (e.g. double length)
- NSLocalizedString() convention: Example: `NSLocalizedString("enabled-toggle.hint", comment: "First draft: Mac Mouse Fix will stay enabled after you close it")`

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
