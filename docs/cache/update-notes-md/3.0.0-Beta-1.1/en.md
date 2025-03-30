**3.0.0** will be the **biggest update** to Mac Mouse Fix so far! 

Bringing together many features that I've worked on for a long time to finally deliver this awesome **value proposal**: 

**Make your $10 mouse better than an Apple Trackpad!**

And you can **test it now**! I'm really excited to hear your guys' feedback!

Here is **everything that's new**:

## 1. Click and Drag to Scroll

You can now **Click and Drag to Scroll** freely in any direction! 

It also allows you to go back and forward in **Safari**, mark messages as read in **Mail**, and **do anything else** you can do with a **two-finger swipe** on an **Apple Trackpad**! 

I worked hard to implement the feature to this quality standard. But as a result, as you play around with it, I think you'll find it really "**just works**"!

## 2. Scroll Gestures

Mac Mouse Fix now supports **Scroll Gestures**!
That means you can **trigger actions** by **scrolling** while holding down a mouse button!

Scroll Gestures let you get even **more functionality** out of a single mouse button in a super **intuitive** way.

In this beta, there are the **following** Scroll Gestures:

  - **Desktop & Launchpad** allows you to reveal the Desktop or open Launchpad by scrolling either up or down. This feels super fluid and intuitive because it simulates pinching with 4 fingers on an Apple Trackpad.
  - **Move between Spaces** lets you switch between Spaces by scrolling up or down. This feels super fluid as well since it simulates swiping on an Apple Trackpad with 3 fingers. However, I'm not sure if this is redundant since you can already Click and Drag to move between Spaces. Let me know what you think!
  - **Zoom in or out** lets you take a closer look on the web or elsewhere. This was already available in Mac Mouse Fix 2 by holding the Command (⌘) key while scrolling, but now you can do it more easily using just one hand!
  - **Horizontal Scroll** lets you scroll left and right. You can also use it to navigate between pages in Safari and other apps because simulates swiping with 2 fingers on an Apple Trackpad.
  - **Swift Scroll** lets you scroll large distances with minimal effort.
  - **Precise Scroll** lets you scroll small distances and use sensitive UI Elements like volume sliders with precision.
  - **App Switcher** lets you switch between recent apps, just like pressing Command-Tab (⌘ + ↹) on your keyboard. This feature has some bugs and I'm not sure it's very useful, since you can already easily access the Tab Switcher from your keyboard, so I'll probably remove it later. Let me know what you think, though.

## 3. Inertial Scrolling

**Inertial Scrolling** makes scrolling on your mouse feel just as **fast** and **fluid** as an Apple Trackpad. 

Inertial Scrolling creates **long** and very **smooth animations**. On a scroll wheel, long animations generally come with the tradeoff of less control.

But Mac Mouse Fix 3 implements some **smart algorithms** to give you a **great intertial feel** while still offering a lot of **control**.

By the way, if you download this Beta, I think you'll be **one of the first** humans to use **scroll bouncing** from a mouse! (other than the Magic Mouse) I think that's kinda cool.


## 4. Other Scrolling Improvements

I **rewrote** most of the scrolling code for MMF 3. This allowed me to implement many **other small features** and improvements:

1. There are now **2 additional keyboard modifiers** so you can not only **Zoom in or out** with Command (⌘), and **Scroll Horizontally** with Shift (⇧), but also **Scroll Swiftly** with Control (^) and **Scroll Precisely** with Option (⌥).
2. You can now see and **customize all 4 keyboard modifiers** using a beautiful and intuitive new UI.
3. **Always-On Precise Scrolling** lets you scroll precisely even without holding down a modifier key by moving the scroll wheel slowly.
4. **Horizontal Scroll Input** from your mouse is no longer ignored, but instead it's smoothed and inverted just like normal vertical scroll input. If your mouse has a **tilt wheel** or a **horizontal scroll wheel** it should feel much nicer now.
5. The **Scroll Direction Invert Settings** are now independent of the System Settings allowing for a less complicated UI.
6. **Scroll settings** can now be **combined** more freely. For example, you can use **Mac Mouse Fix's** Scroll Speed even when Smooth Scrolling is **disabled**. Or you can use **macOS's** Scroll Speed when Smooth Scrolling is **enabled**. (Note: I personally don't like macOS' Scroll Speed at all and I can't think of reasons why anyone would prefer it. So if you do prefer it I'd be very interested to learn more about your experience! You can reach out through the "**ⓘ About**" Tab.)

## 5. Menu Bar Item

Mac Mouse Fix now has a **Menu Bar Item** so you can always see when it's enabled!

The Menu Bar Item has a **beautiful icon**, and it also allows you to **quickly disable** certain features of Mac Mouse Fix so you can play a game or use an app without Mac Mouse Fix interfering.

Of course, you can also still **disable** it for a cleaner Menu Bar.

## 6. App-Specific Settings Have Been Removed

**App-Specific Settings** are gone for now. However, I do plan to **bring them back** in a much more robust and powerful form in the future.

For now, I think the quick settings in the **Menu Bar** Item are a **better**, if less convenient, solution.

They **solve** the **most important problems** of the old App-Specific Settings:

- App-Specific Settings didn't work with some programs like **command line executables**. This included popular apps like **Minecraft**.
- App-Specific Settings had many limitations like they didn't allow you to **turn off buttons** entirely, which was a problem for many gamers.

Another thing to consider is that the old App-Specific Settings were originally **designed as a bandaid** for some apps being incompatible with the old scrolling system. But now, with the new scrolling system precisely emulating Touch Scrolls coming from an Apple Trackpad, most of these incompatibilities should be **fixed anyways**! So there should be less of a need for what the old App-Specific Settings were best at.

