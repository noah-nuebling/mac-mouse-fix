<!-- This README is greatly inspired by / stolen from sindresorhus/Gifski and sindresorhus/caprine -->

<!-- ||| Ideas / Unused / Comments ||| -->

<!-- 

Section ideas: 
- 

Steal from these READMEs:
- https://github.com/exelban/stats
- sindresorhus/Gifski
- sindresorhus/caprine

Centered screenshot:
````
<div align="center"><img src="Markdown/Media/MMF-Buttons-Screenshot.png" width="600" height="auto"></div>
````

Link section with pipe-symbols instead of html table:
```
<h3 align="center">
<a href=https://noah-nuebling.github.io/mac-mouse-fix-website>Download</a> |
<a href=https://github.com/noah-nuebling/mac-mouse-fix/releases>Releases</a> |
<a href=https://github.com/noah-nuebling/mac-mouse-fix/discussions>Help &  Feedback</a>
</h3>
```

-->

<!-- ||| Language picker ||| -->

<details>
  <summary>󠁧󠁿{current_language}</summary>
	
{language_list}
  [Help translate Mac Mouse Fix to different languages!](https://github.com/noah-nuebling/mac-mouse-fix/discussions/731)
</details>

<!-- ||| Head Section ||| -->

<!--
<table align="center"><td>
You can now test the <a href="https://github.com/noah-nuebling/mac-mouse-fix/releases/">Mac Mouse Fix 3 Beta!</a>
</td></table>
-->

<br>

<div align="center">
	<a href="https://noah-nuebling.github.io/mac-mouse-fix-website">
		<img src="{repo_root}Markdown/Media/AppIconRound3.png" width="200" height="auto">
	</a>
	<h1>Mac Mouse Fix</h1>  
    <p>Make Your $10 Mouse Better Than an Apple Trackpad!</p>
</div>

<br>
<br>

<div align="center">
	<table>
		<th><a href=https://noah-nuebling.github.io/mac-mouse-fix-website>Website ↗</a></th>
		<td><a href=https://github.com/noah-nuebling/mac-mouse-fix/issues/new/choose>Help & Feedback</a></td>
		<td><a href=https://github.com/noah-nuebling/mac-mouse-fix/releases>Version History</a></td>
 		<td><a href="{language_root}Acknowledgements.md">Acknowledgements</a></td> <!-- If you translate this, remember to link to the right language version -->
	</table>
  <!-- vvv Hint for translators: You can change the label by editing the text inside the URL after `label=`. Use url encoding for special chars. E.g. `%20` to insert spaces. -->
	<img src="https://img.shields.io/github/downloads/noah-nuebling/mac-mouse-fix/total?label=Downloads&color=25c65f">
</div>

<br>
<br>
<br>
<br>
<!--Use this extra br when theres text above the first header (Edit: I think by "first header" I meant the h1 saying "Mac Mouse Fix", but not sure) -->
<!-- <br> -->

<!-- ||| Intro Text ||| -->

Mac Mouse Fix is an app that makes your mouse better.

I want to turn Mac Mouse Fix into the best mouse driver *of all time*! Some features are still missing at the moment, but I think in some ways it already turns regular mice into the best input devices for Macs! At the same level or even better than an Apple Trackpad or a Logitech MX Master mouse.

For more information on how exactly Mac Mouse Fix enhances your mouse, visit the [website](https://noah-nuebling.github.io/mac-mouse-fix-website).


<!--
easy, efficient, natural and pleasant
Better than an Apple Trackpad or a Logitech MX Master. (These are often considered some of the best input devices for Macs)

It offers amazingly natural and polished gestures and smooth scrolling that let you breeze through macOS just like an Apple Trackpad.

It lets you do almost anything right from your mouse with its powerful customization options that are so simple and intuitive that anyone can use them.
-->

## Background

This is what I wrote on the Mac Mouse Fix website when I released the very first version during the semester break in 2019:

> My name is Noah and I made Mac Mouse Fix. When I started this project I was completely new to software development, but with the power of Google, Stack Overflow, and Apple's Developer Documentation at my fingertips I managed to learn what is necessary to deliver a solid little app that I hope will be useful for you guys. Working on Mac Mouse Fix made me discover a passion for programming, and led me to enroll in a Computer Science Degree at college, which has been awesome so far. I probably won't have a lot of time to work on Mac Mouse Fix during the semester, but please feel free to make your own contributions to Mac Mouse Fix on GitHub!

Since then, I have unfortunately struggled a lot with my mental health. And after starting out with really good grades and a nice social life, I unfortunately became too depressed and anxious to finish my degree. However, I still have a lot of passion and fun working on Mac Mouse Fix, and I hope to be able to sustain myself financially through the project and to slowly but deliberately turn it into the best mouse driver ever and an app that any Mac user with a mouse can appreciate and benefit from. Thanks so much to everyone for their support, be it through financial support, by requesting and discussing features and bugs, or by simply sharing their excitement about the app! <3 :) Thank you.

## Features

See the [website](https://noah-nuebling.github.io/mac-mouse-fix-website#trackpad) for an overview of the features of Mac Mouse Fix, including video demos!

For more details, see the <a href=https://github.com/noah-nuebling/mac-mouse-fix/releases>version history</a>.

<!--
Major features were introduced in these versions:

[0.9](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/0.9.0)
| [1.0.0](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/1.0.0)
| [2.0.0](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.0.0)
| [2.1.0](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.1.0)
| 3.0.0
-->


## What people say

Thanks so much to everyone sharing their excitement about Mac Mouse Fix!\
On the [website](http://noah-nuebling.github.io/mac-mouse-fix-website/) you can find a collection of nice things people have said about the app.


<!-- 
These cool articles were written about MMF

- That YouTube video (so sick)
- Lifehacker
- Blib blob (Japanese)
- Not CNET review
- (?If you know about other coverage of MMF let me know?) 
-->

## Installation

Download the latest version of Mac Mouse Fix on the [website](http://noah-nuebling.github.io/mac-mouse-fix-website/).

You can also install Mac Mouse Fix through [Homebrew](https://brew.sh/)! Just type the following command into the terminal:

```bash
brew install mac-mouse-fix
```

You can download older versions of Mac Mouse Fix from the [version history](https://github.com/noah-nuebling/mac-mouse-fix/releases).

## macOS compatibility

The latest version of Mac Mouse Fix is made for **macOS 11 Big Sur** or later.
  
If you're on macOS **10.15 Catalina**, macOS **10.14 Mojave**, or macOS **10.13 High Sierra**, you can use Mac Mouse Fix [2.2.3](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.3) or below. Later versions of Mac Mouse Fix might still work on your machine, but they will have visual issues and some features might not work properly.
    
If you're on macOS **10.12 Sierra**, or **10.11 El Capitan**, you can use Mac Mouse Fix [2.2.0](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.0) or below.

## Pricing

See the [website](https://noah-nuebling.github.io/mac-mouse-fix-website#price) for an overview of the pricing for Mac Mouse Fix 3.\
Mac Mouse Fix 2 and below will remain free forever.

## Uninstallation

Uninstall Mac Mouse Fix by simply moving it to the bin. 

However, there will be files left on your system. To get rid of these files I recommend the awesome [AppCleaner by FreeMacSoft](https://freemacsoft.net/appcleaner/).

Under macOS, it is not feasible for apps to delete these leftover files by themselves when you delete the app. That's why I highly recommend using an app like AppCleaner.

## Tips

- **Manage windows with a simple Click and Drag**

  [Swish](https://highlyopinionated.co/swish/) is my favorite way to manage windows on macOS. With a simple swipe on your trackpad, it lets you position any window so it takes up half, a quarter, or the whole screen.

  Swish is designed for trackpad gestures, but with Mac Mouse Fix you can use it from any third-party mouse! Just go to Mac Mouse Fix and set any buttons "Click and Drag" action to "Scroll & Navigate" and then you can snap windows with a simple Click and Drag.

  Anything you can do with a two-finger swipe on an Apple trackpad works just as well with the "Scroll & Navigate" feature in Mac Mouse Fix.

- **Control Screen Brightness, Audio Volume, or Media Playback right from your mouse**

  Mac Mouse Fix lets you use **any key on your keyboard** directly from your mouse -
  even special keys only found on Apple keyboards that let you control Screen Brightness, Audio Volume, Media Playback, and more.

  If you don't have an Apple keyboard at hand, **hold Option (⌥)** to choose the special Apple keys.

  <img src="{repo_root}Markdown/Media/Apple-Keys-Demo.gif" width="700">

## Questions

- **Is Mac Mouse Fix native on Apple Silicon?**

  Yes, Mac Mouse Fix runs 100% native on Apple Silicon.

- **Does Mac Mouse Fix collect my data?**

  No. Mac Mouse Fix does not have ads and it doesn't collect any personal information about you.

  The only data I collect is the number of downloads and sales of the app.\
  If you have updates turned on, Mac Mouse Fix will ping GitHub's servers every time you launch the app to ask for an update. But I don't collect any information about this.

- **Why is there a delay when I click?**

  When you click, Mac Mouse Fix might wait to see if you're going to double click.\
  To remove the delay for a button, delete any "Double Click" actions for that button.

- **How can I orbit around objects in 3D apps like Blender?**

  In 3D apps like Blender, you normally Click and Drag the Middle Mouse Button to orbit around objects.\
  But if you assign actions to the Middle Mouse Button in Mac Mouse Fix, then this won't work anymore.
  
  To solve this, I know of 2 options:
  1. Assign clicking and dragging one of the buttons of your mouse to the "Scroll & Navigate" feature. This feature simulates swiping with 2 fingers on an Apple Trackpad. This will, among other things, let you orbit in 3D apps! 
  2. *Uncapture* the Middle Mouse Button by deleting all actions assigned to it in Mac Mouse Fix. See [this guide](https://github.com/noah-nuebling/mac-mouse-fix/discussions/112) for more info.

- **Is my mouse supported?**

  Short answer: Probably. If you want to know for sure, it's best to download Mac Mouse Fix and try it out.

  Mac Mouse Fix works very well with most mice. However, on certain mice designed to be used with proprietary driver software like Logitech Options, Mac Mouse Fix can't recognize all the buttons at the moment. 
  
  That's because these mice communicate with your computer using a special, proprietary protocol, instead of the standard USB protocol.
  I would love to add full compatibility for these mice at some point, but it's a ton of work and it won't be coming soon.

- **Is the Magic Mouse supported?**

  I might add features in the future which enhance the Apple Magic Mouse, but currently, Mac Mouse Fix has no effect on it.
  
  <!-- You can use SteerMouse or proprietary driver like Logitech Options instead. -->


<!--
- **How many buttons should my mouse have?**

  To get the best experience I recommend using Mac Mouse Fix with a mouse that has at least 5 buttons. If your mouse has fewer than 5 buttons, Mac Mouse Fix still provides rich functionality and a great experience, but some features will be less easy to access compared to a 5-button mouse. With a 5-button mouse, you can really breeze through macOS in a way that's just as nice as an Apple Trackpad!
  
  To learn more, see the [trackpad section](https://noah-nuebling.github.io/mac-mouse-fix-website#trackpad) on the website.


- **Mouse brands**

  I'm not the biggest expert on mouse hardware, but I do have quite a collection now, thanks to my work on Mac Mouse Fix! If I had to make a recommendation for what mouse to buy for the best experience with Mac Mouse fix, I'd say get a smaller, chinese brand on Amazon. In my experience, these mice often have better build quality at a fraction of the price of a big brand mouse like Logitech or Roccat. Also, some models of bigger manufacturers like Logitech are made to be used with their proprietary driver software, and they won't be fully compatible with Mac Mouse Fix. If you buy a smaller brand, you can usually be sure, that they will work flawlessly with non-proprietary drivers like Mac Mouse Fix.
-->

- **Are tiltable scroll wheels supported?**

  Some mice let you tilt the scroll wheel left or right to scroll horizontally. Mac Mouse Fix will make this feel more natural and easy to control. However, it's not currently possible to trigger other actions, such as switching between desktops, by tilting the scroll wheel. I'd love to implement this feature at some point, but it's a ton of work and it won't be coming soon.
  
  <!-- This is so hard, because it would require reprogramming the mouse so that it sends button-signals instead of sending scroll-signals, when you tilt the scroll wheel. And to reprogram the mouse, would require communicating with the it through the custom vendor-specific protocol. And that's not easy. For many mice it's not even possible. -->

- **Turning off pointer acceleration**

  Mac Mouse Fix doesn't let you turn off the pointer acceleration, but if you're on **macOS 14 Sonoma** or later, you can turn off the pointer acceleration under `System Settings > Mouse > Advanced... > Pointer acceleration`.

  I plan to add really nice ways to improve pointer acceleration in the future, but I'm not sure when that's coming.

- **Will Mac Mouse Fix still be Open Source now that it's monetized?**

  Yes, Mac Mouse Fix will still be open source.

  I encourage anyone to use the source code of Mac Mouse Fix in their own projects, as long as they don't release a simple copy of Mac Mouse Fix.

  Learn about the details in the [MMF License](https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License) which Mac Mouse Fix 3 and later are licensed under.

  <!--
    , and I don't plan to change that at any point.
  
    This also means you can use Mac Mouse Fix for free by building it from source and disabling the licensing checks. That's perfectly fine, I just discourage sharing these cracked versions online.\
    And of course, on the next update, you'll get a non-cracked version which means you'll have to do this again for every update. (Or just pay $1.99 for the greatest mouse driver ever! :)
  -->

- **Can I get Mac Mouse Fix for free if I already donated?**

  Yes! See the [Acknowledgements]({language_root}Acknowledgements.md#-paypal-donations) for more info.

## How you can contribute

There are several ways to help the project.\
Check out the [Acknowledgements]({language_root}Acknowledgements.md) for more info on who has already contributed!

<!--
- **Spreading the word**

  If you simply talk about Mac Mouse Fix on the internet or elsewhere, that is very helpful for the project.

-->
- **Giving feedback**

  You can help by sharing your **ideas**, **issues** and **feedback** via the [Feedback Assistant](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report).

- **Contributing money**
  
  I hope to be able to sustain myself financially through Mac Mouse Fix. That way, I can keep improving and working on the app. If you would like to help, you can:
  1. Buy Mac Mouse Fix by clicking the button in the app, or clicking [here](https://noahnuebling.gumroad.com/l/mmfinappusd).
  2. [Tip me](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=ARSTVR6KFB524&source=url&lc=en_US) on PayPal. I don't get a lot of money from this, but it's always cute and motivating to get a donation.
  3. [Sponsor me](https://github.com/sponsors/noah-nuebling) on GitHub. A monthly sponsorship is a great way to support the project and help me have a more stable income.

- **Adding translations**
  
  Mac Mouse Fix is available in English, German as well as the languages listed in the [Acknowledgements]({language_root}Acknowledgements.md).

  If you would like to help translate the project, see [this guide](https://github.com/noah-nuebling/mac-mouse-fix/discussions/731).\
  If you want to report missing or outdated translations through the [Feedback Assistant](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=other), that's also very helpful!

- **Contributing code**

  If you would like to contribute code, that's awesome! I'll be happy about any [pull requests](https://github.com/noah-nuebling/mac-mouse-fix/pulls).
  
  However, I might not accept all pull requests. If you want to make sure that your work is not wasted, you can submit an initial pull request that only *describes* the changes you want to make, but contains little or no code. Then I can give you feedback and tell you if I would adopt the changes you want to make in that way.
  <!-- NOTE: I should mention people who contributed code on the acknowledgements page. They are already in the update notes. -->

**Thank you** to everyone who has already contributed and supported me in trying to make the best mouse driver *of all time*! :)🚀