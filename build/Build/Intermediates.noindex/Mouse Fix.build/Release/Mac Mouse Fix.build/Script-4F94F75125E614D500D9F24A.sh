#!/bin/sh

if [ "${CONFIGURATION}" = "Release" ]; then # Only increment in release builds to prevent annoying churn in git history [Nov 12 2025]
    # Notes:
    # - We're storing the `version` (aka build number) directly inside the info plist so that we can increment it here. The `shortVersion` (such as 3.0.1) is instead stored inside the Xcode project under General > Identity > Version
    buildNumber=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "${PROJECT_DIR}/${INFOPLIST_FILE}")
    buildNumber=$((buildNumber+1))
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $buildNumber" "${PROJECT_DIR}/${INFOPLIST_FILE}"
fi

