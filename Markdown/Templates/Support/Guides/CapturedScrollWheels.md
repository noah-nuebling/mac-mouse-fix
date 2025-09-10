```
key: everything
```

# {docname_captured_scroll_wheels}

Just like Mac Mouse Fix takes captures mouse buttons (See '[{docname_captured_buttons_mmf3}](<{language_root}Support/Guides/CapturedButtonsMMF3.md>)'), it also **captures the scroll wheel**.

And just like with buttons, you can prevent capturing of the scrollwheel by configuring the settings in Mac Mouse Fix in a specific way.

There are less reasons to prevent Mac Mouse Fix from capturing the scroll wheel compared to buttons,
but it may be useful if you'd like another app like [MOS](https://mos.caldis.me/) to handle scrolling on your mouse instead of MMF, or if you prefer completely native scrolling behavior.

**To disable capturing of the scrollwheel**: Go to the 'Scrolling' tab and set all the settings to match the native scrolling behavior in macOS. (Smoothness: Off, Speed: macOS, etc.)
After doing that, you should see a notification that tells you that scrolling is no longer captured by Mac Mouse Fix.

Now when you scroll, Mac Mouse Fix will use no more CPU when you're scrolling. And it will not change the behavior or interfere in any way.


## Also see

- [{docname_captured_buttons_mmf3}](<{language_root}Support/Guides/CapturedButtonsMMF3.md>)

```
comment:
```

<!--
    Notes / thoughts: 

    - Should we call it 'capturing' for the scrollwheel? [Sep 2025]
      - Contra: MMF doesn't hide the scroll-events or prevent any default-actions in the same way it does for mouse buttons. 
      - Pro: Capturing is just used like 'Intercepting' by us. The 'hiding from other apps' thing that happens for buttons isn't inherent
    - Should this article even exist? [Sep 2025]
        - - I don't think it's relevant to many users, 
        - + I think it may prevent confusion if we have consistent Capture Toasts for both the 'Capturing sideeffects' on the Buttons and the Scrolling Tab?
        - + The few users for whom it is useful may really appreciate it.
        - - Maybe this should be a footnote at the bottom of CapturedButtonsMMF3.md?
        - - Maintenance overhead. I'm already not including screenshots here and keeping the step-by-step instructions vague to reduce maintenance overhead – and if we do it badly, maybe better not do it at all?
    - Style [Sep 2025]
        - Compared to CapturedButtonsMMF3.md this is **not** broken up into section for maximum scannability. 
        - This is just a long explanatory, text. 
        - Should we break this up into sections like CapturedButtonsMMF3.md for maximum scannability?
            - - More effort
            - - Less laid back / conversational tone (?) (Not sure why I value that. Feels sorta appropriate for this. Since in some way explaining how to use 'competitor' apps might seem like a conflict of interest and sorta weird if I do it in a sterile tone or something? Not sure I'm making any sense.)
            - Easier to parse for readers
    - Everything takes me so much time
        - We should just ship this and if I really hate it later I can change it. It won't affect very many people I think.
-->
