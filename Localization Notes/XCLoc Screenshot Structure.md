# Figuring out xcloc screenshot structure

To figure out the structure that an .xcloc file needs to have to make screenshots show up inline in the Xcode editor, I made a handcrafted example of an .xcloc file with embedded screenshots. See de-manual-edit.xcloc in our CustomImplForLocalizationScreenshotTest test project.

Caveats:
If n strings appeared in the same screenshot we had to include n copies of the screenshot.
Since if several strings referenced the same screenshot file, the red highlighter rectangle that highlights the text in the screenshot broke in Xcode 16.0 Beta 2.
This didn't happen in Loca Studio, but Loca Studio doesn't support the 'state' (e.g. needs_review) which we really want to use.

## References

Found great references inside the "Creating Great Localized Experiences with Xcode 11" WWDC video:
    at 26:52 -> Structure of the Notes > Screenshots folder
    at 33:14 -> Structure of the Notes > Screenshots folder
    at 26:31 -> Structure of the localizationStringData.plist file that can be found in the screenshot folders.

As of Summer 2024 I could find, I think one, other WWDC video that shows some xcloc-localization-screenshots-stuff, but I think it was also older and there wasn't any additional information about the structure that xcode expects inside the .xcloc files.

Found working example of .xcloc file with embedded, inline-viewable, screenshots inside in the com.raywenderlich.GetAPet tutorial project.

## Links

You can find reference WWDC-screenshots, handcrafted .xcloc examples, and more in our test project: https://github.com/noah-nuebling/xcode-localization-screenshot-fix/tree/745a70bfbedad9e1cdad6e5ee1628534b9acae2a/CustomImplForLocalizationScreenshotTest/Notes/Examples


