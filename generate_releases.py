# Imports

import sys
import os
import shutil
# import requests # Only ships with python2 on mac it seems. Edit: So what? We could just install it right?
import urllib.request
import urllib.parse

from pathlib import Path
import json
import textwrap
from pprint import pprint
import re
import anthropic
import argparse
import hashlib
from typing import Callable
import tempfile
import mfutils
from mfutils import deptracked, mfdedent, HumanBytes
import mflocales
from dataclasses import dataclass

from babel import dates as bdates
import datetime

"""
[Mar 2025] Downloads MMF Releases from GitHub, and based on those:
    1. Generates 2 appcast rss feed files for Sparkle
    2. Creates markdown documents that serve as translations of the GitHub Release pages

TODO: [Mar 2025]
    - [x] Integrate this with our scripts repo
        - [x] Use it to validate the locales
            - We can enforce that this repo should be in a folder like mac-mouse-fix-update-feed. The mac-mouse-fix repo, on the master branch, should be a in a sibling folder – Then we can read the locales from the xcode project.
        - [x] Replace subprocess and os.system calls with our 'safe' (non-shell) custom implementation. (Now that we're passing LLM output, shell=True isn't safe anymore I think.)
    - [x] For each locale, create folder of localized 'releases' md docs which mirror the GitHub releases page (including asset-download-links)
    - [x] Rename from generate_appcasts to something that reflects that it also creates 'release' documents now.
    - Anthropic API: 
        - Look into Batch Processing:   https://docs.anthropic.com/en/docs/build-with-claude/batch-processing
        - Look into Prompt Caching:     https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching
        - Optimize Prompt / do 'prompt engineerig' (?)
        - Optimize Model choice (?)
        - Optimize Cost (?)
            - I'll only run this once in a while, so it probably doesn't matter.
        - See if there are other API params to optimize (?)
        - Optimize latency (?)
            - Not that important but current latency of like 30 s per request is annoying to work with. [Mar 2025]
    
    Update: (late [Mar 2025])
        - [x] Add locale picker at top of release documents – reuse code for for creating locale picker when compiling human-translated markdown documents
        - [x] Cleanup file/folder structure for all the new files we're creating now.
        - [x] Cleanup comments and stuff maybe
        - [x] Implement system to link between release-note documents while preserverving language choice.
        - [x] Actually create the appcasts.xml file in such a way that it references all the new translated update-notes html files.
        - [ ] Perhaps implement 'dynamic glossary' idea which we described in a comment somewhere inside generate_releases.
        - [ ] Document/think about problem I just noticed: The refund-email-link we included in several recent release notes is not translatable
            with the systems we've planned.
            I think it's the only user-facing string currently hosted in the redirection service.
            ... Thought: I think like 1 person ever sent us a refund request via that link (?) Perhaps shouldn't spend too much energy on this.

Protocol:  
  - (early) [Mar 2025]
        I machine translated 3.0.3 update notes using the following parameters:
            model:          claude-3-5-sonnet-20241022
            temperature:    0
            system: 
                You are an accurate, elegant translator. Requests that you handle follow the pattern:
                `language_code: <some ISO language code>\\nenglish_text: <some english text>`
                You will reply with the translation of the english text into the language specified by the language code. You do not reply with any other information. Only the translation.
                Context: The text you translate is written by the developer of an indie app. The text is intended to be read by users of said indie app. To be appropriate for this context, the text should not be overly formal. For example, when translating to German, use informal 'du' instead of formal 'Sie'.
            input: 
                f"language_code: {lcode}\nenglish_text: {release_notes_cleaned}"
                On {lcode}:
                    - I fed it 29 language_code's, extracted from the 'knownRegions' in the MMF Xcode project. (from the feature-strings-catalog branch)
                On {release_notes_cleaned}:
                    - Release notes were downloaded straight from the GitHub releases API, I then also stripped out HTML comments since those don't need to be translated.

        I then asked Claude 3.7 (with extended thinking) to thoroughly review the translations.
            - It said they were of excellent quality.
            - It noted that Korean, Japanese, and French use polite forms, which German uses informal 'du'. 
                - I asked it whether that makes sense and it explained that this culturally appropriate and matches trends seen in tech documentation and communication by tech companies.

        I also personally reviewed the German versions:
            - The translations sound very good and natural. Some stuff sounds weird, but I think that's mostly cause my original English texts aren't super well written. (I felt it was very apologetic and verbose in some places. I just felt like who caressss when reading it. But that's not the LLM-translator's fault.)

        -> It seems like this setup produces very good translations.
            (We haven't iterated on the prompt or other parameters, but I think we don't have to since this is good enough.)

        Problems: 
        1. When we use very specific terms mirroring UI elements in the app, that is unlikely to get accurately translated.
            - Solution ideas:
                1. Manual glossary: 
                    Have human translators of the main app create a glossary somehow
                2. Disclaimer: 
                    Mark the update notes as 'machine translated' and 'possibly containing some inaccuracies'
                    -> Other reason to do this: I think people generally appreciate knowing whether the content they look at is AI generated.
                3. Flood LLM context: 
                    Feed all the (human generated) translations from the app and the website into the LLM's context window
                    - Problems: 
                        - Bigger load on the API (Should probably use 'prompt caching'.)
                        - Might degrade the quality if we clutter up the context window
                        - Not sure how handle older UI elements get removed? Then we can't easily update older notes anymore I think. I guess we could feed it different versions of the human generated translations but then we won't be able to employ prompt caching I think and it would complicated everything.
                        - For a lot of the strings in the main MMF app, the primary context for the translators stems from the autogenerated screenshots with markers for where the specific string appears in the screenshot - Might not be feasible to feed this context to the LLM.
                        -> Even with these problems, feeding the human translations as context might still bring worth-it quality improvements.
                4. 'Dynamic glossary':
                    - In this script we'd maintain a 'glossary_keys' list and then we'd extract the English original + translations for those keys from the .xcstrings files 
                      in the 'mac-mouse-fix' repo and paste them into the LLM's context. 
                    -> This should be easy to maintain and make translations quality really good.
                    - Problems:
                        - When older strings referenced by the glossary_keys get removed, we might need special handling -> Could probably just hardcode the latest commit where a specific string is available.

                -> Conclusion: Start with 2. (Disclaimer) and perhaps add 4. (Dynamic glossary) later to improve quality.

    - (late) [Mar 2025]: 
            Updated the prompt with a localizer_hint, plus XML markup:
                System Prompt: 
                    You are an accurate, elegant translator. Requests that you handle follow the pattern:
                    `<language_code>[some ISO language code]</language_code><localizer_hint>[some hint for you]</localizer_hint><english_text>[some english text]</english_text>`
                    You will reply with the translation of the english text into the language specified by the language code. You do not reply with any other information. Only the translation.
                    The localizer hint will either provide additional context to help you with your translation, or it will be '<None>', in which case you can ignore it.
                    Please note: The text you translate is written by the developer of an indie app. The text is intended to be read by users of said indie app. To be appropriate for this context, the text should not be overly formal. For example, when translating to German, use informal 'du' instead of formal 'Sie'.
                User Prompt:
                    rf"<language_code>{language_code}</language_code><localizer_hint>{localizer_hint}</localizer_hint><english_text>{english_text}</english_text>"
            
            Reasoning behind these changes:
                - The localizer_hint is necessary to accurately translate very short custom strings like 'Assets'
                - The XML makes things unambiguous if the localizer hint contains `\n` (which was the separator before)
            
            Other stuff I did:
                - I tried twiddling with the prompt a bit but didn't make it better
                - I used the Anthropic console 'improve prompt' feature. I told it to make the translations more natural. It wrote a very long prompt. But I think the results were less natural if anything.
                -> I think our prompt already produces close-to-optimal results
            
            Note:
                - Explicitly telling the LLM that the localizer_hint may be '<None>' seemed to improve results (but I don't remember how) (Explanation idea: If the input already contains mistakes the output is more likely to, as well.)
    - (even later) [Mar 2025]
        Updated system prompt with a hint to preserve markup:
            You are an accurate, elegant translator. Requests that you handle follow the pattern:
            `<language_code>[some ISO language code]</language_code><localizer_hint>[some hint for you]</localizer_hint><english_text>[some english text]</english_text>`
            You will reply with the translation of the english text into the language specified by the language code. You do not reply with any other information. Only the translation.
            The localizer hint will either provide additional context to help you with your translation, or it will be '<None>', in which case you can ignore it.

            Please note:
            - The text you translate is written by the developer of an indie app. The text is intended to be read by users of said indie app. To be appropriate for this context, the text should not be overly formal. For example, when translating to German, use informal 'du' instead of formal 'Sie'.
            - Your output will be rendered as Markdown or HTML. Please maintain all relevant formatting characters as they appear in the source text, including backslashes at the end of a line (\), asterisks (*), and any other special characters that serve as markup to determine the text formatting.
            - Maintain all placeholders exactly as they appear in the source text (like {variable_name}, %s, etc.)
            - Remember to not reply with any other information except for your translation.

        Reasoning behind these changes:
            - I noticed that, for some languages like Catalan (ca), the model consistently forgot the backslash at the end of the line in the `release-notes.disclaimer` string. The explicit hint seems to fix this.
            - Added another hint to prevent similar mistakes around placeholders (format specifiers). (Not sure this improves things)
            - I also added a final 'only reply with translation' hint at the end just to make sure it doesn't forget among all the other info (Not sure this improves things)
"""

