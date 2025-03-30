Mac Mouse Fix **2.2.5** features improvements to the update-mechanism, and it's ready for macOS 15 Sequoia!

### New Sparkle update framework

Mac Mouse Fix uses the [Sparkle](https://sparkle-project.org/) update framework to help provide a great updating experience.

With 2.2.5, Mac Mouse Fix switches from using Sparkle 1.26.0 to the latest Sparkle [1.27.3](https://github.com/sparkle-project/Sparkle/releases/tag/1.27.3), containing security fixes, localization improvements and more. 

### Smarter update mechanism

There's a new mechanism that decides which update to show the user. The behavior changed in these ways:

1. After you skip a **major** update (such as 2.2.5 -> 3.0.0), you'll still be notified of new **minor** updates (such as 2.2.5 -> 2.2.6).
    - This allows you to easily stay on Mac Mouse Fix 2 while still receiving updates, as discussed in GitHub Issue [#962](https://github.com/noah-nuebling/mac-mouse-fix/issues/962).
2. Instead of showing the update to the latest release, Mac Mouse Fix will now show you the update to the first release of the latest major version.
    - Example: If you're using MMF 2.2.5, and MMF 3.4.5 is the latest version, the app will now show you the first version of MMF 3 (3.0.0), instead of the latest version (3.4.5). This way, all MMF 2.2.5 users see the MMF 3.0.0 changelog before switching to MMF 3.
    - Discussion:
        - The main motivation behind this is that, earlier this year, many MMF 2 users updated directly from MMF 2 to MMF 3.0.1, or 3.0.2. Since they never saw the 3.0.0 changelog, they missed any info about the pricing changes between MMF 2 and MMF 3 (MMF 3 no longer being 100% free). So when MMF 3 suddenly said they need to pay to continue using the app, some were - understandably - a bit confused and upset.
        - Disadvantage: If you just want to update to the latest version, you'll now have to update twice in some cases. This is slightly inefficient, but it should still only take a few seconds. And since this makes the changes between major versions much more transparent, I think it's a sensible tradeoff.

### macOS 15 Sequoia support

Mac Mouse Fix 2.2.5 will work great on the new macOS 15 Sequoia - just like 2.2.4 did.

---

Also check out the previous release [**2.2.4**](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/2.2.4).

*If you have trouble enabling Mac Mouse Fix after updating, please check out the ['Enabling Mac Mouse Fix' Guide](https://github.com/noah-nuebling/mac-mouse-fix/discussions/861).*