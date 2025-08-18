# Opening Mac Mouse Fix & Malware Messages

If you encountered a problem with opening the Mac Mouse Fix app, this guide will help you solve it.

> [!NOTE]
> **Read this guide if you're on Mac Mouse Fix 2.2.3 or below**
> Mac Mouse Fix 2.2.4 and later are 'notarised' by Apple, which should prevent the issues described in this guide. \
> If you experience problems with opening Mac Mouse Fix 2.2.4 or later, please leave a comment below, so I can help you out and update this guide. Thank you. :)

<!--
> [!NOTE]
> **If you're on Mac Mouse Fix 2.2.3 or below**
> Please refer to this guide for solutions.
>
> **If you're on a newer version of Mac Mouse Fix**
> Newer versions of Mac Mouse Fix are notarised by Apple, which should prevent the issues described in this guide from occurring.  If you experience problems despite this, please comment below so I can help you out and improve this guide. Thank you!
-->

### 1. Problem: 'Cannot check for malicious software' message

When trying to open Mac Mouse Fix for the first time, you might encounter this message:
<img width="350" align="center" src="https://user-images.githubusercontent.com/15073177/117338109-7a02c600-ae9e-11eb-91c5-2dee38ae1d7c.png">

**Why does this message appear?**

In macOS, there is a security feature called 'Notarization'. When an app is notarized, that means Apple has checked it and determined it to be safe. 
Unfortunately, it costs $99 to notarize an app, making it a suboptimal option for small open-source projects like Mac Mouse Fix. 
So Mac Mouse Fix is not notarized, that's why this message appears.

However, since the Mac Mouse Fix source code is freely available and thousands of people are using it and have the ability to write about their experiences on this GitHub page, you can still be sure that Mac Mouse Fix is safe.

**Update:** Mac Mouse Fix 2.2.4 and later are notarized by Apple, so this message should not appear anymore. \
I wrote a little bit about the rationale behind notarizing the app in the  [2.2.4](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4) release notes.

**The solution**

To open Mac Mouse Fix anyways:
1. Right-click Mac Mouse Fix in the Finder, then click 'Open'
2. Click 'Open' again in the window that appears

Mac Mouse Fix should then open normally and the 'cannot check for malicious software' message won't appear anymore.

---

### 2. Problem: 'Will damage your computer' message

If you are already a Mac Mouse Fix user, you might have encountered messages saying that Mac Mouse Fix is malware when trying to open Mac Mouse Fix or after restarting your computer:

<img width="600" align="center" src="https://user-images.githubusercontent.com/232541/117108938-7b58c380-adb6-11eb-9497-b4503161249b.png">

**Why do these messages appear?**

Mac Mouse Fix version 1.0.3 and below were signed with a 'code signing certificate' which has since been revoked. That's what prompted the messages.
1.0.4 and above were signed with a new certificate, but after the 2.0 release, that certificate was also revoked. 

[2.1](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.1.0) and later are signed with a new, valid certificate. 

See #95 to learn more about the issue.

**The solution**

Simply [download](http://noah-nuebling.github.io/mac-mouse-fix-website) the latest version of Mac Mouse Fix. It should open normally.

---

I hope this helped you! If you have any questions you can:
- Write a comment down below
- [Open a new GitHub Discussion](https://github.com/noah-nuebling/mac-mouse-fix/discussions)
- [Send me an Email](mailto:noah.n.public@gmail.com?)
  - Please note that I get many emails and I don't have that much time, so I might take a long time to respond

General feedback and improvement ideas for this guide are also very welcome of course!