# Validate location
assert os.path.basename(os.getcwd()) == 'mac-mouse-fix-update-feed', f"Running from unexpected folder {os.getcwd()}. Explanation: [Mar 2025] This script currently lives in the update-feed branch of the main mac-mouse-fix repo, but the script should be run from a separate folder next to the main repo folder, so it can access the Mac Mouse Fix source code."

# Parse args
argparser = argparse.ArgumentParser("")
argparser.add_argument('--test-mode', action=argparse._StoreTrueAction)
argparser.add_argument('--anthropic-api-key', default=os.environ.get("ANTHROPIC_API_KEY"))
args, unrecognized_args = argparser.parse_known_args()
if unrecognized_args:
    print(f"Ignoring unrecognized args: {unrecognized_args}")

# Test mode
TEST_MODE = False
if len(sys.argv) >= 2 and sys.argv[1] == '--test-mode':
    print('Running in --test-mode')
    TEST_MODE = True

# Constants
#   Paths are relative to project root or to each other.

# URLs
url_releases_api        = "https://api.github.com/repos/noah-nuebling/mac-mouse-fix/releases"

if TEST_MODE:
    url_base            = "http://127.0.0.1:8000"       # For testing. Run `python3 -m http.server 8000` to serve this repo at that url. Background: `file://` and `localhost:` URLs are forbidden by Sparkle, this is a workaround. Read more in README.md. Stand [Feb 2025]
else:
    url_base            = "https://raw.githubusercontent.com/noah-nuebling/mac-mouse-fix/update-feed"

if False:
    proxy_url               = "https://noah-nuebling.github.io/mmf-update-notes-proxy/?url="
    raw_github_url          = "https://raw.githubusercontent.com/noah-nuebling/mac-mouse-fix/master"

# Output paths/folders
path_appcast                    = "appcast.xml"                             # Path to the appcast for stable releases
path_appcast_pre                = "appcast-pre.xml"                         # Path to the appcast for prereleases

url_appcast                     = f"{url_base}/{path_appcast}"              # This gets included as a link in appcast.xml. Not sure what it does.
url_appcast_pre                 = f"{url_base}/{path_appcast_pre}"

folder_docs                     = "docs"
folder_github_releases          = f"{folder_docs}/github-releases"          # This where translations of GitHub releases (md) go 
folder_update_notes_html        = f"{folder_docs}/update-notes-html"        # This is where the html update notes go. They are generated from the .md update notes downloaded off GitHub. [Mar 2025] appcast.xml will reference these html update notes via <sparkle:releaseNotesLink>, so these are displayed directly to the user in the Sparkle update window.

# Assets
folder_html_assets              = "html-assets"
path_css_file                   = f"{folder_html_assets}/style.css"         # The css file referenced by the html update notes.
path_js_file                    = f"{folder_html_assets}/script.js"                  

# Implementation detail paths/folders
folder_custom_strings                   = f"{folder_docs}/intermediates/custom-strings"
folder_update_notes_markdown            = f"{folder_docs}/intermediates/update-notes-md"             # This is where the raw md update notes go. The English versions are extracted straight from GitHub releases, and the translations are automatically generated by this script. [Mar 2025] These serve as a cache so we can avoid (slowly) re-translating unless necessary.
folder_ghasset_cache                    = "app-bundles"
folder_downloads                        = "generate_releases_downloads"                     # This is were we download old app versions to, and then unzip them. We want to delete this on exit. (Update: [Mar 2025] also using this to store other temporary data now)

path_deptracker_docs                    = f"{folder_docs}/dependency_tracker.json"
path_deptracker_ghasset                 = f"{folder_ghasset_cache}/dependency_tracker.json"
path_tmp_file_html_header_includes      = f"{folder_downloads}/html_header_includes.html"   # Temp file for storing html headers for update notes. I guess we're using downloads_folder as a general 'tmp' folder here.
path_sparkle_project                    = "Frameworks/Sparkle-1.27.3"                       # Need this to use Sparkles code-signing tool # This is dangerously hardcoded # Might be smart to keep this in sync with the Sparkle version in the app.

subpath_info_plist_app                  = "Contents/Info.plist"                             # Where to look fo the Info.plist file within the unzipped app bundle
filename_app_bundle                     = "Mac Mouse Fix.app"                               # This is the name of the app bundle after unzipping it
filename_prefpane_bundle                = "Mouse Fix.prefpane"                              # App has been renamed, this is the old name

# Dynamic paths/folders
current_directory = os.getcwd()
download_folder_absolute = os.path.join(current_directory, folder_downloads)

# Locale IDs
#   Codes for the languages to translate the update notes into. 
#   Keep in-sync with 'knownRegions' in project.pbxproject of mac-mouse-fix and mac-mouse-fix-website repos:
#       https://github.com/noah-nuebling/mac-mouse-fix/blob/b3c2cb85f81e8637d51b533a43bbc99084e85e89/Mouse%20Fix.xcodeproj/project.pbxproj#L7954
#   These are in Apple's format. See: https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPInternational/LanguageandLocaleIDs/LanguageandLocaleIDs.html

source_locale = 'en'

