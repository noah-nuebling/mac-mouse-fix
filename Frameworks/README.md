
- This folder is for manually added (copy pasted) frameworks
- In the update-feed branch, we're using command line tools from the Sparkle project. 
   -> It might be good if the copy of the Sparkle project in update-feed is the same version as Sparkle.framework in this branch. (And to also keep stuff in sync with other active development branches, like the version-2 branch, and master branch)

- Originally, we used Sparkle 1.26.0
- In 21. May 2024, we switched to the latest Sparkle 1.27.3 (On both `version-2` (MMF 2) and `master` (MMF 3) branches)
    - We decided against using SPM, because I feel like this gives me more control and transparency? Maybe on MMF 3 it makes more sense to use SPM, since we're already using it there?

