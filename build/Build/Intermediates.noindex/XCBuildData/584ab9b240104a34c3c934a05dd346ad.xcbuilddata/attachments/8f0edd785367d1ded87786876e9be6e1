#!/bin/sh

# I originally made this because sometimes I get crashlogs of the Helper which just say -1 for the version.
# Now I'm trying to use the build number to check if an instance of the Helper and an instance of the mainApp belong together.
# Note: Where do INFOPLIST_FILE_MAINAPP and INFOPLIST_FILE_HELPER come from?

# Get versions from Main App
version=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "${PROJECT_DIR}/${INFOPLIST_FILE_MAINAPP}")
shortVersion=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "${PROJECT_DIR}/${INFOPLIST_FILE_MAINAPP}")

if [ "${CONFIGURATION}" = "Release" ]; then # [Nov 12 2025]
    $((version++)) 
    # ^ Because we'll also be incrementing Main App version when it builds
    #   Can't get any build phase from Main App to run before the Helper is compiled. Otherwise we wouldn't need to do this. We could increment the Main App version and then simply copy it over.
    #   For some reason is not always in sync with the Main App version. I saw it lag one behind. I think it might have to do with Xcode optimizing builds and not always running this if the Helper hasn't changed, but not sure.
    #   Edit: I think I fixed the bug where the Helper build number is lagging behind the main app build number by simply moving the "Copy Version From Main App" build phase up - ergo executing it before other build phases. Previously it was the last build phase that was executed.
fi

# Set versions to Helper
/usr/libexec/PlistBuddy -c "Set CFBundleVersion ${version}" "${PROJECT_DIR}/${INFOPLIST_FILE_HELPER}"
/usr/libexec/PlistBuddy -c "Set CFBundleShortVersionString ${shortVersion}" "${PROJECT_DIR}/${INFOPLIST_FILE_HELPER}"

