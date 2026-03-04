//
// --------------------------------------------------------------------------
// vardesc.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2026
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import "SharedHelperMacros.h"

/// `vardesc` -> (var)iable (desc)ription – Helps you quickly debug-print local variables
///  Example usage:
///     ```
///     NSLog(@"Local variables %@", vardesc(some_int, some_object));
///     // Prints:
///     // Local variables: {
///     //     some_int = 79;
///     //     some_object = Description of the object!;
///     // }
///     ```
///  Background: This is inspired by `NSDictionaryOfVariableBindings()` – But this is better-suited for debug-printing because: Dictionaries don't preserve order. Dictionaries can't contain nil. Using NSDictionaryOfVariableBindings requires importing NSLayoutConstraint.h
///  Performance: It's fine. See `vardesc_benchmarks.m`
///  Is this worth the complexity?: Not sure. `FOR_EACH` macro and the `mfbox` stuff is a little complex. And it only saves a few keystrokes. But IIRC I found this nice for some debugging workflows in mf-xcloc-editor [Mar 2026]

NSString *_Nullable _vardesc(NSString *__strong *keys, id __strong *objects, int count);

#define vardesc(vars...)  ({ \
    id _keys[]    = { FOR_EACH(@TOSTR, (,), vars) };                                    /** Using a C array instead of NSArray to be able to capture nil. NSDictionaryOfVariableBindings uses a variadic function. */\
    id _objects[] = { FOR_EACH(_mfbox, (,), vars) };  \
    _vardesc(_keys, _objects, (sizeof(_keys)/sizeof(_keys[0])));  \
})

/// `_mfbox` – Helper for vardesc.
///     Works like `@()` (Boxes primitive types in objects) but you can pass in ANYTHING. (Any C struct, and even objc objects.)

#define _mfbox(thing) ({                                     \
    typeof(thing) _thing = (thing);                         \
    __mfbox((void *)&_thing, @encode(typeof(_thing)));       \
})
id __mfbox(void *thing, char *objc_type);
