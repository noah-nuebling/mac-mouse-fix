
This is a dedicated branch for housing appcast files which tell the Sparkle Updater Framework what to update to etc.

I'm not sure if this is better than having this in the master branch

Pro master branch
- generate_appcasts.py can access project files easily. We don't need this currently but we very we'll might. We actually meant to use that, but we didn't manage to. So we're substituting with downloading all releases, which might be slower. We could probably still check out the master or another branch to look at the files, even if the script lives in this branch, though.
- We (maybe) have the chance of interacting with Xcodes environment variables more easily. However I tried that, and didn't manage to. It's super hacky to access them from an external script

Pro separate update-feed branch
- Cleaner and more separated
- The update feed can contain updates from all branches, so it's a little arbitrary to put it into master. This is actually sort of a good argument I feel. I'mma leave it here
- The script uses git stash currently, so we require the working tree being clean to run it, so we need to commit everytime we want to run it which is pretty annoying. I guess the risk to losing something by accidentally stashing it is lower here, so we could ease out clean working tree policies? ... Nah that's a stupid argument