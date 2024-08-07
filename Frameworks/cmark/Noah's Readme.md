
"cmark" c markdown parser dynamic library 

- Added this on 08.08.2024

- The static libary (libcmark.a) was built from commit 07c7662ddbaa04f868354ae69979af521384a546 of branch 'cjk' of the 'commonmark/cmark' repo
    - Link to the commit this is copied from: https://github.com/commonmark/cmark/tree/07c7662ddbaa04f868354ae69979af521384a546
    - The 'cjk' branch is a development branch that contains a fix for whitespace-related issues in chinese, japanese and korean (cjk) scripts, which don't use whitespace in the way that the markdown parser expects. 
        We've been having various issues in the Chinese translation of MMF due to this, so we'll see if this development branch fixes things.
    - Also see this discussion in the 'commonmark-spec' repo which the 'cjk' branch is based on: https://github.com/commonmark/commonmark-spec/issues/650#issuecomment-1939237484
    - How to build cmark:
        1. Download the cmark repo, then follow the instructions from their readme to create an xcode project using the `cmake` clt.
        2. In the cmake xcode project settings, go to the the library target (called 'cmark'), then change the architecture to universal, 
            and the minimum deployment target to the same as Mac Mouse Fix (10.14.4 at the time of writing) (change settings on the target, not just the project!, since the target overrides project settings) 
        3. Build the library target, after setting its build configuration to 'Release' (it's 'Debug' by default) and setting the run destination as 'Any Mac (arm64, x86_64)'
        4. Copy the built library target (called 'libcmark.a') to Mac Mouse Fix
        5. Copy necessary cmark headers to Mac Mouse Fix. This includes the 'cmark.h' header from source code and the 'cmark_export.h' and 'cmark_version.h' headers from the build products. 
            (This is weird, I'm not sure I'm doing this wrong)
        6. In the Mac Mouse Fix project settings, add libcmark.a as a static library to the main app and helper targets. 

Other: 
- Before this, we had been using apple/swift-markdown, but I really want to get rid of swift libraries since I think it'll improve speed and compile times, give us more control 
    to fix issues like the cjk parsing, and also it's more fun to use the c library directly!
- Using the cjk branch fixes some parsing issues we had with Chinese. We already fixed most of the parsing issues in the recent commits (today is 08.08.2024) by exchanging `__` 
    for emphasis with `**`. But on the license sheet there was a string that said sth like ```**'ABCEFG'** is not a known license key. Please try a different one```, and this 
    still didn't parse properly in Chinese, because the combination of `'` and lack of spaces in Chinese somehow messed it up. But now with the new cjk markdown parser, everything
     seems to be working well!

