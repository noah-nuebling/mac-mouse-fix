This repo makes it easier to publish updates to Mac Mouse Fix. I documented it here to hopefully help people who want to adopt a similar system for their app.

# Overview

This repo contains the script `generate_appcasts` which can automatically create appcast.xml files to be read by the Sparkle updater framework based on GitHub releases.
That way you can have your in-app updates hosted through GitHub releases. 
This is super handy, because that way you can have all your downloads and update notes in one, easy to maintain place, making it very easy to publish a new update.

Another benefit of using GitHub releases for everything, is that you'll get download counters for free without resorting to Google Analytics or another tracker.\
This repo contains the script `stats` to easily display and record download counts for your GitHub releases.

`generate_appcasts` creates 2 appcast files. `appcast.xml` which contains only stable releases and `appcast-pre.xml` which contains prereleases as well. This allows you to let users opt-in to beta testing your app.

Update notes will be automatically generated based on your GitHub Release's descriptions. The style is neutral, supports dark mode, and it's easy to adjust.

# Tutorial

You can use this repo with the following terminal commands:

- `python3 generate_appcasts` \
to generate the `appcast.xml` and `appcast-pre.xml` files \
    (`appcast.xml` will only contain stable releases, while `appcast-pre.xml` will also contain prereleases)

- `cat test.md | pandoc -f markdown -t html -H update-notes.css -s -o test.html; open test.html` \
to test `update-notes.css`

- `python3 stats` \
to see how many times your releases have been downloaded at this point

- `python3 stats record` \
to record the current download counts to `stats_history.json`

- `python3 stats print` \
to display the recorded download counts from `stats_history.json`

- `./update` \
  To
  - Generate new appcasts
  - Record stats 
  - Commit and push everything

To adopt this stuff for your own app you'll want to change the following things: (Untested)
- Adjust `generate_appcasts`, by 
  - Replacing the paths and URLs at the top, to reflect your repo URL, app bundle name, ...
  - Adjust the code further to fit your needs. 
    - The script is written for a simple app bundle that's shipped in a zip file, if you ship in a dmg or something you'll have to adjust it
    - The code involving `prefpane_bundle_name` is only there because my app moved from being a prefpane to being a normal app bundle in the past. You'll probably want to remove it.
    - My app isn't signed through the Apple Developer Program nor Notarized. If yours is, then you might need to adjust other things about the script.
    - There are probably other things I can't think of right now.
- Adjust `update-notes.css` to your liking
- Replace the repo URL at the top of the `stats` script if you want to use it

To use the automatically generated appcastf files from within your macOS app you can use these URLs:
  - https://raw.githubusercontent.com/[owner]/[repo]/update-feed/appcast.xml
  - https://raw.githubusercontent.com/[owner]/[repo]/update-feed/appcast-pre.xml

To publish a new update you would then:
- Create a GitHub release for the new update
- Checkout this repo / branch and run `generate_appcasts`
- Commit and push the changes that were made to the appcast files.
- (Alternatively you can just run `./update`, which will run generate appcasts, record stats, and then push the changes to remote automatically.)
- If everthing went well, your update will now show up in-app through Sparkle!

# Notes

- Every time you run `generate_appcasts`, it will generate the appcasts from scratch. For that it needs to download *all* GitHub releases which can be very slow. It needs to download the releases primarily to sign them for Sparkle. It will also unzip the downloaded releases and then access their Info.plist files to read the bundle version and the minimum compatible macOS version.\
All of this is very inefficient, but it's fast enough for Mac Mouse Fix for now. In the future I might add a mode where only the latest release is processed to speed things up.
- Use a URL like `https://github.com/[owner]/[repo]/releases/latest/download/[AssetName].zip` to link to your latest release download from an external website.
- See the [Sparkle docs](https://sparkle-project.org/documentation/) for more about appcasts.
