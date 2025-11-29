# Automatic Localization Screenshots

## History [Apr 2025]

(Writing this overview way after the fact because I came back to this in [Apr 2025]|(we worked on this in 2024 IIRC) and was confused about the details.

So IIRC, we worked on 2 different repos, before merging the results into MMF:
    - **xcode-localization-screenshot-tests**
        https://github.com/noah-nuebling/xcode-localization-screenshot-tests
        - Here we tried to get Xcode to do it for us (Some WWDC talk said Xcode could do it)
        - But we couldn't get it to work and gave up.
    - **xcode-localization-screenshot-fix**
        https://github.com/noah-nuebling/xcode-localization-screenshot-fix
        - Here we tried (and succeeded) to implement the feature ourselves.
            - (And before that, we created manual .xcloc files with included screenshots)
        - Also search for `CustomImplForLocalizationScreenshotTest` -> Name of the Xcode project in this repo.
        - IIRC, we tried 2 approaches:
            1. We tried to intercept all the UI-string-setters in AppKit (Including the ones called during .nib-file loading.)
                - This kinda worked, but was very brittle and a lot of code.
                - We abandoned the approach but a lot of useful utility/debugging functions came out of this
            2. We used 'steganography' to add invisible codes to all localizable strings
                - Much simpler and more robust approach. This is what's implemented in mmf now.
                - Mystery: [Apr 12 2025] I can't find steganography stuff in xcode-localization-screenshot-fix. 
                    Perhaps there was a 3rd repo we forgot about, or we wrote it directly in mac-mouse-fix?
    - Is there anything useful left in those repos?
        - **xcode-localization-screenshot-tests**:
            - Contains history and notes of all the attempts to get Xcode to export the screenshots for us. (Which all failed)
            - Interesting stuff that's left:
                - Several test Xcode projects
                    - Interesting: We could test these again and see if Xcode can properly export screenshots now (or if we can find a mistake in our tests, that prevented Xcode from exporting the screenshots)
                - README.md
                    - Interesting: Contains "most the references and info I could find on how to export .xcloc files with localization screenshots included."
                    - History of how we came up with manual way to create .xcloc files with included screenshots. 
                        - (Manually created .xcloc files and references for how to do that are found in **xcode-localization-screenshot-fix** > 'Examples' folder)
        - **xcode-localization-screenshot-fix**:
            - We made commits and comments about 'abandoning' it, and we moved utility functions into PortToMMF folder and then moved them into MMF. 
            - Interesting stuff that's left: 
                - NibDecodingAnalysis.m
                    - This hooks into .nib-file decoding to annotate instantiated UIElements with localized-string-keys. 
                    - Interesting: This encodes lots of knowledge about the internal structure of .nib files, which might be useful at some point.
                        - E.g. it prints the entire structure of the object-tree inside an Nib file. 
                - Lots of 'business logic' for the old pre-steganography approach
                    - SystemRenameTracker.m, UIStringChangeDetector.m, NSLocalizedStringRecord.m, AnnotationUtility.m 
                    - Interesting: Demonstrates advanced uses of some of the other utility functions which we ported into MMF, such as: swizzleMethod(), swizzleMethodOnClassAndSubclasses(), getImagePath(), formatStringRecognizer(), ...
                    - Interesting: Demonstrates how *not* to annotate UIElements with localized-string-keys (Our new approach, steganography, is better)
                - UIStringChangeDetector.m
                    - Interesting: List of all (?) UIString-setter-methods across AppKit.
                - AnnotationUtility.m
                    - Interesting: List of all (?) user-facing (and therefore localizable) strings on objects (in AppKit (?))
                        Even obscure ones such as `NSAccessibilityMarkerTypeDescriptionAttribute` or `paletteLabel`.
                - `Notes > AppKitSetters` folder
                    - Notes on trying to find all the UIString-setter-methods inside of AppKit (we got pretty far)
                    - Interesting: This is an overview of all (?) the UIElements in AppKit
                    - Interesting: Shows techniques for searching frameworks for specific symbols.
                    - Interesting: (?) Shows patterns in setter methods across AppKit
                - `Notes > Examples` folder
                    - This contains hand-crafted .xcloc archives
                        - and screenshots from WWDC talks serving as reference - which allowed us to figure out how to create the .xcloc files. 
                    - Interesting: Good reference for programmatically generating .xcloc files.
                        - [Apr 2025] In current impl for creating .xcloc files, which we wrote in 2024, IIRC we duplicate images dozens of times to work around Xcode bug. We could use this to test if that bug has been fixed, maybe.
                - 'External' folder
                    - Contains private declarations for classes 
                        - Classes we found in .nib files e.g. UINibDecoder, NSNibAXAttributeConnector, NSIBHelpConnector, NSWindowTemplate, and more.
                        - AppKit classes like NSToolbarItemViewer, or NSCell
        -> Can't see any other interesting stuff inside **xcode-localization-screenshot-tests** or **xcode-localization-screenshot-fix** (as of [Apr 12 2025]). Possibl that I missed sth.

## Figuring out xcloc screenshot structure
    
    Update: [Apr 2025] These notes seem to be sort of a summary of some info from **xcode-localization-screenshot-tests** and **xcode-localization-screenshot-fix** repos which we seem to have custom-written for the **mac-mouse-fix** repo.

To figure out the structure that an .xcloc file needs to have to make screenshots show up inline in the Xcode editor, I made a handcrafted example of an .xcloc file with embedded screenshots. See de-manual-edit.xcloc in our CustomImplForLocalizationScreenshotTest test project.

Caveats:
If n strings appeared in the same screenshot we had to include n copies of the screenshot.
Since if several strings referenced the same screenshot file, the red highlighter rectangle that highlights the text in the screenshot broke in Xcode 16.0 Beta 2.
This didn't happen in Loca Studio, but Loca Studio doesn't support the 'state' (e.g. needs_review) which we really want to use.

### References

Found great references inside the "Creating Great Localized Experiences with Xcode 11" WWDC video:
    at 26:52 -> Structure of the Notes > Screenshots folder
    at 33:14 -> Structure of the Notes > Screenshots folder
    at 26:31 -> Structure of the localizationStringData.plist file that can be found in the screenshot folders.

As of Summer 2024 I could find, I think one, other WWDC video that shows some xcloc-localization-screenshots-stuff, but I think it was also older and there wasn't any additional information about the structure that xcode expects inside the .xcloc files.

Found working example of .xcloc file with embedded, inline-viewable, screenshots inside in the com.raywenderlich.GetAPet tutorial project.

### Links

You can find reference WWDC-screenshots, handcrafted .xcloc examples, and more in our test project: https://github.com/noah-nuebling/xcode-localization-screenshot-fix/tree/745a70bfbedad9e1cdad6e5ee1628534b9acae2a/CustomImplForLocalizationScreenshotTest/Notes/Examples