locales = [
    'en',
    'de',
    "zh-Hant",
    "zh-HK",
    "zh-Hans",
    'ko',
    'vi',
    'ar',
    'ca',
    'cs',
    'nl',
    'fr',
    'el',
    'he',
    'hu',
    'it',
    'ja',
    'pl',
    "pt-BR",
    "pt-PT",
    'ro',
    'ru',
    'es',
    'sv',
    'tr',
    'uk',
    'th',
    'id',
    'hi',
]

# Validate locales
#   Discussion: [Mar 2025] 
#       The MMF project currently has 3 repos with localizable strings: mac-mouse-fix, mac-mouse-fix-website, and mac-mouse-fix/update-feed (Which lives inside a branch of mac-mouse-fix but I think of as 'functionally its own repo')
#       For things to work smoothly, all these 3 should have the same locales. We have some asserts to help us keep them in-sync:
#           - For mac-mouse-fix and mac-mouse-fix-website (Which are human-translated), we check that their locales are synced in the script that exports and uploads the strings for human translators.
#           - For mac-mouse-fix/update-feed (Which is AI-translated), we check that the locales match the main mac-mouse-fix repo  – right here.
#       Meta: 
#           [Mar 2025] Maybe this explanation should be moved to some central place since it concerns all the localizable repos in the MMF project
print(f"Validating locales against main repo...")
def _validate_locales():
    p = os.path.join('../mac-mouse-fix', mflocales.path_to_xcodeproj['mac-mouse-fix'])
    assert os.path.exists(p), f"Wanted to validate locales, but main repo Xcode project not found at expected location: {p}"
    loc_dev, loc_trans = mflocales.find_xcode_project_locales(p)
    assert loc_dev == source_locale,                            f"Source locale doesn't match main repo: '{loc_dev}' vs '{source_locale}'"
    assert set(loc_trans) == set(locales)-{source_locale},      f"Translation locales don't match main repo. Symmetric difference: {set(loc_trans).symmetric_difference(set(locales))}"
_validate_locales()

# Sort locales
locales = mflocales.sorted_locales(locales, source_locale)

# Stuff for reading directly from the project source files. 
#   We went over to downloading and unzipping all old bundles instead.
#   Note: 
#       Accessing Xcode environment variables is night impossible it seems
#       The only way to do it I found is described here:
#         https://stackoverflow.com/questions/6523655/how-do-you-access-xcode-environment-and-build-variables-from-an-external-script
#         And that's not feasible to do for old versions.

if False:
    info_plist_path = "App/SupportFiles/Info.plist"
    base_xcconfig_path = "xcconfig/Base.xcconfig"
    files_to_checkout = [info_plist_path, base_xcconfig_path]

#
# Main function
#

