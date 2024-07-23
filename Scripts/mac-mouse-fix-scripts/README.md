# mac-mouse-fix-scripts

Collection of Python scripts which we want to share between the mac-mouse-fix and mac-mouse-fix-website repos.

The reason for creating this is that we want to share the localization logic between mac-mouse-fix and mac-mouse-fix-website.

We plan to embed this repo as a submodule in both the mac-mouse-fix and mac-mouse-fix-website repos. This enables syncing the repo between both hosting repos.

(We also tried subtrees but pushing was extremely slow)

GH Submodule resources:

    gitaarik's GH Gist:
        https://gist.github.com/gitaarik/8735255

    gitsubmodules docs:
        https://git-scm.com/docs/gitsubmodules

    git-submodule docs: (verbose)
        https://git-scm.com/docs/git-submodule

    Git-Tools-Submodules docs: (its a book)
        https://git-scm.com/book/en/v2/Git-Tools-Submodules

## Setup

**Git Submodules**

1. Add mac-mouse-fix-scripts as a submodule to a host repo use this command:

       git submodule add https://github.com/noah-nuebling/mac-mouse-fix-scripts

2. To clone the host repo along with submodules, use:

       git clone --recurse-submodules

   or
    
       git clone
       git submodule init

4. git config stuff:

    Enable warnings if you forget to `git push` changes inside the submodule (I recommend)

        git config push.recurseSubmodules check

    Make commands such as `git pull` apply to submodules (alternatively you can use --recurse-submodules flag)

        git config submodule.recurse true

    Make `git diff` include the submodule (very optional)

        git config diff.submodule log

    Show submodule changes in `git st` (very optional)

        git config status.submodulesummary 1

**Other**

1. Add an ./.env file at your repo root with this content:

       PYTHONPATH=mac-mouse-fix-scripts/Shared/

2. Add a `./run` bash script at your repo root with this content:


       #!/bin/bash
       python3 mac-mouse-fix-scripts/run.py "$@";

   Then make it executable using

       chmod +x ./run

## Workflow

**Custom**

1. You can now run the scripts from mac-mouse-fix-scripts using

       ./run <subcommand> <args>       (The ./run bash script (See ^^^) enables this)

2. You can also run the scripts using the VSCode debugger and also linting should work properly.        (The ./.env file (See ^^^) is enables this.)

**Git Submodules**

To `push` submodule changes in host repo A:
    
    `cd` into the submodule, make a new commit, and push it.

To `pull` submodule changes in host repo B:

    git submodule update --remote --merge

or 
    
    `cd` into the submodule and pull

To `push` host repo changes *along* with submodule:

    - Make a new commit inside the submodule
    - Make a new commit inside the host repo (it will point to the new submodule commit)
    - git push --recurse-submodules=on-demandf

To `pull` host repo changes *along* with submodule:

    git pull --recurse-submodules

    Note: 
        `git pull --recurse-submodules` will pull the latest commit of the host repo 
        along with the commit of the submodule that the latest host-repo-commit points to (this doesn't have to
        be the latest commit of the submodule, to get that, use `git submodule update --remote [--merge]`)
