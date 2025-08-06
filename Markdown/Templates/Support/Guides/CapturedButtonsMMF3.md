
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

For example, if 'Middle Mouse Button' **isn't captured** by Mac Mouse Fix, then clicking it over a link in Safari will open that link in a new tab.
However, while Middle Mouse Button **is captured** by Mac Mouse Fix, clicking it over a link in Safari won't do anything. 
That's because Safari (or any other app) can't see when you click the Middle Mouse Button while it is captured by Mac Mouse Fix.
```
comment:
```

```
key: which-buttons
```

### How do I know which buttons are captured by Mac Mouse Fix?

Any button which shows up on the left side of the Action Table is captured by Mac Mouse Fix.

In this image **Middle Button**, **Button 5**, and **Button 4** are captured <br>
<img width="400" alt="Screen Shot 2021-05-29 at 04 44 50" src="https://user-images.githubusercontent.com/40808343/120055995-d8543c00-c039-11eb-8c7b-049608197272.png">

Note that when you disable Mac Mouse Fix, it won't have any effect on your mouse or any of its buttons, regardless of whether they are captured or not.
```
comment:
```

```
key: uncapturing
```

### How to uncapture a mouse button?

To uncapture a mouse button, delete all rows in the Action Table which contain that button. 
You can delete a row in the Action Table by selecting it and then clicking the '-' button.

https://user-images.githubusercontent.com/40808343/120056314-a348e900-c03b-11eb-831b-ab44f0abf8ac.mov
```
comment:
```

```
key: restoring
```

### What can I do to restore the original functionality of a button?

To restore the original functionality of a button, you can uncapture the button as described above. 
You can also always disable Mac Mouse Fix entirely to have your mouse behave exactly as it originally did.

For one scenario there's a neat workaround:
```
comment:
```

```
key: restoring.middle-button
```

#### How to use the original functionality of clicking the Middle Mouse Button without uncapturing it?

To use the original functionality of clicking Middle Mouse Button _without_ uncapturing it, you can choose the **'Middle Click' action**.

<img width="400" alt="Screen Shot 2021-05-29 at 05 19 57" src="https://user-images.githubusercontent.com/40808343/120056598-97f6bd00-c03d-11eb-9784-e4a428910fb4.png">

It will allow you to open links in a new tab, paste text in the Terminal, and do anything else that clicking the Middle Mouse Button normally does.

Note that this workaround will only restore the original functionality of _clicking_ the Middle Mouse Button, and not of clicking and _dragging_ it. 
So this won't allow you to pan around in 3d apps like Blender, unfortunately. 
To have Blender work properly with Mac Mouse Fix, you'll have to uncapture the Middle Mouse Button as described above or disable Mac Mouse Fix whenever you're using Blender.
```
comment:
```

<!-- Hint: You can also assign the 'Middle Click' action to other any other trigger like 'Button 4 Hold' etc. Learn more about triggers in this guide -->

{guide_footer}