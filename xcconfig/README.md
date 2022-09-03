
# Notes (September 2022)

We used to have many different .xcconfig files in this folder. But we just removed them all.
We orginally added them to help with adopting Sparkle for MMF2. But ended up changing our implementation so this wasn't necessary anymore. See "# Old Notes" below for more info on that. 
Then we didn't want to remove them because you never change a running system and also because we thought "maybe we'll use this one day.". But it confused me to have the build settigns in all these different places, and we didn't really need the xcconfig files, so we're removing them now. 
Instead, we'll just use the standard Xcode build settings.

If there is a need in the future to add .xcconfig files back in, you can check out the comments and notes below to help you, or have a look at commit 667cd7925c82b02b71d2a842281c0df5f7dfd02a which is last with the old xcconfig files.

# Comments from the old .xcconfig files


// Awesome, extensive tutorial: https://nshipster.com/xcconfig/
// Official .xcconfig documentation: https://help.apple.com/xcode/#/dev745c5c974
//
// Example usage
//  - https://github.com/lwouis/alt-tab-macos/blob/master/config/base.xcconfig
//  - https://github.com/lwouis/alt-tab-macos/blob/master/config/debug.xcconfig
//  - https://github.com/lwouis/alt-tab-macos/blob/master/config/release.xcconfig
//
// Build settings reference: https://help.apple.com/xcode/mac/11.4/#/itcaec37c2a6

# Old Notes (Before September 2022 cleanup)

- Edit: (Writing this a much later so I don't remember everything) Actually there were more problems with the approach described below (Edit: maybe it's because you have to download the app to sign it for Sparkle anyways?). So we ended up having generate_appcasts.py simply download all versions of the app and look at the info.plists to get this information. So I think having these xcconfig files here isn't necessary at all.

- ! If we want to move or refactor Base.xcconfig, we need to reflect that in generate_appcasts.py, but also still use the old path for older repo version. So it's better to not refactor it at all if possible.
- We created these xcconfig files to give our generate_appcasts.py script a chance to read the minimum compatible macOS version.
    - When you set env variables from the project editor, those are deeply buries withing the project.pbxproj file, and completely impractical to access for an external script. (External -> Not executed by Xcode as part of the build process)
    - The generate_appcasts.py script will go through all releases, and look at their related commits. Within those, it'll look into [ProjectRoot]/xcconfig/Base.xcconfig and search for the value to MACOSX_DEPLOYMENT_TARGET in there.
        - So if we refactor Base.xcconfig, we need to adjust the generate_appcasts.py script, too

