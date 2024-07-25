#  Misappropriating XCStrings

XCStrings files are automatically kept in sync with C and Swift source files by Xcode.

However, we want to use them for .md files and for .vue files as well!

# 1. Approach: Lying to Xcode about file types

 It seems we can get Xcode to export NSLocalizedString() macros used in our .md files into .xcstrings files. To do that, it seems we have to set the "Type" of the .md file in the Xcode inspector to something that is processed by the C or Swift compilation toolchain (?).
 
 Here are file "Types" I tested which make Xcode recognize NSLocalizedString() macros. 
 
 - "C Header"
 - "C Preprocessed Source"
 - "C Source"
 - "makefile"
 - "Exported Symbols"

Here are the file "Types" I tested which didn't make Xcode recognize NSLocalizedString() macros.

- Markdown Text
- Plain Text

This approach is hacky but would be ok I think. The main problem is that it seems we have to build the Xcode project in order for the .xcfiles to be updated. Building the Xcode project might be slow to incooperate into the build process in the MMF Website project.  

However, we also found a lower-level approach that should be faster ...

# 2. Approach: Utilizing `xcstringstool`

I saw that there's an xcstringstool clt that Xcode uses as part of its compilation process to extract .strings and .stringsdict files from the .xcstrings files!

The `xcstringstool sync` subcommand can be used to automatically update an .xcstrings file, based on a .stringsdata file!

.stringsdata files aren't documented, and all the .stringsdata files I could find in my build folder didn't contain any actual strings. However, we searched for these files on GitHub and found that when running an iPhone app in the simulator, then Xcode's build folder will contain .stringsdata files! Based on this we could figure out the structure.

The structure of the .stringsdata files is like this:

```
{
  "source": "/Users/Noah/Desktop/StringsdataFileTest/StringsdataFileTest/ContentView.swift",
  "tables": {
    "Localizable": [
      {
        "comment": "",
        "key": "Hello, world!"
      }
    ],
    "WoodenTable": [
      {
        "comment": "youtbe comment hhihihiahooohohohohoh",
        "key": "the.keyyy.eyy",
        "value": "the default value!"
      }
    ]
  },
  "version": 1
}
```

-> I generated this .strings data file by creating an iPhone SwiftUI project in Xcode and then building and running it in an iPhone simulator - after adding the following code into ContentView.swift:

```
…

struct ContentView: View {
    
    var storedString = ""
    
    init() {
        var options = String.LocalizationOptions()
        options.replacements = nil // Don't know what this does
        storedString = String.init(localized: "the.keyyy.eyy", defaultValue: "the default value!", options: options, table: "WoodenTable", bundle: Bundle.main, locale: Locale.current, comment: "youtbe comment hhihihiahooohohohohoh")
    }

…
```  

-> So we can see that the .stringsdata files are json internally, and have a simple structure, so they should be easy to automatically generate.

## `xcstringstool sync` command

Here's an example usage:

/Applications/Xcode.app/Contents/Developer/usr/bin/xcstringstool sync Markdown/Skeletons/Markdown.xcstrings --stringsdata Markdown/Skeletons/Noahs.stringsdata

-> When we update the .xcstrings files like this, new keys from the .stringsdata file are automatically added, and unused keys are marked as stale in the development language. (I have tested this a bit and my observations matched this.) 
    -> Also, values defined in the .stringsdata file are automatically inserted/updated in the .xcstrings for the development language. When the value for the development language changes, all translations receive the state "needs_review". (I think, haven't tested this)

- Another thing to note is that in the Xcode Report Navigator there's a 'Sync Localizations' step which probably does this stuff. But the logs contain almost no info. 

- Anotherrr thing to note that the `xcstringstool sync` command can take several .stringsdata files as input and it can also take several .xcstrings files to merge into. I think the idea behind this is that:
    - There's exactly one .stringsdata file generated for each translatable source file. 
    - Each localizable string in the source files can have a "table" value assigned to it. And each .xcstrings file represents one table. (I remember the 'each .xcstrings file represents one table' bit from the WWDC video about .xcstrings file). 
    -> However, for our usecase we probably don't need this. 

## Other

Here's the command we used to concatenate the .stringsdata files in the Xcode intermediate files, so we can quickly see the content of all the .stringsdata files: (We found they were all blank)

find "/Users/Noah/Library/Developer/Xcode/DerivedData/Mouse_Fix-hdmyobfkwunqnodwaymizmchcbjp/Build/Intermediates.noindex/Mouse Fix.build/Debug/Mac Mouse Fix.build/Objects-normal/arm64" -name "*.stringsdata" -print0 | xargs -0 cat > ./concatenated_stringsdata_files.txt; open ./concatenated_stringsdata_files.txt

When we searched on GitHub for .stringsdata files, here's the searchstring we used: path:".stringsdata" content:"\"Localizable\"" /// We add the "Localizable" to make sure the .stringsdata file actually has content.

The only .stringsdata that had any content were iphone-simulator-build files it seems.
Here's an example: 
https://github.com/Thiagolourenco/MobileFoodUI/blob/87f6833a300d7317fa36ab8c1570c880745c1e13/build/MobileFoodUI.build/Debug-iphonesimulator/MobileFoodUI.build/Objects-normal/arm64/SettigsView.stringsdata#L4

---

BEFORE I FORGET: 

1. 

This Doesn't belong here. But there are 3 command line tools I know of to extract NSLocalizedStrings:

- genstrings (for creating strings files)
- extractLocStrings (for creating strings files)
- xcodebuild -exportLocalizations (for creating .xcloc files)

2. 

Apple has docs for .xcstrings files. (Why have I never seen those before?)
https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog#

3. In JSON, don't put a comma after the last element in a list/dict! I think this messed up my testing at points.