def generate():

    try:

        # Check if there are uncommited changes
        #   Note: This script uses git stash several times, so they'd be lost Update: [Feb 2025] We don't seem to be using git stash anymore. We can probably turn this off. (./update still checks for uncommited changes, so that should be safe.)
        if TEST_MODE or True:
            pass
        else: 
            uncommitted_changes = mfutils.runclt('git diff-index HEAD --')
            if (len(uncommitted_changes) != 0):
                raise Exception('There are uncommited changes. Please commit or stash them before running this script.')

        # Main logic
        
        # Call GH API
        with urllib.request.urlopen(url_releases_api) as request:
            releases = json.load(request)

        # Make downloads folder
        os.makedirs(download_folder_absolute, exist_ok=True)

        # Prepare text to include in the html header of all release notes.
        #   (We have to write this to a file because I don't know how else to pass this to pandoc.)
        
        if True: 
            # Approach 1: Reference the css/js files
            #   This only works through githack, because raw.githubusercontent serves the css and js file with text/plain mime type.
            #   
            #   Meta: Is this better than embedding the css/js files directly? 
            #       Contra: The client will have to download the css/js either way to correctly display the update notes. So that's not better.
            #       Pro: The html files inside update-notes/html will be smaller, since they don't all contain a copy of our css/js.
            #       Pro: The *content* in the html files can be updated and diff'd independently of the js/css. This might make it easier to programmatically check for content changes, which might be useful once we translate the update-notes with the help of an LLM but don't wanna regenerate translations if the content didn't change.
            #       Contra: This might **slow down** loading of update notes because we need to download 3 different files through githack. 
            #           But based on [Feb 2025] testing, the slow down is not noticable. Specifically, I saw that: 1. BetterDisplay, another Sparkle app also take a bit to load the notes 2. When you load a note in the browser, it's instant, despite css and js being served through githack. -> So I don't feel like githack makes a difference.
            
            html_header_includes = mfdedent("""
                <link rel="stylesheet" href="{css_slot}"/>
                <script src="{js_slot}"></script>
            """).format(
                css_slot = apply_githack(f'{url_base}/{path_css_file}'),
                js_slot = apply_githack(f'{url_base}/{path_js_file}')
            )
        else: 
            # Approach 2: include the css/js files directly
            html_header_includes = mfdedent("""
                <style> 
                {css_slot} 
                </style>
                <script> 
                {js_slot} 
                </script>
            """).format(css_slot = textwrap.indent(Path(path_css_file).read_text(), 4 * ' '), 
                        js_slot = textwrap.indent(Path(path_js_file).read_text(), 4 * ' '))
        
        with open(path_tmp_file_html_header_includes, 'w') as f:
            f.write(html_header_includes)

        # We'll be iterating over all releases and collecting data to put into the appcast
        appcast_items = []
        appcast_pre_items = [] # Items for the pre-release channel

        for r in releases:

            # Get short version
            short_version = r['name']
        
            # Log
            print(f'Processing release {short_version}...')

            # Get tag name
            tag_name = r['tag_name']
            
            # Get link to main GitHub releases page
            html_url = r['html_url']

            # Get release notes
            release_notes = r['body'] # This is markdown
            
            # Get publishing date
            publishing_date = r['published_at']

            # Get isPrerelease
            is_prerelease = r['prerelease']

            # Get path to cached English release notes
            md_path_src = getpath_release_notes_md(source_locale, tag_name)

            # Remove HTML comments from release notes
            #   Since those don't have to be translated (And would cost a bunch of extra Claude tokens)
            release_notes = re.sub(r"<!--.*?-->", "", release_notes, count=0, flags=re.DOTALL)
            
            # Write the fresh source-language release notes to file
            p = Path(md_path_src)
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text(release_notes)

            # Update translations for release notes
            for locale in locales:
                translation_path = getpath_release_notes_md(locale, tag_name)
                _ = upget_translation(release_notes, locale, md_path_src, translation_path, do_localize_urls=True)

            # Update HTML release notes
            for locale in locales:
                
                # Get dependency paths
                md_path: str            = getpath_release_notes_md(locale, tag_name)
                disclaimer_path: str    = getpath_custom_string(locale, 'release-notes.disclaimer')

                # Get target path
                html_path: str          = getpath_release_notes_html(locale, tag_name)

                # Combine dependency paths
                source_paths = None
                if locale != source_locale:   source_paths = [disclaimer_path, md_path]
                else:                         source_paths = [md_path]
                
                # Skip if source file doesn't exist
                if not os.path.exists(md_path):
                    print(f"Not creating release document for release notes at '{md_path}' because the file doesn't exist.") # This is to let us skip certain translations during development. Shouldn't happen in production.
                    continue

                # Update dependencies (only disclaimer as of [Mar 2025])
                #   Notes: 
                #   - [Mar 2025] This will update the file at disclaimer_path, so gotta call it before the @deptracked updater below
                #   - [Mar 2025] If you change the html_url, the @deptracker won't understand that. Delete html docs to force recompute.
                disclaimer = upget_custom_string(locale, 'release-notes.disclaimer').format(gh_releases_url=html_url) 

                # Combine dependencies into HTML
                #   Note: [Mar 2025] Probably useless to use deptracker here. Probably makes things more error-prone, without meaningful speedup.
                @deptracked(path_deptracker_docs, source_paths, html_path, sources_are_files=True)
                def update_release_md_file():
                    
                    # Load translated release notes
                    release_notes = Path(md_path).read_text()

                    # Combine dependencies
                    combined_md = release_notes
                    if locale != source_locale:
                        combined_md = disclaimer + '\n\n---\n\n' + combined_md

                    # Write combined md to temp file
                    #   Notes: 
                    #       - [Mar 2025] Gotta write to file, otherwise we couldn't escape it properly for pandoc IIRC.
                    #       - [Mar 2025] Not sure we should use tempfile or our download_folder for this temp file
                    md_path_temp = tempfile.NamedTemporaryFile().name
                    Path(md_path_temp).write_text(combined_md)
                    print(f"Wrote combined markdown to '{md_path_temp}'")

                    # Convert combined md release notes to HTML 
                    release_notes_html = mfutils.runclt(
                        "pandoc"
                       f" {md_path_temp}"
                        " --from markdown --to html"
                        " --standalone"                     # Not sure what this does / if it's necessary
                       f" --include-in-header ./{path_tmp_file_html_header_includes}"
                       f" --variable lang={locale}"         # Sets the `lang` and `xml:lang` attributes on the outermost <html> element || I observed [Mar 2025] that this fixes comma (，) and period (。) alignment when Safari/Sparkle renders the Chinese docs
                        " --metadata title=''"
                        " --metadata document-css=false"    # Stops pandoc from adding some of its default inline css, but can't manage to turn that off entirely.
                        ,
                        fail_on_stderr=False
                    )

                    # Write result to file
                    p = Path(html_path)
                    p.parent.mkdir(parents=True, exist_ok=True)
                    p.write_text(release_notes_html)

                    # Return success
                    return True
                update_release_md_file()

            # Update Release documents
            #   (Create md docs mirroring GitHub releases pages (but localized)
            for locale in locales:
                
                # Skip English
                #   (The English 'release document' is just the actual GitHub Release page)
                if locale == source_locale:
                    continue

                # Get dependency paths
                md_path = getpath_release_notes_md(locale, tag_name)
                kdisclaimer = 'release.disclaimer'
                kmetadata   = 'release.metadata'
                kassets     = 'release.assets'
                source_paths = [
                    md_path,
                    getpath_custom_string(locale, kdisclaimer),
                    getpath_custom_string(locale, kmetadata),
                    getpath_custom_string(locale, kassets),
                ]

                # Skip if source file doesn't exist
                if not os.path.exists(md_path):
                    print(f"Not creating release document for release notes at '{md_path}' because the file doesn't exist.") # This is to let us skip certain translations during development. Shouldn't happen in production.
                    continue

                # Get target path
                release_doc_path = getpath_github_release(locale, tag_name)

                # Update dependencies
                disclaimer      = upget_custom_string(locale, kdisclaimer)
                metadata        = upget_custom_string(locale, kmetadata)
                assets_title    = upget_custom_string(locale, kassets)

                # Apply formatting
                disclaimer = disclaimer.format(gh_releases_url=html_url)
                metadata = metadata.format(date=ui_string_from_gh_date(locale, publishing_date))

                # Combine dependencies into release document
                #   Note: [Mar 2025] Probably useless to use deptracker here. Probably makes things more error-prone, without meaningful speedup.
                @deptracked(path_deptracker_docs, source_paths, release_doc_path, sources_are_files=True)
                def update_release_md_file() -> str:
                    
                    # Build language picker
                    #   Notes: 
                    #       - [Mar 2025] buildmd.py creates same-looking langauge picker. 
                    #           (buildmd.py builds human-translated md files, while this builds AI-translated ones)
                    #           We could reuse the code, but it feels simple enough, and would require enough refactoring, that it's not worth it
                    #
                    #       - [Mar 2025] On "Help translate Mac Mouse Fix to different languages!" link
                    #           - This is hardcoded to English here, but translated in the buildmd.py script
                    #               - The main purpose of the link inside buildmd is to inform humans how to contribute translations. For this purpose, they should speak English.
                    #               - We also planned to keep the localization guide (which it links to) in English
                    #                   (Update: Although we do have a redirection-service link for it which we should probably use, and which would add flexibility around the locale)
                    #               -> So not sure it makes sense to translate this -> Leaving it hardcoded to English for now.
                    #           - For these AI-translated documents, such a link might not be necessary at all, the only purpose of the link I could think of would be:
                    #               1. Report quality issues with translations
                    #               2. (?) Link to a central place where you can learn more about Translations of MMF
                    #               3. (?) Keep consistency with language picker in human-translated md documents.
                    #               -> Perhaps for the purpose of gathering 'quality-issue-reports' from non-English-speakers, it would make sense to translate the link, and its destination?

                    locale_picker_content = ""
                    for i, locale2 in enumerate(locales):
                        
                        is_last = i == len(locales)-1
                        langname = mflocales.locale_to_language_name(locale2, locale2, include_flag=True)
                        
                        link = None
                        if locale2 == source_locale:      
                                                                link = html_url             # English links to the actual GitHub Releases page
                                                                langname += " (GitHub)";    # [Mar 2025] Don't think we have to translate this. Especially since all language names in the picker are in that language, and this is next to the English one.
                        else:                                   link = mflocales.mmf_release_url(locale2, tag_name)

                        if locale == locale2:     locale_picker_content += f"**{langname}**"
                        else:                   locale_picker_content += f"[{langname}]({link})"
                        if not is_last:         locale_picker_content += '\\\n'

                    locale_picker = mfdedent(r"""
                        <details>
                        <summary>{current_locale_name}</summary>

                        {content}\
                        [Help translate Mac Mouse Fix to different languages!](https://github.com/noah-nuebling/mac-mouse-fix/discussions/731)
                        </details>
                        """).format(
                            current_locale_name=mflocales.locale_to_language_name(locale, locale, include_flag=True),
                            content=locale_picker_content,
                        )

                    # Build prefix
                    prefix = mfdedent(r"""
                        {language_picker}
                        <table align=><td>
                        {disclaimer}
                        </td></table>

                        <table></table>

                        # {version_name}
                        *{metadata}*

                        <br>
                        """).format(language_picker=locale_picker, disclaimer=disclaimer, version_name=short_version, metadata=metadata)
                    
                    # Get strings describing each asset
                    #   [Mar 2025] This is not localized, so we could cache it for each lang.
                    assets_content = ""
                    for i, asset in enumerate(r['assets']):

                        url  = asset['browser_download_url']
                        name = asset['name']
                        size = HumanBytes.format(int(asset['size']), metric=True, precision=1) # This is in metric (1000 B/KB), while on official GH release page it seems to be in binary (1024 B/KB) – but I don't think it'll matter to anyone.

                        if i != 0: 
                            assets_content += '\n'
                        assets_content += mfdedent(r"""
                            <tr>
                                <td><a href="{download_url}">{asset_name}</a></td>
                                <td>{asset_size}</td>
                            </tr>
                            """).format(download_url=url, asset_name=name, asset_size=size)

                    # Build suffix
                    suffix = mfdedent(r"""      
                        ---
                                      
                        <table align="start">
                        <tr>
                            <td colspan=2>
                                <b>{assets_title}</b>
                            </td>
                        </tr>
                        {assets_content}
                        </table>
                        """).format(assets_title=assets_title, assets_content=assets_content)
                    
                    # Get release notes
                    release_notes = Path(md_path).read_text()

                    # Combine
                    result = prefix + '\n\n' + release_notes + '\n\n' + suffix

                    # Write result to file
                    p = Path(release_doc_path)
                    p.parent.mkdir(parents=True, exist_ok=True)
                    p.write_text(result)

                    # Return Success
                    return True
                update_release_md_file()

            #
            # Build appcast items for this release
            #

            if False:
                # Tried to checkout each commit and then read bundle version and minimum compatible macOS version from the local Xcode source files. 
                # I had trouble making this approach work, though, so we went over to just unzipping each update and reading that data directly from the bundle

                # Get commit number
                # commit = os_system_exc(f"git rev-list -n 1 {tag_name}") # Can't capture the output of this for some reason
                commit_number = mfutils.runclt(f"git rev-list -n 1 {tag_name}")

                # Check out commit
                # This would probably be a lot faster if we only checked out the files we need
                os_system_exc("git stash")
                files_string = ' '.join(files_to_checkout)
                bash_string = f"git checkout {commit_number} {files_string}"
                try:
                    mfutils.runclt(bash_string)
                except Exception as e:
                    print(f"Exception while checking out commit {commit_number} ({short_version}): {e}. Skipping this release.")
                    continue

                # Get version
                #   Get from Info.plist file
                bundle_version = mfutils.runclt(f"/usr/libexec/PlistBuddy {info_plist_path} -c 'Print CFBundleVersion'")

                # Get minimum macOS version
                #   The environment variable buried deep within project.pbxproj. No practical way to get at this
                #   Instead, we're going to hardcode this for old versions and define a new env variable via xcconfig we can reference here for newer verisons
                #   See how alt-tab-macos did it here: https://github.com/lwouis/alt-tab-macos/blob/master/config/base.xcconfig
                minimum_macos_version = ""
                try:
                    minimum_macos_version = mfutils.runclt(f"awk -F ' = ' '/MACOSX_DEPLOYMENT_TARGET/ {{ print $2; }}' < {base_xcconfig_path}")
                except:
                    minimum_macos_version = 10.11

            # Get app asset
            # NOTE: This has a copy in stats_internal.py. Keep them in sync.
            app_assets = [asset for asset in r['assets'] if asset['name'] == 'MacMouseFixApp.zip' or asset['name'] == 'MacMouseFix.zip'] # I don't think we need `MacMouseFix.zip` here (That's the old prefpane name.)
            assert len(app_assets) <= 1, f"Found {len(app_assets)} app assets. Here are the asset names: { list(map(lambda a: a['name'], r['assets'])) }"
            if len(app_assets) == 0:
                print(f"Couldn't find asset with standard name. Falling back to first asset, named {r['assets'][0]['name']}")
                app_assets = [r['assets'][0]]
            
            # Get download link
            download_link = app_assets[0]['browser_download_url']

            # Download MMF version
            # [Mar 2025] What to use as 'source hash' for asset downloads?
            #       Minimal Testing with GitHub Releases: 
            #           - The following values in the GitHub API response stay constant, until the asset is deleted and reuploaded:
            #               - 'id', 'url', 'node_id', 'created_at'
            #           - You can also rename the asset on the GitHub Website, which will change the following fields:
            #               - 'name', 'updated_at', 'browser_download_url'
            #           - Based on GitHub API reference you can update the following fields (See: https://docs.github.com/en/rest/releases/assets?apiVersion=2022-11-28#update-a-release-asset)
            #               - 'name', 'label', 'state'
            #           (Tests performed inside https://github.com/noah-nuebling/gh-release-asset-id-test-mar-2025/releases/tag/test)
            #       
            #       -> Conclusion: Based on these tests, I think the 'id' field can be safely used as the 'source hash'. To be more strict, we might combine it with the 'updated_at' field. To be more human-readable, we could use the 'url' instead of the 'id'
            # Note [Mar 2025]:
            #   - If we rename an asset, it would get 'orphaned' by the dependency tracker and not cleaned up automatically. To fix this we could make the download_zip_path independent of the download_name. But I don't think this will ever happen, and if it happens it's easy to deal with.
            
            download_name = download_link.rsplit('/', 1)[-1]
            download_zip_path = getpath_ghasset_cache(tag_name, download_name)
            Path(download_zip_path).parent.mkdir(parents=True, exist_ok=True)
            deptracker_source_hashes = [
                f'ghasset-url:{app_assets[0]['url']}', 
                f'ghasset-updated-at:{app_assets[0]['updated_at']}'
            ]
            did_download = False
            @deptracked(path_deptracker_ghasset, deptracker_source_hashes, download_zip_path, sources_are_files=False)
            def download_mmf():                
                newfile, httpmessage = urllib.request.urlretrieve(url=download_link, filename=download_zip_path)
                nonlocal did_download; did_download = True
                return True
            download_mmf()
            
            # Log
            print(f"Process MMF asset {"(freshly downloaded)" if did_download else "(cached)"}) from '{download_link}'...")

            # Get edSignature
            signature_and_length = mfutils.runclt(f"./{path_sparkle_project}/bin/sign_update {download_zip_path}")

            # Unzip MMF version
            os_system_exc(f'ditto -x -k --sequesterRsrc --rsrc "{download_zip_path}" "{folder_downloads}"') # This works, while subprocess.check_output() doesn't for some reason || Update: [Mar 2025] Using runclt() now, instead of subprocess.check_output(). Haven't tested that here. 

            # Find app bundle in archive
            #   Maybe we could just name the unzipped folder instead of guessing here
            #   Well we also use this to determine if the download is a prefpane or an app. There might be better ways to infer this but this should work
            is_prefpane = False
            app_path = f'{folder_downloads}/{filename_app_bundle}'
            if not os.path.exists(app_path):
                app_path = f'{folder_downloads}/{filename_prefpane_bundle}'
                if not os.path.exists(app_path):
                    raise Exception('Unknown bundle name after unzipping')
                else:
                    is_prefpane = True

            if is_prefpane:
                continue

            # Find Info.plist in app bundle
            info_plist_path = f'{app_path}/{subpath_info_plist_app}'

            # Read stuff from Info.plist
            bundle_version = mfutils.runclt(f"/usr/libexec/PlistBuddy '{info_plist_path}' -c 'Print CFBundleVersion'")
            minimum_macos_version = mfutils.runclt(f"/usr/libexec/PlistBuddy '{info_plist_path}' -c 'Print LSMinimumSystemVersion'")

            # Delete bundle we just processed so that we won't accidentally process it again next round (that happens if the next bundle has prefpane_bundle_name instead of app_bundle_name)
            shutil.rmtree(app_path)

            # Assemble collected data into appcast.xml-ready item-string
            #  
            #   About release notes & appcast.xml format:
            #       Release notes can be embedded directly in the appcast.xml using <description> or via a link using <sparkle:releaseNotesLink>
            #           Originally, we used <description> to keep things simple, but this caused the appcast.xml to contain countless copies of our custom css and js text.
            #           I couldn't figure out how to fix that without switching to <sparkle:releaseNotesLink>, so we did switch in [Feb 2025]
            #       
            #   <sparkle:releaseNotesLink> complications:
            #   - [Feb 2025] We're prepending base_url, because I don't think the <sparkle:releaseNotesLink> can be a relative URL. 
            #   - [Feb 2025] <sparkle:releaseNotesLink> requires githack since raw.githubusercontent serves the html file with text/plain mime type, which makes Sparkle update window in MMF display the html source code as plain text.
            #       - Before githack, we used a custom proxy to change mime-types, but it worked clientside and so required js which wasn't activated in the update window of older MMF versions.
            #       - See: https://github.com/noah-nuebling/mmf-update-notes-proxy

            #   References: 
            #       - [SUAppcastItem releaseNotesURL] docs (https://sparkle-project.org/documentation/api-reference/Classes/SUAppcastItem.html#/c:objc(cs)SUAppcastItem(py)releaseNotesURL)
            #           - Explains difference between <sparkle:releaseNotesLink> and <description>
            #       - SampleAppcast.xml 1 (https://github.com/sparkle-project/Sparkle/blob/2.x/Resources/SampleAppcast.xml)
            #           - Contained in main Sparkle repo, uses <sparkle:releaseNotesLink>
            #       - SampleAppcast.xml 2 (https://sparkle-project.org/files/sparkletestcast.xml)
            #           - Linked from Sparkle docs, uses <description>
            appcast_release_note_elements = []
            for locale in locales:
                
                html_path = getpath_release_notes_html(locale, tag_name)

                if not os.path.exists(html_path):
                     print(f"Skipping appcast entry for '{html_path}' since the file doesn't exist. (We tolerate this for testing - shouldn't happen in production.)")
                     continue

                if True:
                    # Approach 1: <sparkle:releaseNotesLink>
                    #   (Requires githack to fix mime type)
                    #   Notes: 
                    #   - [Mar 2025] On `xml:lang`:
                    #       Sparkle docs say `xml:lang` expects 2-letter *country code* (Src: https://sparkle-project.org/documentation/publishing/). 
                    #       But we're supplying locale codes from Xcode, which consist of a *language code* plus optional *region* or *script* code (E.g. zh-Hans, zh-HK) (Src: https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPInternational/LanguageandLocaleIDs/LanguageandLocaleIDs.html)
                    #       Not sure how Sparkle will handle this, I think they'll handle it fine and just wrote their docs incorrectly (Nobody gets the terminology around these codes right - Not even me in this script.)
                    #           Update: [Mar 29 2025] Tested – Works perfect in Sparkle.
                    appcast_release_notes_element = mfdedent("""
                        <sparkle:releaseNotesLink xml:lang=\"{lang_slot}\">
                        {release_notes_link_slot}
                        </sparkle:releaseNotesLink>
                    """).format(
                        lang_slot=locale,
                        release_notes_link_slot=(4*' ' + apply_githack(f"{url_base}/{html_path}")),
                    )
                else:
                    # Approach 2: <description>
                    #   (This bloats the appcast file quite a lot)
                    appcast_release_notes_element = mfdedent("""
                        <description xml:lang=\"{lang_slot}\">
                        {release_notes_slot}
                        </description>
                    """).format(
                        lang_slot=locale,
                        release_notes_slot=(4*' ' + release_notes_html)
                    )
                
                appcast_release_note_elements.append(appcast_release_notes_element)
            
            release_notes_str = '\n'.join(appcast_release_note_elements)

            item_string = mfdedent("""
                <item>
                    <title>{title_slot}</title>
                    <pubDate>{publishing_date_slot}</pubDate>
                    <sparkle:minimumSystemVersion>{minimum_macos_version_slot}</sparkle:minimumSystemVersion>
                {release_notes_str_slot}
                    <enclosure
                        url=\"{download_link_slot}\"
                        sparkle:version=\"{bundle_version_slot}\"
                        sparkle:shortVersionString=\"{short_version_slot}\"
                        {signature_and_length_slot}
                        type=\"{type_slot}\"
                    />
                </item>
            """).format(
                title_slot                  = f"{short_version} available!", # Note: [Mar 2025] Not sure if this needs to be translated. Is it even shown to the user?
                publishing_date_slot        = publishing_date,
                minimum_macos_version_slot  = minimum_macos_version,
                release_notes_str_slot      = textwrap.indent(release_notes_str, 4*' '),
                download_link_slot          = download_link,
                bundle_version_slot         = bundle_version,
                short_version_slot          = short_version,
                signature_and_length_slot   = signature_and_length,
                type_slot                   = "application/octet-stream", # Not sure what this is or if this is right
            )

            # Append item_string to arrays
            if not is_prerelease:
                appcast_items.append(item_string)

            appcast_pre_items.append(item_string)

        # Assemble item strings into final appcast strings
        #   Note: [Mar 2025] Not sure we need to translate any of the text here. I don't think it's shown to the user.
        appcast_content_string = mfdedent('''
            <?xml version="1.0" encoding="utf-8"?>
            <rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"  xmlns:dc="http://purl.org/dc/elements/1.1/">
            <channel>
                <title>Mac Mouse Fix Update Feed</title>
                <link>{}</link>
                <description>Stable releases of Mac Mouse Fix</description>
                <language>en</language>
                {}
            </channel>
            </rss>
        ''').format(url_appcast, '\n'.join(appcast_items))

        appcast_pre_content_string = mfdedent('''
            <?xml version="1.0" encoding="utf-8"?>
            <rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"  xmlns:dc="http://purl.org/dc/elements/1.1/">
            <channel>
                <title>Mac Mouse Fix Update Feed for Prereleases</title>
                <link>{}</link>
                <description>Prereleases of Mac Mouse Fix</description>
                <language>en</language>
                {}
            </channel>
            </rss>
        ''').format(url_appcast_pre, '\n'.join(appcast_pre_items))

        # Write to file
        with open(path_appcast, "w") as f:
            f.write(appcast_content_string)
        with open(path_appcast_pre, "w") as f:
            f.write(appcast_pre_content_string)

        # Cleanup & exit
        clean_up(folder_downloads)
        exit(0)

    except Exception as e: # Exit immediately if anything goes wrong
        print(e)
        clean_up(folder_downloads)
        exit(1)

