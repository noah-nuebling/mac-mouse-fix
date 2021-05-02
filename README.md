# About

This repo contains the script `generate_appcasts.py` which can automatically create appcast.xml files to be read by the Sparkle updater framework based on GitHub releases.
That way you can have your apps updates be hosted by github releases.

See the [Sparkle docs](https://sparkle-project.org/documentation/) for more about appcasts.

Every time you run it, `generate_appcasts.py` will download all GitHub releases. It needs to do this to sign the releases for Sparkle. It will also unzip the releases to access their Info.plist files.\
This is very inefficient, but it's fast enough for me for now. In the future I might add a mode where it only processes the latest release to speed things up.

# Tutorial


You can use this repo with the following terminal commands:

- `python3 generate_appcasts.py` \
to generate the `appcast.xml` and `appcast-pre.xml` files \
    (`appcast.xml` will only contain stable releases, while `appcast-pre.xml` will also contain prereleases)

- `cat test.md | pandoc -f markdown -t html -H update-notes.css -s -o test.html; open test.html` \
to test `update-notes.css`

- `python3 print_download_counts.py` \
to see how many times your releases have been downloaded.

To adopt this for your own app you'll want to change the following things: (Untested)
- Adjust `generate_appcasts.py`, by 
  - Replacing the paths and URLs at the top
  - Adjust the code further to fit your needs. 
    - The script is written for a simple app bundle that's shipped in a zip file, if you ship in a dmg or something you'll have to adjust it.
    - The code involving `prefpane_bundle_name` is only there because my app moved from being a prefpane to being a normal app bundle. You'll probably want to remove it.
    - Maybe other things I can't think of.
- Adjust `update-notes.css` to your liking
- Replace the URL in `print_download_counts.py` if you want to use that script.


To use the automatically generated appcasts from within your macos app you can use these URLs:
  - https://raw.githubusercontent.com/[owner]/[repo]/update-feed/appcast.xml
  - https://raw.githubusercontent.com/[owner]/[repo]/update-feed/appcast-pre.xml

To publish a new update:
- Create a GitHub release for the new update
- Checkout this repo / branch and run `generate_appcasts.py`
- Commit and push the new appcast files.