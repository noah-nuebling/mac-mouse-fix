
- If you update or refactor Sparkle, make sure to update the `generate_appcasts.py` script. It's hardcoded to reference `Frameworks/Sparkle-1.26.0`
- In the main branches (master and feature-remap currently), I use Sparkle.framework, which is derived from the Sparkle-1.26.0 folder in this branch. It might be good to keep them in sync.

History:
- Originally, we used Sparkle 1.26.0
- On 21. May 2024 we updated to 1.27.3
  - At the time of writing, we also updated the `version-2` branch to 1.27.3, but haven't yet updated the master branch and other branches.