#!/usr/bin/python3


# Imports

import os
# import requests # Only ships with python2 on mac it seems
import urllib.request
import urllib.parse

import json

from pprint import pprint

import subprocess

try:

    # Check if there are uncommited changes
    # This script uses git stash several times, so they'd be lost
    uncommitted_changes = subprocess.check_output('git diff-index HEAD --', shell=True)
    if (len(uncommitted_changes) != 0):
        raise Exception('There are uncommited changes. Please commit or stash them before running this script.')
    

    # Constants
    #   Paths are relative to project root. -> Run this from project root.

    releases_api_url = "https://api.github.com/repos/noah-nuebling/mac-mouse-fix/releases"

    info_plist_path = "App/SupportFiles/Info.plist"
    base_xcconfig_path = "xcconfig/Base.xcconfig"
    sparkle_project_path = "Frameworks/Sparkle-1.26.0" # This is dangerously hardcoded

    # Script

    request = urllib.request.urlopen(releases_api_url)
    releases = json.load(request)

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
        # Convert to HTML
        release_notes = subprocess.check_output(f"echo $'{release_notes}' | pandoc -f markdown -t html]", shell=True)
            # The $'' are actually super important, otherwise bash won't presever the newlines for some reason

        # Get title
        title = f"Version {short_version} available!"

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
        commit = subprocess.check_output(f"git rev-list -n 1 {tag_name}", shell=True)
        commit = commit[0:-1] # There's a linebreak at the end

        # Check out commit
        # This would probably be a lot faster if we only checked out the files we need
        os.system("git stash")
        os.system("git checkout {commit_number}")

        # Get version
        #   Get from Info.plist file
        bundle_version = subprocess.check_output(f"/usr/libexec/PlistBuddy {info_plist_path} -c 'Print CFBundleVersion'", shell=True)

        # Get minimum macOS version
        #   The environment variable buried deep within project.pbxproj. No practical way to get at this
        #   Instead, we're going to hardcode this for old versions and define a new env variable via xcconfig we can reference here for newer verisons
        #   See how alt-tab-macos did it here: https://github.com/lwouis/alt-tab-macos/blob/master/config/base.xcconfig
        minimum_macos_version = ""
        try:
            minimum_macos_version = subprocess.check_output(f"awk -F ' = ' '/MACOSX_DEPLOYMENT_TARGET/ {{ print $2; }}' < {base_xcconfig_path}", shell=True)
            minimum_macos_version = minimum_macos_version[0:-1] # Remove trailing \n character
        except:
            minimum_macos_version = 10.11

        # Get download link
        download_link = r['assets'][0]['browser_download_url']

        # Download update
        download_name = download_link.rsplit('/', 1)[-1]
        download_destination = download_name
        urllib.request.urlretrieve(download_link, download_destination)

        # Get edSignature
        signature_and_length = subprocess.check_output(f"./{sparkle_project_path}/bin/sign_update {download_destination}", shell=True)


except Exception as e: # Exit immediately if anything goes wrong

    print(e)
    exit(1)

