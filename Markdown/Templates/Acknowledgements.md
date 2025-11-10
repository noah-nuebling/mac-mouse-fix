```
key: intro
```
# 🙌 Acknowledgements

Big thanks to everyone using Mac Mouse Fix and providing feedback. It's awesome and highly motivating to see so many people enjoy and engage with something I created.

I want to especially thank the people and projects named in this document.
```
comment:
```

<a name="translations"></a> 
```
key: translations
```
## 🌏 Translations

Thanks for bringing Mac Mouse Fix to people around the globe!

- 🇨🇳 Chinese translations by [@groverlynn](https://github.com/groverlynn)
- 🇰🇷 Korean translations by [@jeongtae](https://github.com/jeongtae)
- 🇻🇳 Vietnamese translations by [@nghlt](https://github.com/nghlt)
```
comment:
```

<!-- 
  Old stuff from Money section:

  Thanks so much to everyone who bought me a milkshake and to all {sales_count} people who bought Mac Mouse Fix! Ya'll are the bomb. Thanks to you I can spend lots of time on sth I love doing.
  You make me me feel like there are many generous people out there who appreciate the app and want to support it, and thanks to you, I can spend more time on something I love doing. 
-->

<a name="money"></a> 
```
key: money
```
## 💰 Money

Thanks so much to everyone who treated me to a milkshake and to all **{sales_count}** people who bought Mac Mouse Fix.
Thanks to you, I can spend lots of time doing something I love. 

People who supported me by spending more than the standard price on Mac Mouse Fix receive a special mention here:
```
comment:
```

<a name="generous-contributors"></a> 
```
key: money.generous
```
### ⭐️ Generous Contributors

Thanks for your support! :)
```
comment:
```

{generous}

<a name="very-generous-contributors"></a> 
```
key: money.very-generous
```
### 🚀 Very Generous Contributors

These people spent a lot more than the standard price and treated me to an **Incredible Milkshake**. (And some even left a message) Thanks for the *sugar rush*!
```
comment:
```

{very_generous}

<a name="github-sponsors"></a> 
```
key: money.github-sponsors
```
### ❤️ GitHub Sponsors

**Huge thanks** to [anyone](https://github.com/sponsors/noah-nuebling#sponsors) sponsoring me on GitHub! Hopefully I can get that milkshake factory one day thanks to you. :)
```
comment:
```

<a name="paypal-donations"></a> 
```
key: money.paypal-donations
```
### ✨ PayPal Donations

Lots of generous people bought me milkshakes on PayPal when Mac Mouse Fix was still entirely free.

If you're among them, click [here](https://redirect.macmousefix.com/?locale={locale_code}&target=mmf-apply-for-milkshake-license) to receive a **free license**!

```
comment:
```
<!-- It's truly incredibly helpful to have some predictable monthly income. -->

<a name="other-software"></a> 
```
key: software
```
## 👾 Other Software
```
comment:
```

```
key: software.inspiration
```
**Software** that inspired Mac Mouse Fix:

- [SteerMouse](https://plentycom.jp/en/steermouse/index.html) - Pioneering mouse software for Mac, inspiring many features. There were moments when I thought "this is probably not possible", but then I saw "oh, SteerMouse does it", and three years later, I figured out how to implement it, too.
- [Calftrail Touch](https://github.com/calftrail/Touch) - The foundation for the "reverse engineering" work which powers Mac Mouse Fix's best-in-class and first-of-a-kind trackpad simulation!
- [MOS](https://mos.caldis.me/) - Mac Mouse Fix's "High Scroll-Smoothness" option, the "App-Specific Settings" implementation, and more were inspired by MOS.
- [SensibleSideButtons](https://github.com/archagon/sensible-side-buttons) - I copied its code for an early implementation of the "Go back/forward one page in Safari and other apps" feature, and also led me to discover the Calftrail Touch project.
- [Gifski](https://github.com/sindresorhus/Gifski) - Greatly inspired the design and content of the [Readme.md]({language_root}Readme.md) for Mac Mouse Fix.
- [Vue Issue Helper](https://new-issue.vuejs.org/) - Foundation for the design and technical implementation of [Mac Mouse Fix Feedback Assistant](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/).
```
comment:
```


<!--

  vvv Unused stuff and notes vvv.

  TODO: Once we overhaul the website: add inspirations and libraries of the website here
  NOTE: Should I name pastebin too? And Gumroad API? - ANSWER: No, APIs don't really fit here I think. No good reason why. Maybe just lazyness.

  NOTE: Should I add my personal developments tools I used to the software section? - Xcode, VSCode, GitHub, iTerm2, fish shell, z clt, maybe more...
  NOTE: We're not including the "outstandingly helpful feedback" section. It's kinda weird and there is no concrete thing that they did which is now part of MMF. 
        If ppl make pull requests with significant contributions, then we should mention them somewhere.


    [BartyCrouch](https://github.com/FlineDev/BartyCrouch) - Keep translation files in sync with source code and Interface Builder files 


      ## ☺️ Outstandingly Helpful Feedback
      
      __People__ that inspired Mac Mouse Fix:
      
      - @DrJume for teaching me about debouncing and inspiring the UI for entering and displaying keyboard modifiers on the scroll tab
      - German guy for inspiring the tab-based layout in MMF 3
      - Guy who made an alternative app icon
      - Guy who helped tune the fast scrolling in that pull request
      - [SmoothMouse](https://smoothmouse.com/) - It's creator [Dae](https://dae.me/) answered some important questions for me about Pointer Speed in macOS.
      
      - So many others I can't think of right now. Thanks to everybody else who shared their thoughts!
  
  
      
    Random old note: 
        ^^^ Note: The double space after <br> is not necessary for the formatting to work here, so we don't have to tell localizers.
              (If you use actual linebreaks instead of <br> I think it is sometimes necessary.) 
  
    Old paragraph with key `software.libraries` and comment ```Note: Don't forget the `<br>`, it inserts a line<br>eak.``` 
    Removed [Oct 2025] because I wanna remove some of these dependencies and don't wanna promote them, also it's too hard to keep up-to-date and people who really care can scan the source files for the dependencies.
    
        Mac Mouse Fix was built with the help of these **great libraries**:

        - [ReactiveSwift](https://github.com/ReactiveCocoa/ReactiveSwift) - Streams of values over time tailored for Swift
        - [CocoaLumberjack](https://github.com/CocoaLumberjack/CocoaLumberjack) - Fast & simple, yet powerful & flexible logging
        - [Swift Markdown](https://github.com/apple/swift-markdown) - Parse, build, edit, and analyze Markdown documents
        - [Sparkle](https://github.com/sparkle-project/Sparkle) - A software update framework for macOS
        - [MASShortcut](https://github.com/shpakovski/MASShortcut) - API and user interface for recording, storing & using system-wide keyboard shortcuts
        - [CGSInternal](https://github.com/NUIKit/CGSInternal) - A collection of private CoreGraphics routines
        - Dependencies of Mac Mouse Fix's scripts:<br>
          [Update and statistics scripts](https://github.com/noah-nuebling/mac-mouse-fix/blob/update-feed/requirements.txt) | [Markdown generator script]({repo_root}Markdown/Code/python_requirements.txt) | [.strings file sync script]({repo_root}Localization/Code/UpdateStrings/requirements.txt) | ["State of Localization" script]({repo_root}Localization/Code/StateOfLocalization/requirements.txt)
        - Dependencies of the [Mac Mouse Fix Feedback Assistant](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/) web app [here](https://github.com/noah-nuebling/mac-mouse-fix-feedback-assistant/blob/master/package.json)
        - Dependencies of the [Mac Mouse Fix Website](https://macmousefix.com/) are available [here](https://github.com/noah-nuebling/mac-mouse-fix-website/blob/main/package.json)
        ```
        comment:
        ```
  
  -->
