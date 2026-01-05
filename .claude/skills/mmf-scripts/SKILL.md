---
name: mmf-scripts
description: Information about the ./run command and ./mac-mouse-fix-scripts. Use when discussing ./run, or working on scripts in mac-mouse-fix-scripts.
---

# Mac Mouse Fix Scripts

The `./mac-mouse-fix-scripts` folder contains a submodule with various Python scripts. These can be invoked using the `./run` command:

```
./run [<run_args> --] <subcommand> <subcommand_args>
```

## Finding available commands

Run `./run` with no arguments to see all available subcommands.

## Finding script implementations

The scripts live in a **git submodule** (`./mac-mouse-fix-scripts`).

**Important:** Exploration agents and glob/grep tools seem to sometimes not find files in submodules. [Jan 2026] To reliably find script source code, run `./run` with no arguments which will print a mapping from subcommands to script files
