This repo makes it easier to publish updates to Mac Mouse Fix. I documented it here to hopefully help people who want to adopt a similar system for their app.

# Overview

Last updated [Mar 2025]
This repo contains the `generate_releases.py` script which;
- Downloads releases from GitHub
- Translates them
- Creates a translated mirror of the GitHub Release pages under docs/github-releases
- Creates ./appcast.xml and ./appcast-pre.xml rss feeds (containing translated release notes) - which can be displayed as app updates through the Sparkle framework.

This makes it easy to publish a new update. You simply create a new GitHub Release, and then run a script, and done!

Another benefit of using GitHub releases for everything, is that you'll get download counters for free without resorting to Google Analytics or another tracker.\
This repo contains the script `stats.py` to easily display and record download counts for your GitHub releases.

`generate_releases.py` creates 2 appcast files. `appcast.xml` which contains only stable releases and `appcast-pre.xml` which contains prereleases as well. This allows you to let users opt-in to beta testing your app.

Update notes will be automatically generated based on the GitHub Releases' body texts. The styling is neutral, supports dark mode, and is easy to adjust in `html-assets/style.html`

---

**Update [Mar 2025]:**

I wrote this Readme when the scripts here were quite simple, since I thought other devs might wanna use this as a template, but we've now added relatively complex features like AI Translation, visualization of the download numbers and reliance on our mac-mouse-fix-scripts repo as a submodule - so I probably wouldn't recommend using this as a template anymore, as it's relatively specific and complicated.

# General Usage

You can use this repo with the following terminal commands:

- `./run stats` \
  to see how many times your releases have been downloaded at this point according to the GitHub API.

- `./run stats record` \
  to record the current download counts from the GitHub API to `stats_history.json`

- `./run stats print` \
  to display the recorded download counts from `stats_history.json`

- `./run stats plot` \
  to visualize the recorded stats

- `./run stats plot <versions to plot>` \
  to visualize the recorded stats for specific app versions.

- `./run generate_releases` \
  to generate the `appcast.xml` and `appcast-pre.xml` files \
    (`appcast.xml` will only contain stable releases, while `appcast-pre.xml` will also contain prereleases)

- `./update` \
  To
  - run `./run generate_releases`
  - run `./run stats record`
  - Commit and push everything

The workflow for publishing a new update is:
- Create a GitHub release for the new update
- Checkout this repo / branch and run `./update`.
- Result:
  - Localized GitHub Releases will appear at https://github.com/noah-nuebling/mac-mouse-fix/tree/update-feed/docs/github-releases
  - The update will now show up in the app (with localized release notes)

# Testing

### To test `update-notes/style.css`: [Feb 2025]
Simply run the command at the top of test.md

### To test `appcast.xml` [Feb 2025]
- Run `./generate_releases --test-mode` which will set the 'base_url' to `http://127.0.0.1:8000` and then generate new appcast files.
- Host the folder containing this repo on a local server at `http://127.0.0.1:8000` by running `python3 -m http.server 8000`
- Inside the MMF source code, set `kMFUpdateFeedRepoAddressRaw` to `http://127.0.0.1:8000`, also update the `SUFeedURL` value in Info.plist accordingly.
- Turn off security by going to mainApp's Info.plist and setting NSAppTransportSecurity.NSAllowsArbitraryLoads = YES
- If necessary, lower the version string and build number of MMF such that it will display some older release as an update.
- Build and run the app. It should now retrieve and display updates straight from the local appcast files.
    
Background: `file://` and `localhost:` URLs are forbidden by Sparkle so we need to do this stuff to trick it into accepting a local appcast. (As of [Feb 2025])

# Other

Download link for latest release:
  Use a URL like `https://github.com/[owner]/[repo]/releases/latest/download/[AssetName].zip` to link to your latest release download from an external website. Downloads from that external website will also count towards your GitHub Releases' download counts.

Reference:
  Also see the [Sparkle docs](https://sparkle-project.org/documentation/) more about appcasts and other things

On timestamps:
  On Monday Jan 10 22 I changed the timestamps to record in UTC time instead of local time, so all the timestamps after around 12 pm that day are shifted forward by 8 hours or so compared to the earlier ones. At some point in August when I flew from Europe to the US the timestamps should also be shifted. 

The generated appcast files are queried by Mac Mouse Fix to find new upates.
  
  MMF is hardcoded to use these URLs:
  - https://raw.githubusercontent.com/noah-nuebling/mac-mouse-fix/update-feed/appcast.xml
  - https://raw.githubusercontent.com/noah-nuebling/mac-mouse-fix/update-feed/appcast-pre.xml