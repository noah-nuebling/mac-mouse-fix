# CodeStyle


## Enums

[Jan 2025] I just thought about how to best define and name enums, and I think this is pretty good:
    ```
    typedef enum : int {
        kMFMyEnum_First,
        kMFMyEnum_Second,
        kMFMyEnum_Third,
    } MFMyEnum;
    
    NSString *MFMyEnum_ToString(MFMyEnum case) {
        static const NString *strings[] = {
            [kMFMyEnum_First]  = @"First",
            [kMFMyEnum_Second] = @"Second",
            [kMFMyEnum_Third]  = @"Third",
        };
        return safeindex(strings, arrcount(strings), case, stringf(@"%d", case));
    }
    ```

Benefits:
- Consistently prefix enum cases with the enum name, for nice autocomplete
- Use underscore to separate the enum name from the case names
- Use k prefix because Apple uses it and for nicer autocomplete (probably a bit unnecessary?)
- MF prefix for our stuff helps with autocomplete.
- Defining a `_ToString` function is really nice for debugging. Is a bit boilerplate-y but should be easy with multi-cursor editing. 
    You could use X macros or foreach macros to avoid repeating yourself but I think that's too complicated.

Such a `_ToString` function can also be added to existing enums from Apple's libraries – to help with debugging.

Alternatively to the ToString function, you could just define a bunch of NSString constants:
    ```
    typedef MFMyEnum NSString *
        static MFMyEnum kMFMyEnum_First    = @"First",
        static MFMyEnum kMFMyEnum_Second   = @"Second",
        static MFMyEnum kMFMyEnum_Third    = @"Third",
    ```
    Pro: 
        - This is a bit more concise than defining a separate `_ToString` function.
        - The enum cases can be stored inside objc collections without boxing
    Contra:
        - Putting this into .h would be a little inefficient, since each compilation unit has its own copy of static variables. 
            Probably not a big deal though. You could also make them non-static by declaring them in .h and defining them in .m
        - You don't get compiler checks on switches. I've never found a use for that though.
        - After you serialize these, you need to *not* modify the string constant, which might make renaming awkward. 
            (For int-based enums you need to not modify the order after serializing, unless you explicitly assign numbers to the cases) 

What about Apple's macros like `NS_ENUM` or `NS_TYPED_ENUM`?
    I don't remember the details but IIRC they just add magic to the Swift imports.
   ... I think they rename and namespace the enum-cases in Swift which makes them harder to search for in the codebase, and I think there were other issues, too.