#
# Other helpers
#

def ui_string_from_gh_date(locale: str, gh_date: str) -> str:
    # GitHub date parsing
    #   Doesn't output hour, minute, second. Only year, month, day
    #     Not moving this into mfutils, since I think it's pretty specific for what we're doing here.
    gh_api_time_format = "%Y-%m-%dT%H:%M:%SZ"
    dt = datetime.datetime.strptime(gh_date, gh_api_time_format)
    dt = dt.replace(tzinfo=datetime.timezone.utc)                   # Set the timezone to +0 (Implied by the 'Z' in the original ISO string from the gh API.)
    locale = locale.replace('-', '_')
    result = bdates.format_date(dt, locale=locale)
    return result

def getpath_ghasset_cache     (tag_name: str, download_name: str) -> str:   return os.path.join(folder_ghasset_cache, tag_name, download_name)
def getpath_custom_string     (locale: str, strkey: str)          -> str:   return os.path.join(folder_custom_strings         , strkey , locale    + '.txt')
def getpath_github_release    (locale: str, tag_name: str)        -> str:   return os.path.join(folder_github_releases        , locale  , tag_name + '.md')
def getpath_release_notes_md  (locale: str, tag_name: str)        -> str:   return os.path.join(folder_update_notes_markdown  , locale  , tag_name + '.md')
def getpath_release_notes_html(locale: str, tag_name: str)        -> str:   return os.path.join(folder_update_notes_html      , locale  , tag_name + '.html')

