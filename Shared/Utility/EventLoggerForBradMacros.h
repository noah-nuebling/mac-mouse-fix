//
// --------------------------------------------------------------------------
// EventLoggerForBradMacros.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2025
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "SharedUtility.h"

/// This file contains macros from EventLoggerForBrad that we copy pasted over, before properly merging the EventLoggerForBrad code into MMF.
///     TODO: Merge these when copying over EventLoggerForBrad macros

/// Changes since copying this from EventLoggerForBrad:
///     Updated ifcastn and ifcastpn to properly prevent trying to set the inner variable by moving `const` to the appropriate place in the declaration.

/// scopedvar - helper macro
/// What:   Insert a variable declaration into the following scope.
/// Why:    Useful for implementing other macros – The macro can be used as a 'header' for a scope and insert useful variables into it.
///         -> Otherwise not really useful
/// How:    Uses two nested for-loops. Little hacky. In CPP there's `If Statement with Initializer`, but afaik, in C, this is the only way to insert a declaration into a scope from outside the scope.
///
/// Caution: Using`break` or `continue` inside `scopedvar()`s scope will simply break out of that scope. It won't interact with any enclosing loops (since scopedvar() uses for-loops under-the-hood)
///         > `break` and `continue` also won't work for __any macros that use scopedvar()__ – Don't forget this!
///
/// Examples:
///
///     1. One-liner
///         `scopedvar(int x = 5) printf("%d", x);  // x only exists for this printf`
///
///     2. With { braces }
///         ```
///         scopedvar(NSMutableString *str = [NSMutableString string]) {    // str only exists inside { ... }
///             [str appendString: @"Hello"];
///             [str appendString: @" World"];
///             NSLog(@"%@", str);
///         }
///         ```
    
#define scopedvar(declaration...)                                                                       /** vararg... so the declaration may contain commas without being interpreted as multiple macro args */\
    for (int __scopedvar_oncetoken = 0;     !__scopedvar_oncetoken;)                                    \
    for (declaration;                       !__scopedvar_oncetoken; __scopedvar_oncetoken = 1)          

#define scoped_preprocess(statements...) /** Untested. Not well thought-through. Don't use this. Could perhaps be useful for validation or compile-time-checks of a scopedvar(). Since this is an if statement, the macro args could also easily prevent the scope from being executed entirely. */\
    if (({ statements }))

/// Helper macro: bitpos(): Get the position of the bit in a one-bit-mask
///     - (a one-bit-mask is an integer with a single bit set – it specifies what that bit means in a bitflags datatype)
///     - Example usage: This expression will always evaluate to true: `mask == (1 << bitpos(mask))` (Given that exactly 1 bit is set in `mask`)
///     - If `mask` is compile-time-constant, this whole macro is compile-time-constant! Therefore you can use it inside `static_assert()` and other places.
#define bitpos(mask) (                                                  \
    (mask) == 0               ? -1 :                                    /** Fail: less than one bit set */\
    ((mask) & (mask)-1) != 0  ? -1 :                                    /** Fail: more than one bit set (aka not a power of two) */\
    __builtin_ctz(mask)                                                 /** Sucess! – Count trailling zeros*/ \
)

/// safeindex() - bound-checked array access with fallback value
///     - Works with any subscriptable type: C arrays, C Strings, NSArray, etc.
///     - Usage example:
///         ```
///         const char *fruits[] = {"apple", "banana", "orange"};
///         const char *fruit = safeindex(fruits, arrcount(fruits), 3, "<no fruit at index 3>");`
///         // Returns "<no fruit at index 3>"
///         ```
#define safeindex(list, count, i, fallback) (typeof((list)[0])) ({ \
    __auto_type __i = (i); \
    __auto_type __cnt = (count); \
    ((0 <= __i) && (0 < __cnt) && (__i < __cnt)) ? (list)[__i] : (fallback); /** We're making sure `count` and `i` are both positive before comparing them. Otherwise we might have subtle issues because `(int)-1 < (unsigned int)1` is false in C.*/\
})

