# CodeStyle


## #pragma once

[Feb 2025] We don't actually need `#pragma once`, since we're using `#import` everywhere, 
which already solves the duplicate-header-inclusion problem.

## `NS_ASSUME_NONNULL`

Don't use this. We usually wan't our objc methods to be nullable/null-safe. 
When we return nil from a method, it's is actually dangerous if Swift imports it as a non-optional.
    Update: [May 2025] Since we enabled -Wnullable-to-nonnull-conversion warnings, I'm not sure this is dangerous anymore. (See `Xcode Nullability Settings.md`)

Unfortunately there's only `NS_ASSUME_NONNULL` and no `NS_ASSUME_NULLABLE`, which is what we want.

## Spaces in objc methods

[Feb 2025] Gnustep code puts spaces after: (the)colons in objc methods 
    See https://github.com/gnustep/libs-base/blob/a043cb077cc6e4ef9cf7d27b4883ff971331b800/Source/NSDictionary.m#L320
    This is more readable than the typical Apple style I think. Especially with nested method calls.
    Maybe I'll make a habit of this.
    
    Example:
        Gnu style:   `[aCoder encodeObject: [self objectForKey: key] forKey: s];`
        Apple style: `[aCoder encodeObject:[self objectForKey:key] forKey:s];`
        -> Gnu makes it easier to visually scan all the parts that belong to a method signature, and where the nested call starts/ends. 

    Update: [Apr 2025] You're constantly fighting Xcode's autocomplete if you try to do this, so we gave up on it.

## Enums

[Jan 2025] I just thought about how to best define and name enums, and I think this is pretty good:
    ```
    typedef enum : int {
        kMFMyEnum_First  = 0,
        kMFMyEnum_Second = 1,
        kMFMyEnum_Third  = 2,
    } MFMyEnum;
    
    NSString *MFMyEnum_ToString(MFMyEnum case) {
        static const NString *map[] = {  
            [kMFMyEnum_First]  = @"First",
            [kMFMyEnum_Second] = @"Second",
            [kMFMyEnum_Third]  = @"Third",
        };
        NSString *result = safeindex(map, arrcount(map), case, nil);
        return result ?: stringf(@"%d", case);
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
    typedef NSString * MFMyEnum;
        MFMyEnum static const kMFMyEnum_First    = @"First";
        MFMyEnum static const kMFMyEnum_Second   = @"Second";
        MFMyEnum static const kMFMyEnum_Third    = @"Third";
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
   -> Don't use
   Also see: 
    - MFStringEnum macros [Apr 2025] (I might delete them at some point.)

## Dict-of-blocks

[Jul 2025]

You can emulate a switch-statement that works on any objc object by using an NSDictionary filled with blocks. 

Example:

    ```
    NSDictionary <NSString *, void (^)(void)> *dictswitch = @{
        @"A": ^{ printf("Case A!\n"); },
        @"B": ^{ printf("Case B!\n"); },
    };
    if (dictswitch[value]) dictswitch[value]();
    else assert(false);
    
    ``` 

I've benchmarked the pattern a bit inside MarkdownParser.m, and it didn't seem to be any slower than a native C-switch. I think there must be some crazy clang optimizations to make it this fast.

However, in practise, I'd still prefer just use an if-else with macros. Benefits: You don't have to rely on magical clang optimizations to make this fast, and it's about as concise.

Example:

    ```
    #define xxx(value_) else if ([value_ isEqual: value])
    if ((0)) ;
    xxx(@"A")   printf(@"Case A!\n");
    xxx(@"B")   printf(@"Case B!\n");
    else        assert(false);
    #undef xxx
    ```
    
For switching over integers we can also use our `bcase` and `fcase` macros, which are a thin wrapper around real, native C switches. 

## Temporary local macros

[Jul 2025]

Sometimes it's nice to compress boilerplate with a local macro, that you #undef right after. 
I tend to call these macros `xxx`. 
Not sure why, but it seems to work better than trying to give it a more descriptive / longer name.
