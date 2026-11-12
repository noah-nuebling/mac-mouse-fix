#!/bin/sh

# Update: Commenting this out now, since we've moved everything to .xcstrings files instead of .strings files. Later, maybe we want to reactivate this and change the script so that it extracts strings from .md.skeleton files which we plan to introduce. 
# Update2: No we're extracting strings from the .md files before building the .md files probably

# Run UpdateStrings/script.py. 
# Notes:
# - Using xcrun everywhere for hopefully better compatibility? It looks up the command in Xcode dev tools and other places, even if it's not in the path - if I understand correctly.
# - This script takes around 2-3s from what I've seen. Should maybe optimize. Edit: Optimized a little. It's around 2s. BartyCrouch wasn't much faster - also hovers around 2s.
# - Activating the venv doens't work here for some reason, so we do this weird ${SRCROOT}/venv/bin/pip3 stuff.
 
# Install dependencies into venv
#xcrun python3 -m venv ${SRCROOT}/venv
#${SRCROOT}/venv/bin/pip3 install -r ${SRCROOT}/Localization/Code/UpdateStrings/requirements.txt

# Run script 
#${SRCROOT}/venv/bin/python3 ${SRCROOT}/Localization/Code/UpdateStrings/script.py --wet_run