I hope everone is okay with that! Let me know your **thoughts**!

## 7. UI Overhaul

I've completely **rewritten the UI** to be more **beautiful** and **powerful** while still retaining the **simplicity** and **ease of use** that people love about Mac Mouse Fix.

Here's what's new:

- The UI is now split up into different **tabs**. This cleans things up and allows Mac Mouse Fix to provide additional settings that are important to people without the UI becoming too complicated or overwhelming. This will also allow me to extend Mac Mouse Fix with new features in the future. 
- I added subtle and delightful little **animations** all over the new UI that make it easier to navigate and add a feeling of polish.
- Options that depend on other options will be **hidden** and the layout will adjust with beautiful subtle animations. This keeps things as simple and streamlined as possible. So you don't have to waste time and brainpower looking at options that you don't need to be thinking about.
- The new UI features small **hints** for options that can otherwise be confusing.
- The **new Action Table design** makes it much clearer how to add and remove Actions, which many people were confused by. It also shrinks and grows to fit the number of Actions so you don't have to resize it manually.
- The new **About Tab** features a beautiful layout, and puts additional options for support, feedback, and more at your fingertips.
- Some **existing UI strings** have been improved.
- There's now a **new option** to Lock the Mouse Pointer during Click and Drag Gestures. I don't have one to test, but this should be very nice for Trackball-Mice!


## 8. Monetization

Mac Mouse Fix 3 will be **free for 30 days** and then cost **$1.99** to own.

I know that paying for something that used to be free is not the best feeling, but I hope I can convince you that it's a really **good thing for the project**!

Like for every other aspect of Mac Mouse Fix, I paid great attention to making the **user experience** as **simple** and **pleasant** as possible:

1. The **30 free days** are smartly implemented. Mac Mouse Fix **only counts the days** on which you **actually use it**. So there's **no pressure** to use the app before the time is up, and you can make an informed decision whether you want to buy the app or not without any stress.
2. After the 30 free days are over, **paying** for the app is extremely **simple** and **fast**. You can use all the payment methods you love like **Apple Pay** and **PayPal**, and it only takes **2 clicks** to pay from inside the app via Apple Pay!
3. After you bought the app for $1.99, **activating your license** is also extremely **simple**. I actually put a **link** on the **checkout screen** in the web browser that takes you **directly** into the app and opens the **screen for entering the license** for you!
4. After you **activate your license**, there's a cute randomized **thank you message** on the about tab. (I heard there are even some super secret rare ones...)
5. Your license is **synced via iCloud** so it will automatically be available on all your computers!

By helping Mac Mouse Fix financially, you can also help me **spend a lot more time** on it and make it the **best mouse driver EVERRR**. 
I also _love_ spending time on Mac Mouse Fix, so that would also make me **happy** :)

**Will Mac Mouse Fix still be Open Source?**

Yes. Mac Mouse Fix will still be open source, and I don't plan to change that at any point. 

This also means you *can* use Mac Mouse Fix for free by building it from source and disabling the licensing checks. That's perfectly fine, I just discourage sharing these cracked versions online.
And of course, on the next update, you'll get a non-cracked version which means you'll have to do this again for every update. (Or just pay $1.99 for the greatest mouse driver ever! :)

Anyone will also still be able to use source code from Mac Mouse Fix in their free and commercial products as long as they don't just sell a copy of Mac Mouse Fix without adding their own contribution.

Learn about the details in the new [MMF License](https://github.com/noah-nuebling/mac-mouse-fix/blob/version-3/LICENSE) which MMF 3 will be licensed under.

**Will I have to pay to use the Mac Mouse Fix 3 Beta?**

No. You can just use your 30 free days. The free day counter probably won't reset when the stable version of Mac Mouse Fix 3 releases, since that would be extra stuff to design and implement and I don't think anyone will care too much. (Let me know if you do). But I will extend the number of free days if the beta goes on for more than 30 days.

**Can I get Mac Mouse Fix for free if I already donated?**

Yes! If you bought me a milkshake before the 10th of September 2022, you can write an email to noah.n.public@gmail.com with "Milkshake Karma" in the subject and a screenshot as proof and then I'll send you a 100% off discount code or something!

## 9. Internationalization

With the UI rewrite, it's now possible to **translate** Mac Mouse Fix into different languages!

I already translated it into **German**, my native language, and you can translate it into **your language**, too!

I plan to write a more **detailed guide** on this in the future, but if you want to give it a go, here's a small overview of the **steps**:

- **Download** the source code & Xcode
- **[Add your language](https://developer.apple.com/documentation/xcode/adding-support-for-languages-and-regions)** to the project
- Put your translations into the **`.strings`** and **`.stringsdict`** files throughout the project
- **Commit** your changes and create a **pull request**

If your translation is added to the project you'll get **10 MMF copies for free**, and of course, you'll be **credited as a contributor**. I heard you can also leave your **personal message** by changing some of the (secret rare thank you messages) on the About tab. 

Maybe I'll add **more perks** in the future. Let me know if you have any **ideas** for that!

## 10. How You Can Help

You can help by sharing your **ideas**, **issues** and **feedback**!

The best place to share your **ideas** and **issues** is the [Feedback Assistant](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report).
The best place to give **quick** unstructured feedback is the [Feedback Discussion](https://github.com/noah-nuebling/mac-mouse-fix/discussions/366).

You can also access both these places from within the app on the "**ⓘ About**" tab.

**Thanks** for helping to make Mac Mouse Fix better! 🚀