/// ifcast & ifcastn
///     NOTE: Swapped out `varname` and `classname` args compared to EventLoggerForBrad – to be consistent with isclass() macro arg order.
/// What:   Check if objc object O is of class C. If so, cast O to C and make O available in a dedicated scope.
/// Why:    Makes working with objc objects of unknown type more concise.
/// Note:   Similar to Swift if-let-as statement.
///
/// Caution: Uses `scopedvar()` macro, so will behave unexpectedly with `break` and `continue` statements.
///     ... Maybe that's a good reason not to use these...
///
/// Examples:
///
/// 1. ifcast
///     ```
///     id obj = @"hello";
///     ifcast(obj, NSString) {                    // obj is now an (NSString *) inside the scope
///         NSLog(@"Length: %lu", obj.length);     // Can use NSString methods directly
///     }
///     ```
/// 2. ifcastn
///     ```
///     id obj = @"hello";
///     ifcastn(obj, NSString, str) {               // Re(n)ame obj to str inside the scope
///         NSLog(@"Length: %lu", str.length);
///         obj = nil;                              // obj can be overriden (it would be shadowed when using ifcast())
///     }
///     ```
/// 3. if-else-statement
///     ```
///     ifcast          (obj, NSArray)                     NSLog(@"Array: %@", obj.firstObject);
///     else ifcast     (obj, NSDictionary)                NSLog(@"Dict: %@", obj.allKeys);
///     else ifcastn    (obj, NSString, str)
///     {
///         NSString *upper = [str uppercaseString];
///         NSLog(@"Uppercased string: %@", upper);
///     }
///     else                                                NSLog(@"Unknown class: %@", [obj className]);
///     ```
///
///     Equivalent macro-free code: (more boilerplate)
///         ```
///         if      ([obj isKindOfClass: [NSArray class]])        NSLog(@"Array: %@", ((NSArray *)obj).firstObject);
///         else if ([obj isKindOfClass: [NSDictionary class]])   NSLog(@"Dict: %@", ((NSDictionary *)obj).allKeys);
///         else if ([obj isKindOfClass: [NSString class]])
///         {
///             NSString *str = (id)obj;
///             NSString *upper = [str uppercaseString];
///             NSLog(@"Uppercased string: %@", upper);
///         }
///         else                                                        NSLog(@"Unknown class: %@", [obj className]);
///         ```
///
///         ... Actually not that much boilerplate –> Probably shouldn't use these macros.

#define ifcastn(varname, classname, newvarname)                                                         \
    if (varname && [varname isKindOfClass: [classname class]])                                          \
        scopedvar(id __ifcast_temp = varname)                                                           /** The temp var allows us to shadow `varname` if `newvarname` == `varname` */ \
            scopedvar(classname *_Nonnull const __attribute__((unused)) newvarname = __ifcast_temp)     /** 1. Notice `_Nonnull`. We're not only guaranteed the class but also the non-null-ity of newvarname || 2. Notice __attribute__((unused)) – it turns off warnings when the macro user doesn't use newvarname. 3. Notice `const` it warns the user when they try to override the inner variable. (Since they're probably trying to override the outer one.) */ \

#define ifcast(varname, classname)  \
    ifcastn(varname, classname, varname)

/// ifcastp & ifcastpn
///     Works just like ifcast & ifcastn but for objc protocols instead of classes.

#define ifcastpn(varname, protocolname, newvarname)                                                             \
    if (varname && [varname conformsToProtocol: @protocol(protocolname)])                                        \
        scopedvar(id __ifcast_temp = varname)                                                                   \
            scopedvar(id<protocolname> _Nonnull const __attribute__((unused)) newvarname = __ifcast_temp)

#define ifcastp(varname, protocolname)  \
    ifcastpn(varname, protocolname, varname)


/// ------------------------------------

/// Debug-printing enum function
///     ([Apr 2025] Doesn't really belong in EventLoggerForBrad*Macros*  but oh well)

static inline NSString *_Nonnull bitflagstring(int64_t flags, NSString *const _Nullable bitToNameMap[_Nullable], int bitToNameMapCount) {
    
    /// bitflag-printer utility
    ///     [Apr 2025] Copied over from EventLoggerForBrad
    
    /// Build result
    NSMutableString *result = [NSMutableString string];
    
    int i = 0;
    while (1) {
        
        /// Break
        if (flags == 0) break;
        
        if ((flags & 1) != 0) { /// If `flags` contains bit `i`
            
            /// Insert separator
            if (result.length > 0) {
                [result appendString:@" | "];
            }
            
            /// Get string describing bit `i`
            NSString *bitName = safeindex(bitToNameMap, bitToNameMapCount, i, nil);
            NSString *str = (bitName && bitName.length > 0) ? bitName : stringf(@"(1 << %d)", i);
            
            /// Append
            [result appendString:str];
        }
        
        /// Increment
        flags >>= 1;
        i++;
    }
    
    /// Wrap result in ()
    result = [NSMutableString stringWithFormat:@"(%@)", result];
    
    /// Return
    return result;
}