def clean_up(download_folder):
    ret = os.system(f'rm -R {download_folder}')
    if ret != 0:
        print(f'Clean up failed with error code: {ret}')

def apply_githack(url: str):
    # Notes: 
    #   - Based on raw.githack.com, they have very good uptime and have been running for over 10 years (copyright is from 2013) – So I think it's ok to rely on that service.
    #   - raw.githack.com/faq strongly recommends using rawcdn.githack.com in production (instead of raw.githack.com), but that requires us to know the git commit and manually update URLs when content changes (if I understood correctly) – which would complicate the logic here.
    #     Discussion:
    #       Specifically raw.githack.com says: "Please use CDN URLs for anything that might result in heavy traffic. [...] If you don't and the service gets a lots of requests from the same domain, all further requests will be temporary redirected to corresponding CDN URLs"
    #       I assume this is to prevent costs on their side.
    #       I assume traffic from the Sparkle update window in MMF wouldn't trigger the CDN fallback, since the traffic wouldn't come from 'the same domain'. But I'm not sure. If the fallback does trigger, it could delay the rollout of changes we make to update notes. It could also perhaps cause other problems I can't think of right now.
    #       However, I still think it's ok to not use the CDN URL here, since the traffic generated by MMF should be quite low.
    #       I tested with Little Snitch in [Feb 2024] using a newer MMF build (I believe it used Sparkle 1.27): And it seems that githack is only pinged when the update notes are actually showed to the user – When no update is found, then githack is not pinged.
    #       When githack is pinged, it will serve the html, css, and js for the update notes for exactly one update. Looking at the size of those files, this should only be a few KB of traffic.
    #           -> Based on this, I believe the traffic to githack should be pretty miniscule, and therefore I assume it's ok to *not* use the CDN URL.
    #           -> I also set up a 10$-per-month patreon donation for the githack maintainer in [Feb 2025]. I assume that will (more than) offset any costs caused by this.

    if TEST_MODE:
        return url  # In TEST_MODE we host the files locally and they'll be served with the right mime type
    else:
        return url.replace('raw.githubusercontent.com', 'raw.githack.com')

