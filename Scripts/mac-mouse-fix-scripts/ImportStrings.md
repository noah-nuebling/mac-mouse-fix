# ImportStrings.md

To publish .xcloc files, we can use our custom script:

    ./run upload-strings

To import .xcloc files that users sent use, we can use

    `cd` to mac-mouse-fix
    xcodebuild -importStrings -localizationPath "path/to/Mac Mouse Fix.xcloc"

    `cd` to mac-mouse-fix-website
    xcodebuild -importStrings -localizationPath "path/to/Mac Mouse Fix Website.xcloc"