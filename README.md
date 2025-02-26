This repo makes it easier to publish updates to Mac Mouse Fix. I documented it here to hopefully help people who want to adopt a similar system for their app.

# Overview

This repo contains the script `generate_appcasts` which can automatically create appcast.xml files to be read by the Sparkle updater framework based on GitHub releases.
That way you can have your in-app updates hosted through GitHub releases. 
This is super handy, because that way you can have all your downloads and update notes in one, easy to maintain place, making it very easy to publish a new update.

Another benefit of using GitHub releases for everything, is that you'll get download counters for free without resorting to Google Analytics or another tracker.\
This repo contains the script `stats` to easily display and record download counts for your GitHub releases.

`generate_appcasts` creates 2 appcast files. `appcast.xml` which contains only stable releases and `appcast-pre.xml` which contains prereleases as well. This allows you to let users opt-in to beta testing your app.

It also creates update notes under `update-notes/html/` – these are included int the appcast files by reference.

Update notes will be automatically generated based on the GitHub Releases' body texts. The styling is neutral, supports dark mode, and is easy to adjust in `update-notes/style.html`

# Usage

You can use this repo with the following terminal commands:

- `./stats` \
  to see how many times your releases have been downloaded at this point according to the GitHub API.

- `./stats record` \
  to record the current download counts from the GitHub API to `stats_history.json`

- `./stats print` \
  to display the recorded download counts from `stats_history.json`

- `./stats plot` \
  to visualize the recorded stats

- `./stats plot <versions to plot>` \
  to visualize the recorded stats for specific app versions.

- `./update` \
  To
  - run `./generate_appcasts`
  - run `./stats record`
  - Commit and push everything

- `./generate_appcasts` \
  to generate the `appcast.xml` and `appcast-pre.xml` files \
    (`appcast.xml` will only contain stable releases, while `appcast-pre.xml` will also contain prereleases)

The workflow for publishing a new update is:
- Create a GitHub release for the new update
- Checkout this repo / branch and run `./update`.
- If everything went well, the new update will now show up in your app!

# Testing

### To test `update-notes/style.css`: [Feb 2025]
Simply run the command at the top of test.md

### To test `appcast.xml` [Feb 2025]
- Run `./generate_appcasts --test-mode` which will set the 'base_url' to `http://127.0.0.1:8000` and then generate new appcast files.
- Host the folder containing this repo on a local server at `http://127.0.0.1:8000` by running `python3 -m http.server 8000`
- Inside the MMF source code, set `kMFUpdateFeedRepoAddressRaw` to `http://127.0.0.1:8000`, also update the `SUFeedURL` value in Info.plist accordingly.
- If necessary, lower the version string and build number of MMF such that it will display some older release as an update.
- Build and run the app. It should now retrieve and display updates straight from the local appcast files.
    
Background: `file://` and `localhost:` URLs are forbidden by Sparkle so we need to do this stuff to trick it into accepting a local appcast. (As of [Feb 2025])

# Other

Optimization:
  Every time you run `generate_appcasts`, it will generate the appcasts from scratch. For that it needs to download *all* GitHub releases which can be very slow. It needs to download the releases primarily to sign them for Sparkle. It will also unzip the downloaded releases and then access their Info.plist files to read the bundle version and the minimum compatible macOS version.\
  All of this is very inefficient, but it's fast enough for Mac Mouse Fix for now. In the future I might add a mode where only the latest release is processed to speed things up.

Download link for latest release:
  Use a URL like `https://github.com/[owner]/[repo]/releases/latest/download/[AssetName].zip` to link to your latest release download from an external website. Downloads from that external website will also count towards your GitHub Releases' download counts.

Reference:
  Also see the [Sparkle docs](https://sparkle-project.org/documentation/) more about appcasts and other things

On timestamps:
  On Monday Jan 10 22 I changed the timestamps to record in UTC time instead of local time, so all the timestamps after around 12 pm that day are shifted forward by 8 hours or so compared to the earlier ones. At some point in August when I flew from Europe to the US the timestamps should also be shifted. 

The generated appcast files are queried by Mac Mouse Fix to find new upates.
  
  In MMF we're using these URLs:
    - https://raw.githubusercontent.com/noah-nuebling/mac-mouse-fix/update-feed/appcast.xml
    - https://raw.githubusercontent.com/noah-nuebling/mac-mouse-fix/update-feed/appcast-pre.xml

# For others who want to adopt this

(I don't think anybody actually wants to do this, it's just some sloppy python scripts.)

To adopt this stuff for your own app you'll want to do the following things: (Untested)
- Adjust `generate_appcasts`, by 
  - Replacing the paths and URLs at the top, to reflect your repo URL, app bundle name, ...
  - Adjust the code further to fit your needs. 
    - The script is written for a simple app bundle that's shipped in a zip file, if you ship in a dmg or something you'll have to adjust it
    - The code involving `prefpane_bundle_name` is only there because my app moved from being a prefpane to being a normal app bundle in the past. You'll probably want to remove it.
    - My app isn't signed through the Apple Developer Program nor Notarized. If yours is, then you might need to adjust other things about the script.
      - Update [Feb 2025] Not true anymore. MMF is notarized.
    - There are probably other things I can't think of right now.
- Adjust `update-notes/style.css` and `update-notes/script.js` to your liking.
- Replace the repo URL at the top of the `stats` script if you want to use it.
- Possibly install some command line tools this depends on. I recommend you use [Homebrew](https://brew.sh/) for that. (Update [Feb 2025]: Everybody knows this what is this ahahdhfasf)