def os_system_exc(s): 
    ret = os.system(s)
    if ret != 0:
        raise Exception(f"os.system failed with error code {ret}")

# Custom strings
# Explanation:
#   [Mar 2025] The main localizable strings this script deals with are the release notes obtained from the GitHub releases API, 
#   but we need some additional localizable strings - those are defined here.
# Notes: 
#   - [Mar 2025] Leading and trailling whitespace seems to be lost after translation with Claude, so we shouldn't include them here.
#   - [Mar 2025] Use upget_custom_string() to access (translated versions) of these. 
#   - On 'release-notes.disclaimer' string:
#       - [Mar 2025] 'not completely accurate' is translated to German as 'nicht vollständig präzise' which is pretty awkward. 'not completely accurate' is translated as 'nicht vollständig korrekt' which is better.
#           -> Perhaps we should tune the LLM params to sound more natural, or alternatively hardcode some strings?

@dataclass
class LocalizableString:
    string: str
    hint: str|None = None

custom_strings_in_src_language: dict[str, LocalizableString] = {
    'release-notes.disclaimer': LocalizableString(mfdedent(r""" 
        **ℹ️ Translated by AI**

        This release note has been translated by the Claude AI. It may not be entirely accurate.\
        For the original English version, [click here]({gh_releases_url}).
        """)),
    'release.disclaimer': LocalizableString(mfdedent(r"""
        <b>Translated by AI</b><br>
        This is a translation of a <b><em>GitHub Release</em></b>.<br>
        The translation was made by the Claude AI and may not be entirely correct.<br>
        For the original GitHub Release (in English), <a href="{gh_releases_url}">click here</a>.
        """)),
    'release.metadata': LocalizableString(
        r"**Release Date:** {date}",   
        hint="Metadata displayed right below the header of a release document for the Mac Mouse Fix app."),
    'release.assets': LocalizableString(
        r"Assets",                     
        hint="This is a heading for a table showing downloadable files/resources for a release of the Mac Mouse Fix app."),

    # Handwritten German versions (unused, just for reference, as of [Mar 2025])
        '__de.release.disclaimer': LocalizableString(mfdedent(r"""
            <b>Von KI übersetzt</b><br>
            Dies ist eine Übersetzung von einem <b><em>GitHub Release</em></b>.<br>
            Die Übersetzung wurde von der Claude KI erstellt und ist möglicherweise nicht ganz korrekt.<br>
            Das ursprüngliche GitHub Release (auf englisch) findest du <a href="{gh_releases_url}">hier</a>.
            """)),
        '__de.release.metadata': LocalizableString(
            "**Veröffentlichungsdatum:** {date}"),
        '__de.release.assets': LocalizableString(
            "Assets"),
}

def upget_custom_string(locale: str, strkey: str) -> str:

    # Validate args
    assert locale in locales,                           f"Unknown locale {locale}"
    assert strkey in custom_strings_in_src_language,    f"Unknown string key {strkey}"

    # Derive stuff
    src_path:           str                 = getpath_custom_string(source_locale, strkey)
    translation_path:   str                 = getpath_custom_string(locale, strkey)
    fresh_src:          LocalizableString   = custom_strings_in_src_language[strkey]

    # Write the fresh source-language-string to file
    #   Note: [Mar 2025] Is it inefficient to do this every time here? Maybe we could restrict this to only happen once per strkey, per program-run
    #   Note: [Mar 2025] Update: Now that @deptracked decorator supports non-file sources, we no longer have to write the source-language-string to file here – But it's actually nice-to-have so you can easily browse the original next to the translations.
    p = Path(src_path)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(fresh_src.string)

    # Do translation
    #   Note: [Mar 2025] We have one file per strkey – is that inefficient or something?
    result = upget_translation(fresh_src, locale, src_path, translation_path, do_localize_urls=False)

    # Return
    return result

#
# AI Translation
#

