#!/usr/bin/python3

# Imports

import os
import shutil
# import requests # Only ships with python2 on mac it seems
import urllib.request
import urllib.parse

import json

from pprint import pprint

import subprocess

releases_api_url = "https://api.github.com/repos/noah-nuebling/mac-mouse-fix/releases"


def main():
    try:

        # Script

        request = urllib.request.urlopen(releases_api_url)
        releases = json.load(request)

        for r in releases:

            # Get short version
            short_version = r['name']

            # Get download count
            downloads = r['assets'][0]['download_count']

            print(f'{short_version}: {downloads} downloads')


    except Exception as e: # Exit immediately if anything goes wrong
        print(e)
        exit(1)


main()