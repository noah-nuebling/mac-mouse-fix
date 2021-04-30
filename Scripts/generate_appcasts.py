#!/usr/bin/python3


# Imports

import os
# import requests # Only ships with python2 on mac it seems
import urllib.request
import urllib.parse

import json

from pprint import pprint

import subprocess

# Constants
#   Paths are relative to project root.

os.chdir('..') # Run this script from the Scripts folder, it will then automatically chdir to the root dir

releases_api_url = "https://api.github.com/repos/noah-nuebling/mac-mouse-fix/releases"

info_plist_path = "App/SupportFiles/Info.plist"
base_xcconfig_path = "xcconfig/Base.xcconfig"
sparkle_project_path = "Frameworks/Sparkle-1.26.0" # This is dangerously hardcoded
download_folder = "generate_appcasts_downloads" # We want to delete this on exit
current_directory = os.getcwd()
download_folder_absolute = os.path.join(current_directory, download_folder)
files_to_checkout = [info_plist_path, base_xcconfig_path]

def generate():
    try:

        # Check if there are uncommited changes
        # This script uses git stash several times, so they'd be lost
        uncommitted_changes = subprocess.check_output('git diff-index HEAD --', shell=True).decode('utf-8')
        if (len(uncommitted_changes) != 0):
            raise Exception('There are uncommited changes. Please commit or stash them before running this script.')

        # Script

        request = urllib.request.urlopen(releases_api_url)
        releases = json.load(request)

        # We'll be iterating over all releases and collecting data to put into the appcast
        appcast_items = []
        appcast_items_pre = [] # Items for the pre-release channel

        for r in releases:

            # Accessing Xcode environment variables is night impossible it seems
            # The only way to do it I found is described here:
            #   https://stackoverflow.com/questions/6523655/how-do-you-access-xcode-environment-and-build-variables-from-an-external-scrip
            #   And that's not feasible to do for old versions.


            # Get short version
            short_version = r['name']

            print(f'Processing release {short_version}...')

            # Get release notes
            release_notes = r['body'] # This is markdown

            # Write release notes to file. As a plain string I had trouble passing it to pandoc, because I couldn't escape it properly
            os.makedirs(download_folder_absolute, exist_ok=True)
            text_file = open(f"{download_folder}/release_notes.md", "w")
            n = text_file.write(release_notes)
            text_file.close()
            # Convert to HTML
            release_notes = subprocess.check_output(f"cat {download_folder}/release_notes.md | pandoc -f markdown -t html", shell=True).decode('utf-8')
                # The $'' are actually super important, otherwise bash won't presever the newlines for some reason


            # Get title
            title = f"{short_version} available!"

            # Get publishing date
            publising_date = r['published_at'];

            # Get isPrerelease
            is_prerelease = r['prerelease']

            # Get type
            type = "application/octet-stream" # Not sure what this is or if this is right

            # Get localized release notes ?
            #   ...


            # Get tag
            tag_name = r['tag_name']

            # Get commit number
            # commit = os.system(f"git rev-list -n 1 {tag_name}") # Can't capture the output of this for some reason
            commit_number = subprocess.check_output(f"git rev-list -n 1 {tag_name}", shell=True).decode('utf-8')
            commit_number = commit_number[0:-1] # There's a linebreak at the end

            # # Check out commit
            # # This would probably be a lot faster if we only checked out the files we need
            # os.system("git stash")
            # files_string = ' '.join(files_to_checkout)
            # bash_string = f"git checkout {commit_number} {files_string}"
            # try:
            #     subprocess.check_output(bash_string)
            # except Exception as e:
            #     print(f"Exception while checking out commit {commit_number} ({short_version}): {e}. Skipping this release.")
            #     continue

            # # Get version
            # #   Get from Info.plist file
            # bundle_version = subprocess.check_output(f"/usr/libexec/PlistBuddy {info_plist_path} -c 'Print CFBundleVersion'", shell=True).decode('utf-8')

            # # Get minimum macOS version
            # #   The environment variable buried deep within project.pbxproj. No practical way to get at this
            # #   Instead, we're going to hardcode this for old versions and define a new env variable via xcconfig we can reference here for newer verisons
            # #   See how alt-tab-macos did it here: https://github.com/lwouis/alt-tab-macos/blob/master/config/base.xcconfig
            # minimum_macos_version = ""
            # try:
            #     minimum_macos_version = subprocess.check_output(f"awk -F ' = ' '/MACOSX_DEPLOYMENT_TARGET/ {{ print $2; }}' < {base_xcconfig_path}", shell=True).decode('utf-8')
            #     minimum_macos_version = minimum_macos_version[0:-1] # Remove trailing \n character
            # except:
            #     minimum_macos_version = 10.11

            # Get download link
            download_link = r['assets'][0]['browser_download_url']

            # Download update
            os.makedirs(download_folder_absolute, exist_ok=True)
            download_name = download_link.rsplit('/', 1)[-1]
            download_destination = f'{download_folder}/{download_name}'
            urllib.request.urlretrieve(download_link, download_destination)

            # Get edSignature
            signature_and_length = subprocess.check_output(f"./{sparkle_project_path}/bin/sign_update {download_destination}", shell=True).decode('utf-8')
            print(os.getcwd())
            os.system(f'ditto -V -x -k --sequesterRsrc --rsrc "{download_destination}" "{download_folder}"')
            # unzip_output = subprocess.check_output(f'ditto -V -x -k --sequesterRsrc --rsrc "{download_destination}" "{download_folder}"')




            # Assemble collected data into appcast-ready item-string
            item_string = f"""
    <item>
        <title>{title}</title>
        <pubDate>{publising_date}</pubDate>
        <sparkle:minimumSystemVersion>{minimum_macos_version}</sparkle:minimumSystemVersion>
        <description><![CDATA[
            {release_notes}
        ]]>
        </description>
        <enclosure
            url=\"{download_link}\"
            sparkle:version=\"{bundle_version}\"
            sparkle:shortVersionString=\"{short_version}\"
            {signature_and_length}
            type=\"{type}\"
        />
    </item>"""

            # Append item_string to arrays
            appcast_items_pre.append(item_string)
            if not is_prerelease:
                appcast_items.append(item_string)

            print(item_string)

        # clean_up(download_folder)

    except Exception as e: # Exit immediately if anything goes wrong
        print(e)
        clean_up(download_folder)
        exit(1)

def clean_up(download_folder):
    if download_folder != "":
        try:
            os.system(f'rm -R {download_folder}')
        except:
            pass

generate()