def _let_claude_translate(locale: str, english_textttt: str|LocalizableString) -> str:

    # [Mar 2025] Helper for upget_translation()

    # Preprocess args
    english_text: str = None
    localizer_hint: str = None
    if isinstance(english_textttt, LocalizableString):
        english_text = english_textttt.string
        localizer_hint = english_textttt.hint
    else:
        english_text = english_textttt
        localizer_hint = None
    localizer_hint = localizer_hint or '<None>'

    # Validate
    assert english_text     != '' and english_text is not None, f"English input is empty"
    assert localizer_hint   != '',                              f"Localizer hint is empty but not None"

    # Lazily create anthropic client (Store it on the function object)
    if not hasattr(_let_claude_translate, "anthropic_client"):
        api_key = args.anthropic_api_key
        assert api_key is not None, "Error: No anthropic API key found (Provide it via arg or environment var)."
        _let_claude_translate.anthropic_client = anthropic.Anthropic(api_key=api_key)
        assert _let_claude_translate.anthropic_client is not None, f"Error: No anthropic API client couldn't be created. api_key: {api_key}"
    anthropic_client = _let_claude_translate.anthropic_client

    # Constant: Max output tokens
    #   On token count: [Mar 2025]
    #   - The `3.0.1 Beta 1` notes have a bit over 1000 tokens.
    #   - 8192 is currently the max. That seems sorta low? But should be enough for our usecase. 
    #   - If we reach the limit, the stop_reason is set to 'max_tokens'
    #  On 'language code': [Mar 2025]
    #   - language_code might not be the technically correct terminology for the codes we're supplying (I think it's `Language ID`), but Claude seem to handle things fine. (Src: Correct terminology from Apple: https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPInternational/LanguageandLocaleIDs/LanguageandLocaleIDs.html)
    max_output_tokens = 8192
    
    # Create request for anthropic API
    anthropic_args = {
        'model': "claude-3-5-sonnet-20241022",
        'system': mfdedent(r"""
            You are an accurate, elegant translator. Requests that you handle follow the pattern:
            `<language_code>[some ISO language code]</language_code><localizer_hint>[some hint for you]</localizer_hint><english_text>[some english text]</english_text>`
            You will reply with the translation of the english text into the language specified by the language code. You do not reply with any other information. Only the translation.
            The localizer hint will either provide additional context to help you with your translation, or it will be '<None>', in which case you can ignore it.

            Please note:
            - The text you translate is written by the developer of an indie app. The text is intended to be read by users of said indie app. To be appropriate for this context, the text should not be overly formal. For example, when translating to German, use informal 'du' instead of formal 'Sie'.
            - Your output will be rendered as Markdown or HTML. Please maintain all relevant formatting characters as they appear in the source text, including backslashes at the end of a line (\), asterisks (*), and any other special characters that serve as markup to determine the text formatting.
            - Remember to not reply with any other information except for your translation.
            """),
        'messages': [{
            "role": "user",
            "content": [
                {
                    "type": "text",
                    "text": rf"<language_code>{locale}</language_code><localizer_hint>{localizer_hint}</localizer_hint><english_text>{english_text}</english_text>"
                }
            ]
        }]
    }

    # Get input token count
    input_token_count_response = anthropic_client.messages.count_tokens(**anthropic_args)
    input_token_count = input_token_count_response.input_tokens
    
    # Log
    print(f"Sending request to anthropic with {input_token_count} input tokens...")

    # Ping Anthropic
    anthropic_args = { 
        **anthropic_args, 
        'max_tokens':   max_output_tokens,
        'temperature':  0,
    }
    response = anthropic_client.messages.create(**anthropic_args)
    
    # Validate response
    assert response.stop_reason == 'end_turn', f"Anthropic model stopped with unexpected reason '{response.stop_reason}'"
    
    # Extract translation text
    translation = response.content[0].text

    # Return
    return translation

def upget_translation(
    fresh_src: str|LocalizableString, 
    translation_locale: str,
    src_path: str,
    translation_path: str,
    do_localize_urls: bool
) -> str:
    
    # Caution:
    #   [Mar 2025] src_path must be updated to contain fresh_src before this is called, otherwise the dependency tracker will incorrectly reference the outdated content of the source file, while the translation is actually derived from the newer fresh_src.
    #       -> Perhaps we could make this less error-prone (but also less efficient) by not passing in fresh_src, or by writing fresh_src to src_path inside this function. 
    #       Related: Explanation or 'upget' function-prefix explained in the deptracked() implementation

    # Note: [Mar 2025] What does 'upget' mean?
    #   We prefix depency-functions with 'upget', e.g. 'upget_translation()' to signify that the functions not only *get* and return the fresh value, but also *up*date the target_path with that fresh value.
    #   This is important to keep in mind, because, to ensure correctness, our code needs to manually make sure that all dependency-files are updated *before* their dependent-files.
    #   (Before we try to abstract that away, it's probably better to use an existing tool like make or snakemake or something, for now it's manageable to handle this manually)

    # Skip source language (English)
    if translation_locale == source_locale: 
        return fresh_src.string if isinstance(fresh_src, LocalizableString) else fresh_src

    # Get & update translation
    translation = None
    @deptracked(path_deptracker_docs, [src_path], translation_path, sources_are_files=True)
    def update_translation_file():
        
        # Constants
        user_allowed_translate_all_locales_key  = f'user_allowed_translate_all - {src_path}'
        user_allowed_translate_ALL_key          = f'user_allowed_translate_ALL'

        # Check if user allows this translation
        #   (User might wanna avoid expensive/slow API calls.)
        user_allowed_translate = None
        if hasattr(upget_translation, user_allowed_translate_ALL_key):
            user_allowed_translate = getattr(upget_translation, user_allowed_translate_ALL_key)
        elif hasattr(upget_translation, user_allowed_translate_all_locales_key):
            user_allowed_translate = getattr(upget_translation, user_allowed_translate_all_locales_key)
        else:
            while True:
                user_input = input(f"❓🤖❓ Translate '{src_path}' to language '{translation_locale}'? (Might incur API costs) [y/n/ya/na/yaa/naa - ya/na to apply choice to all remaining languages. yaa/naa to apply choice to all.]")
                if   user_input == 'y':     user_allowed_translate = True
                elif user_input == 'n':     user_allowed_translate = False
                elif user_input == 'ya':    user_allowed_translate = True;                          setattr(upget_translation, user_allowed_translate_all_locales_key, True)
                elif user_input == 'na':    user_allowed_translate = False;                         setattr(upget_translation, user_allowed_translate_all_locales_key, False)
                elif user_input == 'yaa':   user_allowed_translate = True;                          setattr(upget_translation, user_allowed_translate_ALL_key, True)
                elif user_input == 'naa':   user_allowed_translate = False;                         setattr(upget_translation, user_allowed_translate_ALL_key, False)
                else:                       print(f'Error: Input {user_input} unrecognised.');      continue
                break
        assert user_allowed_translate is not None, "Code is buggy"
        
        if not user_allowed_translate:
            return False # Signal to deptracker decorator that we didn't derive the string
        
        # Log
        print(f"Translating to '{translation_locale}'...")

        # Ask LLM to translate
        translation = _let_claude_translate(translation_locale, fresh_src)

        # Validate
        assert translation is not None, f"Translation for '{translation_path}' from LLM is unexpectedly None"

        # Write result to file
        p = Path(translation_path)
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(translation)

        # Return success
        return True
    update_translation_file()

    # Get cached translation if it wasn't updated. 
    if translation is None and os.path.exists(translation_path):
         translation = Path(translation_path).read_text()

    # Localize urls
    #   Notes: 
    #       - [Mar 2025] doing this outside the deptracker, otherwise, we'd have to retranslate everything with the LLM, when we change the url-localization-logic
    #       - [Mar 2025] After changing url-localization-logic, we still might have to delete some target files to force re-generation of some files (not sure) (I think it's the HTML files since those are also deptracked atm, which maybe they shouldn't be.)
    if translation is not None and do_localize_urls:
        # Log
        print(f"Localizing URLs inside LLM's translation...")
        # Localize URLs
        translation = mflocales.localize_urls(source_locale, translation_locale, translation)

    # Fall back to placeholder
    if translation is None: translation = "<No translation>"

    # Return
    return translation

#
# Run
#

generate()