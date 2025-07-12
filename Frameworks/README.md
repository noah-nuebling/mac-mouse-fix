
- This folder is for manually added (copy pasted) frameworks
- In the update-feed branch, we're using command line tools from the Sparkle project. 
   -> It might be good if the copy of the Sparkle project in update-feed is the same version as Sparkle.framework in this branch. (And to also keep stuff in sync with other active development branches, like the version-2 branch, and master branch)

- Originally, we used Sparkle 1.26.0
- In 21. May 2024, we switched to the latest Sparkle 1.27.3 (On both `version-2` (MMF 2) and `master` (MMF 3) branches)
    - We decided against using SPM, because I feel like this gives me more control and transparency? Maybe on MMF 3 it makes more sense to use SPM, since we're already using it there?
- On [Jul 5 2025] I updated mac-mouse-fix/master from Sparkle 1.27.3 to a custom build of Sparkle 1.27.3 which visually improves the SUUpdate alert (increased vertical margins and improved border around the release-notes). 
    - Reason for these changes:
        - The border looked jarring on macOS Tahoe Beta 2, and couldn't keep myself from adjusting the margins, too. 
    - Building our customized Sparkle 1.27.3 from source:
        - Checkout noah-nuebling/Sparkle:master (including submodules)
        - Run `make release`
        - Extract Sparkle.framework from `Sparkle-1.27.3.tar.xz`
    - Also see:
        - My pull request for the release-notes-border-changes which was rejected, but maintainer Zorg kindly gave useful tips and explained advantages of Sparkle 2: https://github.com/sparkle-project/Sparkle/pull/2740
        - My commit messages inside noah-nuebling/Sparkle:master
    - Why fork Sparkle 1 and not upgrade to Sparkle 2?
        - We're customizing Sparkle 1 since that's currently less work than upgrading to Sparkle 2 and Sparkle 1 still works fine. I haven't really looked into how hard upgrading to Sparkle 2 would be.  
