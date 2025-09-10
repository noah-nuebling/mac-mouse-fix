


<!--

Planning for updated MMF 3 Captured Buttons Guide: [Aug 2025]

- There are two aspects to the Guide:
    - Practical user problems caused by capturing
        - Helping people solve these are the core purpose of this Guide
        - List of practical problems I can think of
            - Terminal pasting, Browser-link-opening 
                - (Due to Middle Click capturing)
            - Blender orbiting 
                - (Due to Middle Drag capturing)
            - Browser back-and-forward 
                - (Due to Side-Button Capturing) 
                - (I don't remember actually hearing issue reports about this.)
            - Video-game remapping of side-buttons 
                - (Due to Side-Button Capturing) 
                - (Which videogames do that?)
            - Using MOS, Logi Options, or another smooth scrolling app for scrolling, and using MMF only for buttons
                - (Due to scrollwheel capturing) 
                - (Not sure if you need to fully uncapture to make this work – Can't you just turn off smooth-scrolling in MMF? But it would still be nice for users to know how to get MMF CPU usage during scrolling to 0% if they don't need it.)
    - Instilling fundamental mental model of how capturing works
        - If people understand this, they can then understand how to solve their specific practical problems. Maybe even ones we're not aware of.
        - This may make up the majority of the content, but it's **in service** of people being able to solve the practical problems.

Content:
    - Core explanation of 'capturing' 
        - should probably be shared for scrollwheel and buttons
        - ... But that might make it more abstract and harder to understand? 
    - Practical UI-based guides 'How do I know what is captured' and 'how to uncapture' 
        - should probably be specific to scrollwheel / buttons and should probably use screenshots so it's very easy-to-follow
    - Reference to practical problems (See above)
        - People with those practical problems should be naturally guided to this article and it should be clear that they need to read this to sole the problem.
            - Leading with the abstract explanations of what 'capturing' means might not make this obvious?
                - Maybe list the practical issues explicitly in a scannable way.
            - Think about the 'user journey' for people with those practical problems!
        - Also write about how people can solve those practical issues caused by capturing *without* uncapturing (e.g. Middle Click action, Scroll & Navigate for Orbiting, etc.)
            - I guess you could think of uncapturing as a bit of a nuclear/last resort option (?) (but useful to understand)
        - Probably pull in the Blender Orbiting section from Readme > Questions
            - Are there other sections we should pull in?
-->


<!-- 
    Philosophical: The current draft explains the reasoning and addresses the problem cases I'm aware of in great detail. The old version just tried to instill fundamental understanding of capturing and let users figure out their usecases (and mentions some problem-cases briefly at the end to say "here's how to solve this without uncapturing")

    Update: [Sep 2025] It seems we since went back to something closer to the old structure.

        New Philosophical thoughts: I think I program too much. I was too in my head with this. This isn't about making some technically perfect thing, it's just about helping people solve problems with the app.
-->

<!-- 

-->

<!--

# Captured Buttons

When you install Mac Mouse Fix, you'll notice that the **buttons on your mouse perform new functions**.

However, you may also notice that, some of the old **functions that those buttons used to perform no longer work**.

This may disrupt your workflow, if you previously used the buttons to:

- Click and Drag the middle button to **Orbit around objects in 3d modeling apps like Blender.**
- Click the middle button to **paste text in the Terminal**
- Click the middle button to **open links in a new tab in Safari and other browsers**
    - Click the middle button to **close tabs in Safari and other browsers**. 
        (Is this worth mentioning separately?)
- Click the side buttons (mouse button 4 and 5) to **go back and forward in Chrome, VSCode, and other apps.**
- Remapped the mouse buttons to **Custom assigned functions in video games or pro apps** (like ...? VSCode?).

The buttons will no longer perform their usual actions because the buttons have been **captured** by Mac Mouse Fix – that means Mac Mouse Fix takes **complete control** of those buttons and **other apps no longer get notified** when you press those buttons. (/ "can no longer see" those buttons.) 

Mac Mouse Fix needs to hide the button from other apps so that you can perform gestures and actions in Mac Mouse Fix without accidentally triggering functions on those other apps at the same time.

## What can I do to restore the functionality of a button before it was captured by MMF?

To get back the functionality that you were used to before installing Mac Mouse Fix, there are 3 approaches.

1. Leave the Button captured, but assign functionality inside MMF that restores the original functionality that you were used to.
2. Uncapture the button – if you delete **all the bindings** in MMF for a button, then that button will no longer be captured and will behave exactly as if Mac Mouse Fix was disabled
3. Disable Mac Mouse Fix entirely (Switch off `General > Enable Mac Mouse Fix`) – then MMF will not interfere with the functioning of your mouse at all.

### 1. Restoring old functionality – without uncapturing


 - Assign Click and Drag to 'Scroll & Navigate'. It will simulate trackpad-swiping with 2 fingers which lets you orbit in Blender among other things. However if your computer getting slow this might become less responsive (Working on that.)
    Solves usecases: 
        - **Orbit around objects in 3d modeling apps like Blender.**
        - **go back and forward in Chrome, VSCode, and other apps.**
- Assign Clicking to 'Middle Click' action in MMF.
    Solves usecases: 
        - **paste text in the Terminal**
        - **open links in a new tab in Safari and other browsers** 
            - and **close tabs in Safari and other browsers**
        - **Custom assigned functions in video games or pro apps**
            - Caveats: Only 'click' actions will work, not 'Click and Drag' actions – because MMF sends the mouseup and mousedown event at once. (Necessary to avoid interference with other MMF gestures assigned to the same button)
- Assign clicking to 'Back' and 'Forward' actions in MMF
    Solves usecases:
        - **go back and forward in Chrome, VSCode, and other apps.**
        - **Custom assigned functions in video games or pro apps**
            - Why this works? The 'Back' and 'Forward' actions will actually simulate MB 4/5 clicks in video games and pro apps (since MMF 3.0.6), so you can then remap MB 4/5 in those games/apps and it'll work.
            - Caveats: Only 'click' actions will work, not 'Click and Drag' actions – because MMF sends the mouseup and mousedown event at once. (Necessary to avoid interference with other MMF gestures assigned to the same button)

### 2. Restoring old functionality – by uncapturing

(Maybe insert the explanations of the fundamental capturing concepts from the old guide.)

-->

```
key: intro
```

# {docname_captured_buttons_mmf3}

When using Mac Mouse Fix, you might have come across a message saying that a button on your mouse has been 'captured' by Mac Mouse Fix.

<img width="400" alt="Screen Shot 2021-05-27 at 21 29 49" src="https://user-images.githubusercontent.com/40808343/119886114-e79c9200-bf32-11eb-98a9-4a0e7daab465.png">

In this article, you'll learn what this means, what problems it might cause, and how to work around them.
```
comment:
```

```
key: terminology
```

### What does it mean for a button to be 'captured' by Mac Mouse Fix?

A mouse button that is captured by Mac Mouse Fix can't be seen by other apps or by macOS anymore.
The functions which this button would normally perform won't work anymore while it is captured.

<!--
When you install Mac Mouse Fix, you may notice that:
1. The buttons on your mouse perform new functions, that are assigned in Mac Mouse Fix.
2. Some of the old, familar functions of those buttons stop working. That's because they have been **captured** by Mac Mouse Fix.
-->

For example, while the middle mouse button is captured, clicking it over a link in Safari will **not open that link in a new tab** like it would if Mac Mouse Fix was turned off.

That's because Safari (and any other app) can't see when you click the Middle Mouse Button while it is captured by Mac Mouse Fix.

<!--
When a mouse button is **captured** by Mac Mouse Fix, it takes **complete control** of that button and **other apps no longer get notified** when you press those buttons. (/ "can no longer see" those buttons.) 
-->

<!--
Mac Mouse Fix needs to hide the button from other apps so that you can perform gestures and actions in Mac Mouse Fix without accidentally triggering functions on those other apps at the same time.
-->


```
comment:
```

```
key: which-buttons
```

### How do I know which buttons are captured by Mac Mouse Fix?

Any button which shows up on the left side of the Action Table is captured by Mac Mouse Fix.

In this image **Middle Button**, **Button 5**, and **Button 4** are captured <br>
<!-- <img width="400" alt="Screen Shot 2021-05-29 at 04 44 50" src="https://user-images.githubusercontent.com/40808343/120055995-d8543c00-c039-11eb-8c7b-049608197272.png"> -->
<img width="700" src="{repo_root}/Markdown/Media/ActionTableDE.png">


```
comment:
```

```
key: uncapturing
```

### How to uncapture a mouse button?
<!-- 
- [ ] TODO [Aug 2025]: Replace 'uncapture' with 'stop capturing' or whatever we're using in-app (Cause uncapture doesn't translate well I think?) 
    - [ ] Also reconsider the German phrasing we're currently using: "verhindern, dass eine Maustaste abgefangen wird"
