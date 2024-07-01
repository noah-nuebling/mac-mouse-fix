# mac-mouse-fix-scripts

Collection of Python scripts which we want to share between the mac-mouse-fix and mac-mouse-fix-website repos.

The reason for creating this is that we want to share the localization logic between mac-mouse-fix and mac-mouse-fix-website.

We plan to embed this repo as a 'subtree' in both the mac-mouse-fix and mac-mouse-fix-website repos. This enables syncing the repo between both hosting repos.

## How to set up

1. Add this repo as a subtree using this command:

    git subtree add --prefix mac-mouse-fix-scripts git@github.com:noah-nuebling/mac-mouse-fix-scripts.git main --squash

2. Add a .env file at your repo root with this content:

    PYTHONPATH=mac-mouse-fix-scripts/Shared/

3. Add a bash script at your repo root with this content:

    #!/bin/bash
    python3 mac-mouse-fix-scripts/run.py "$@";

-> Now you can run the scripts using ./run <subcommand> <args>
-> You can also run the scripts using the VSCode debugger and linting should work properly. (The .env file is necessary for that.)

## How to sync

To push:

    ./run sync-scripts push

To pull:

    ./run sync-scripts pull

