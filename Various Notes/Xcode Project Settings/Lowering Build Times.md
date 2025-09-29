


Took some measures to lower build times: [Sep 2025]

Context: [Sep 2025]
    Incremental build times were like 11 seconds which was a hindrance when iterating on the UI. 
    Now it's < 4 seconds which feels nice. 

Measures:
    - Set DEBUG_INFORMATION_FORMAT from 'DWARF with dSYM file' to just 'DWARF' (for DEBUG builds)
        - Saved like 1 second
    - Turned off ENABLE_DEBUG_DYLIB 
        - Saved like 6 seconds (!)
        - This turns off SwiftUI previews afaik
        - From my shallow analyisis, most of the extra time is spent on signing 4 extra targets
            (See: https://developer.apple.com/documentation/xcode/understanding-build-product-layout-changes)
    - Added a 'Fast Build' build scheme  
        - Doesn't attach a debugger
            - Currently nothing else [Sep 2025]
