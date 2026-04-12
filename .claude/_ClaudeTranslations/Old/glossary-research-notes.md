<!--
(Notes on glossary-research.md subagent)


Prompt to this subagent that actually produces reasonable result: 
(prevents it from recommending 'klicken und bewegen', which is retarded)

    Hi Claude. Please spawn a glossary-research subagent and give it these exact instructions:

    ---

    Search Apple's glossary for German (de) translations.

    **Context:** I'm translating UI strings for Mac Mouse Fix, a macOS app that enhances mouse functionality. These strings appear in an Action Table where users configure what happens when they perform mouse gestures. The left column shows triggers (physical mouse actions the user performs) and the right column shows effects.

    The strings I'm translating describe **physical mouse actions** - things like "Click and Drag Button 4" or "Double Click Middle Button". These are descriptions of what the user does with their mouse, NOT instructions telling them to do something.

    **Terms to look up:**
    - Drag (as in "click and drag" - the mouse action where you hold the button down while moving)
    - Scroll (the mouse action)
    - Hold (holding down a mouse button)
    - Click / Double Click / Triple Click
    - Primary Button / Secondary Button / Middle Button (mouse button names)

(When a Claude spawns the subagent it will still recommend 'klicken und bewegen' – not sure how to fix that. Maybe ```Drag (as in "click and drag"``` is key. [Jan 2026])

    Here's a *bad* prompt that Claude alledgedly wrote for the subagent: (This makes it recommend 'bewegen'. Not sure why.) (Update: The Claude fabricated ALL of this. Never experienced that before. It was straight up lying about everything. It never gave this prompt to the subagent. Maybe never called a subagent at all. This prompt works fine.)

        I need Apple's official German (de) terminology for mouse-related terms used in macOS System Settings and UI. These terms appear in a Mac mouse utility app to describe trigger actions (user inputs).

        Context: These are trigger descriptions shown in a UI table. They describe what the user does with their mouse (e.g., "Click Middle Button", "Double Click and Drag Button 4").

        Please look up the German translations for:

        1. **Click actions**: Click, Double Click, Triple Click (as in "Double Click to open")
        2. **Mouse actions**: Drag, Scroll, Hold (as in "click and drag", "scroll with mouse")
        3. **Button names**: Primary Button, Secondary Button, Middle Button, Button (as in "Button 3", "Button 4")

        Focus on how Apple translates these in:
        - Mouse/Trackpad settings in System Settings
        - Accessibility settings
        - General macOS UI terminology

        Return the official German terms Apple uses for each.

-->