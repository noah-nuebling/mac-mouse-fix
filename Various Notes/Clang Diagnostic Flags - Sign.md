# Clang Diagnostic Flags - Sign

Enabled `-Wsign-compare` and `-Wsign-conversion` warnings on [Jul 2025].

### `a<b` footgun

    `Wsign-compare` should prevent this footgun I was worried about where following evaluates to false, because the int gets converted to unsigned int and then underflows:
        ```
        int a = -1;
        unsigned int b = 1;
        int result = (a<b); // false!
        ```
        
    [Jul 2025] There are several mentions of the `a<b` footgun in SharedMacros.h and perhaps elsewhere. Maybe update/remove those, now that we found solution.
