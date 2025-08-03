# {docname_captured_buttons_mmf2}

When using Mac Mouse Fix, you might have come across a message saying that a button on your mouse has been 'captured' by Mac Mouse Fix.

<img width="400" alt="Screen Shot 2021-05-27 at 21 29 49" src="https://user-images.githubusercontent.com/40808343/119886114-e79c9200-bf32-11eb-98a9-4a0e7daab465.png">

In this article, you'll learn what this means, what problems it might cause, and how to work around them.

### What does it mean for a button to be 'captured' by Mac Mouse Fix?

A mouse button that is captured by Mac Mouse Fix can't be seen by other apps or by macOS anymore.
The functions which this button would normally perform won't work anymore while it is captured.

For example, if 'Middle Mouse Button' **isn't captured** by Mac Mouse Fix, then clicking it over a link in Safari will open that link in a new tab.
However, while Middle Mouse Button **is captured** by Mac Mouse Fix, clicking it over a link in Safari won't do anything. 
That's because Safari (or any other app) can't see when you click the Middle Mouse Button while it is captured by Mac Mouse Fix.

### How do I know which buttons are captured by Mac Mouse Fix?

Any button which shows up on the left side of the Action Table is captured by Mac Mouse Fix.

In this image **Middle Button**, **Button 5**, and **Button 4** are captured
<img width="400" alt="Screen Shot 2021-05-29 at 04 44 50" src="https://user-images.githubusercontent.com/40808343/120055995-d8543c00-c039-11eb-8c7b-049608197272.png">

Note that when you disable Mac Mouse Fix, it won't have any effect on your mouse or any of its buttons, regardless of whether they are captured or not.

### How to uncapture a mouse button?

To uncapture a mouse button, delete all rows in the Action Table which contain that button. 
You can delete a row in the Action Table by selecting it and then clicking the '-' button.

https://user-images.githubusercontent.com/40808343/120056314-a348e900-c03b-11eb-831b-ab44f0abf8ac.mov

### What can I do to restore the original functionality of a button?

To restore the original functionality of a button, you can uncapture the button as described above. 
You can also always disable Mac Mouse Fix entirely to have your mouse behave exactly as it originally did.

For one scenario there's a neat workaround:

#### How to use the original functionality of clicking the Middle Mouse Button without uncapturing it?

To use the original functionality of clicking Middle Mouse Button _without_ uncapturing it, you can choose the **'Middle Click' action**.

<img width="400" alt="Screen Shot 2021-05-29 at 05 19 57" src="https://user-images.githubusercontent.com/40808343/120056598-97f6bd00-c03d-11eb-9784-e4a428910fb4.png">

It will allow you to open links in a new tab, paste text in the Terminal, and do anything else that clicking the Middle Mouse Button normally does.

Note that this workaround will only restore the original functionality of _clicking_ the Middle Mouse Button, and not of clicking and _dragging_ it. 
So this won't allow you to pan around in 3d apps like Blender, unfortunately. 
To have Blender work properly with Mac Mouse Fix, you'll have to uncapture the Middle Mouse Button as described above or disable Mac Mouse Fix whenever you're using Blender.

<!-- Hint: You can also assign the 'Middle Click' action to other any other trigger like 'Button 4 Hold' etc. Learn more about triggers in this guide -->

{guide_footer}