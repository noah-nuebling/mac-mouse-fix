# `Old` Scripts

The `Old` Folder contains the StateOfLocalization and UpdateStrings scripts. They both became obsolete after we moved from using .strings and .stringsdict to using .xcstrings files. 

**UpdateStrings**

-> Superseeded by **SyncXCStrings** script.
- The **UpdateStrings** script was part of the Xcode build process. It sorted, cleaned-up, inserted, and annotated the development language (English) .strings files throughout the project by comparing them to source code files. 
- Now, With .xcstrings files, all of this is handled by Xcode (Or by xcstringstool which our new SyncXCStrings script uses internally) 
- The new SyncXCStrings script exists to also make this Xcode functionality available for other file types (.md and .vue)

**StateOfLocalization

-> Superseeded by **SyncXCStrings** and **UploadXCStrings** script
- The **StateOfLocalization** script tracked discrepancies between source language and the translations, and then published them to the "🌏 State of Localization 🌎" comment on GitHub. 
- Now, for .xcstrings files, such discrepancies are automatically tracked by Xcode. (Or by xcstringstool which our new SyncXCStrings script uses internally)
- Publishing of this info is now handled by the UploadXCStrings script. It uploads .xcloc files which contain info about which strings need to be reviewed by localizers. 

# Localization > Code
(These are the contents of the old readme for the StateOfLocalization and UpdateStrings scripts)

## StateOfLocalization

(All of these commands are for the fish shell)

**Install dependencies**

```
python3 -m venv env;\
source env/bin/activate.fish;\
python3 -m pip install -r Localization/Code/StateOfLocalization/requirements.txt;
```

**Run the script**

```
python3 Localization/Code/StateOfLocalization/script.py --api_key <...>
```
(Use --help for an explanation of the args)

**Deactivate the venv**

```
deactivate
```

## UpdateStrings

(All of these commands are for the fish shell)

**Install dependencies**

```
python3 -m venv env;\
source env/bin/activate.fish;\
python3 -m pip install -r Localization/Code/UpdateStrings/requirements.txt;
```

**Run the script**

```
python3 Localization/Code/UpdateStrings/script.py
```
(Use --help for an explanation of the args)

**Deactivate the venv**
```
deactivate
```
