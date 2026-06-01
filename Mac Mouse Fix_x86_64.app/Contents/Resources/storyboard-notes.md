# storyboard-notes.md

[Aug 2025] Notes regarding the UI in Main.storyboard.

## Hint under the enableCheckbox (aka `enableToggle`)

[Aug 2025] The hint is supposed to teach people that they don't have to add MMF to Login Items.
Lately I've noticed quite a few report requests about 'hiding MMF on startup'. I think for a year or so after releasing MMF 3 we didn't get such requests. I'm not sure what changed.

To try to mitigate this, I changed the hint text to be clearer in 3958c9e5a616525c729ca07bd478b79d9f0bd6d4 in [Aug 2025] 
    ... And left some more notes in this follow-up commit: 579ddf1b9de7dcf6764d0f7b1728f036c98c6e6e

After making this change in MMF 3, I noticed that we had a more detailed text in MMF 2! (Totally forgot)
    Here's the tooltip for the enableToggle in MMF 2:
        ``` 
        Enable Mac Mouse Fix for a better mouse experience!
        
        Mac Mouse Fix stays enabled even after you quit the app or restart your computer.
        
        To disable Mac Mouse Fix, uncheck this checkbox or move the app to the Trash.
        ```
        -> This is pretty close to what we did in 3958c9e5a616525c729ca07bd478b79d9f0bd6d4, but a bit more detailed and 'conversational'.

