

/**
# Build Schemes and Iteration Times [Dec 2025]
    - Use the `Localization Screenshot Taker - Dont Build MMF` build scheme to quickly iterate on the `LocalizationScreenshotTaker` code itself. [Dec 2025]
        -> This greatly speeds up iteration time, since it doesn't have to build the whole project every time you make a change to the automation/'test' code.
    - Caution/learning: Previously we made this behavior the default – so that you always had to manually build the app first to get it to update– but I forgot that sooo many times and then spent time debugging, so it wasted a lot of time. [Dec 2025]

# More ideas for speeding up XCUITest workflows [Dec 2025]
    - Speed up animations inside MMF
        - I saw a Twitter post on this Today. IIRC, they were setting a global variable on UIView to turn off animations, and speeding up the animation speed on the Window's root CALayer
*/