-->


To uncapture a mouse button, delete all rows in the Action Table which contain that button. 
You can delete a row in the Action Table by clicking the '-' button.

https://user-images.githubusercontent.com/40808343/120056314-a348e900-c03b-11eb-831b-ab44f0abf8ac.mov
```
comment:
```

```
key: restoring
```

### How can I restore the original functionality of a button?

To restore the original functionality of a button, you can **uncapture** the button as described above. 
You can also always **disable Mac Mouse Fix entirely** to have your mouse behave exactly as it originally did.

For some use cases, you can restore the original functionality of a button **without uncapturing** it, by instead assigning specific actions inside Mac Mouse Fix:

```
comment:
```

| {{Button||restoring.header.default||}} | {{Original function||restoring.header.function||}} | {{Action in Mac Mouse Fix||restoring.header.action||}} |
|----------|-----------------------------------|-------------------------|
| {{Middle Mouse Button<br>(Click)||restoring.row.1.default||}} | {{Open browser tabs in background||restoring.row.1.function||}} | {{**'Middle Click'**<br>(Can be assigned to **clicking** a button)||restoring.row.1.action||}} |
| {{Middle Mouse Button<br>(Click)||restoring.row.2.default||}} | {{Paste text in Terminal||restoring.row.2.function||}} | {{**'Middle Click'**<br>(Can be assigned to **clicking** a button)||restoring.row.2.action||}} |
| {{Mouse Button 4 / Mouse Button 5<br>(Click)||restoring.row.3.default||}} | {{Back / Forward in VSCode, Chrome, etc.||restoring.row.3.function||}} | {{**'Back'** / **'Forward'**<br>(Can be assigned to **clicking** a button)||restoring.row.3.action||}} |
| {{Middle Mouse Button<br>(Click and Drag)||restoring.row.4.default||}} | {{Orbit around objects in 3D apps like Blender||restoring.row.4.function||}} | {{**'Scroll & Navigate'**<br>(Can be assigned to **clicking and dragging** a button)||restoring.row.4.action||}} |

