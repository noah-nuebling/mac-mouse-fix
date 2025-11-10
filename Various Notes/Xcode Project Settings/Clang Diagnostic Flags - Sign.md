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
    [Oct 2025] Interesting: The `+` operator doesn't seem to have this footgun. The following works fine. Not sure what's going on.
        ```
        unsigned long x = 10;
        int offset = -3;
        x = (x + offset);

        ```

    Update: [Nov 2025]
        Disabled `-Wsign-compare`. It's too annoying and not often helpful. 
            (Because C stdlib / Cocoa APIs constantly return unsigned ints and when you wanna iterate over them with `int i` it warns you, even though that's fine 99% of the time. Only problem is when you wanna iterate backwards IIRC.)

### Backwards for-loop footgun

    [Sep 2025] These `Wsign-compare` and `-Wsign-conversion` warnings often encourage us to use unsigned ints for for-loops, but this will result in an infinite loop for backwards loops like this one:
    ```
    for (unsigned int i = 10; i >= 0; i--) 
        printf("i: %u\n", i);
    ```
    -> The `i >= 0` condition is always true if i is unsigned!
        ... The `Wsign-compare` and `-Wsign-conversion` warnings may not be such a good idea after all. [Sep 2025] 
        ... Maybe this is a reason to use more for-loop macros (except just loopc which we already use a lot.)


Random thought: [Sep 2025] I feel like unsigned integers are kind of a bad idea. I have no need for them. They only complicate things. I should default to always using signed integers. The only problem is C's integer promotion rules are bonkers and 'promote' signed ints to unsigned, making them underflow if they are negative. Also Apple's APIs tend to return unsigned integers for sizes and other things that can't logically be negative, so you're constantly dealing with unsigned ints.
