#!/usr/bin/python3

# Constants
#   Paths are relative to project root. -> Run this from project root.

releases_api_url = "https://api.github.com/repos/noah-nuebling/mac-mouse-fix/releases"
info_plist_path = ""

# Imports

import os
# import requests # Only ships with python2 on mac it seems
import urllib.request
import urllib.parse

import json

from pprint import pprint

# Script

request = urllib.request.urlopen(releases_api_url)
releases = json.load(request)

for r in releases:

    # Get tag
    tag_name = r['tag_name']

    # Get commit number
    # commit = os.system(f"git rev-list -n 1 {tag_name}") # Can't capture the output of this for some reason
    commit = subprocess.check_output(f"git rev-list -n 1 {tag_name}", shell=True)
    commit = commit[0:-1] # There's a linebreak at the end

    # Get edSignature

    # Get length ?

    # Get version

    # Get short version
    short_version = r['name']


    # Get downloadLink

    # Get release notes

    # Get title

    # Get publishing date

    # Get minimum system version

    # Get isPrerelease

    # Get type

    # Get localized release notes ?