<!-- 
Should we add explanations / context for the table above?
- [ ] Maybe add screenshot of how to select the actions in MMF? (as in the MMF2 Guide.)
- [ ] Maybe explain how **'Zurück'** / **'Vorwärts'** simulate MB 4/5 clicks in third-party apps
- [ ] Maybe explain how **'Scrollen & Navigieren'** simulates 2-finger Trackpad swipes
-->


```
key: restoring.footer
```
So kannst du weiter **wie gewohnt** die Taste verwenden, aber ihr **zusätzlich** auch noch andere Funktionen zuweisen!
```
comment: 
```


<!-- 
  In 3D apps like Blender, you normally Click and Drag the Middle Mouse Button to orbit around objects.
  But if the Middle Mouse Button is captured by Mac Mouse Fix, then this won't work anymore.
  
  To orbit in Blender _without_ uncapturing the Middle Mouse Button, choose the **'Scroll & Navigate' action**
-->

<!-- Hint: You can also assign the 'Middle Click' action to other any other trigger like 'Button 4 Hold' etc. Learn more about triggers in this guide -->

```
key: also-see
```

## Also see

- [{docname_captured_scroll_wheels}](<{language_root}Support/Guides/CapturedScrollWheels.md>)

```
comment:
```

<br>

---

{guide_footer}
