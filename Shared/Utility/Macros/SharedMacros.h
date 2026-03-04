//
//  SharedMacros.h
//  EventLoggerForBrad
//
//  Created by Noah Nübling on 10.02.25.
//

///     [Mar 4 2026] Removed a lot of stuff from here.
///         New philosophy: I'm over testing what's possible with macros just for the sake of it. New macros need to be simple and flexible (-> worth their complexity). And I'll only add them when I actually need them.
/// -------------------------------------

#import <Foundation/Foundation.h>
#import "SharedHelperMacros.h"

#define range(i, count) (int i = 0; i < (count); i++) /// for-loop sugar

#define arr(expr, header) ({ /** Python style 'list-comprehension' sugar. */\
    auto _result = [NSMutableArray new]; \
    header { [_result addObject: (expr)]; } \
    _result; \
})
#define any(expr, header) ({ /** Python-style 'any()' sugar */\
    auto _result = false; \
    header { if (expr) { _result = true; goto _end; } } \
    _end: _result; \
})
#define arrmax(expr, header) ({  /** Python-style max-item sugar || Not sure this is worth the complexity. [Mar 4 2026] */\
    double _result = -INFINITY; \
    header { auto _expr = (expr); if (_expr > _result) _result = _expr; } \
    _result; \
})

/// `mfonce` – abbreviation for `dispatch_once`
///     Less complicated/custom than `MFOnceMacro.h` [Nov 2025]
///     Originally from `mf-xcloc-editor`
///     Usage example:
///         `mfonce(mfoncet, ^{ <Stuff you wanna do once> });`

#define mfonce dispatch_once
#define mfoncet ({ static dispatch_once_t onceToken; &onceToken; })

/// `mferror` macro
///     Shorthand for creating an NSError with a debug description (Uses `NSDebugDescriptionErrorKey`)
///     Usage example:
///         `mferror(NSCocoaErrorDomain, NSPropertyListReadCorruptError, @"Deserialized plist object from %@ is not a mutable dictionary. Is %@", url, [result class]);`

#define mferror(domain_, code_, formatAndArgs_...) \
    [NSError errorWithDomain: (domain_) code: (code_) userInfo: @{ NSDebugDescriptionErrorKey: stringf(@"" formatAndArgs_) }]

/// `nowarn_push()` and `nowarn_pop()` macros:
///     Temporarily disable clang warnings
///     Example usage:
///         Silence *all* warnings
///             ```
///             nowarn_push();
///             <Code that triggers warnings>
///             nowarn_pop();
///             ```
///         Silence specific warnings
///                 (See https://clang.llvm.org/docs/DiagnosticsReference.html)
///             ```
///             nowarn_push(-Wundeclared-selector);
///             <Code that triggers -Wundeclared-selector warnings>
///             nowarn_pop();
///             ```

#define nowarn_push(w)                                                     \
    _Pragma("clang diagnostic push")                                        \
    IFEMPTY     (w, _Pragma("clang diagnostic ignored \"-Weverything\""))   \
    IFEMPTY_NOT (w, _Pragma(TOSTR(clang diagnostic ignored #w)))

#define nowarn_pop()                                                        \
    _Pragma("clang diagnostic pop")

/// array count convenience
#define arrcount(x) ({ static_assert(!_isobject(x), "Use a method like -[count] for objects."); (sizeof(x) / sizeof((x)[0])); })

/// `isclass` macro
///     Shorthand for `-[isKindOfClass:]` and `-[isSubclassOfClass:]`
#define isclass(x, classname) [[(x) class] isSubclassOfClass: [classname class]]

/// `isclassd` macro
///     `isclass`, but (d)ynamic. Meaning the compiler doesn't have to know about the class we're comparing against.
#define isclassd(x, classname) [[(x) class] isSubclassOfClass: NSClassFromString(classname)]

/// stringf – (string) (f)ormatting convenience.
///  Notes:
///     - Don't use `stringf(@"%s", some_c_string)`, it breaks for emojis and you can just use `@(some_c_string ?: "")` instead – (Update [2025] – `?: ""` since `@()` crashes if you pass it NULL.)
#define stringf(format, ...) [NSString stringWithFormat: (format), ## __VA_ARGS__]

/// astringf – like (stringf) but for NS(A)ttributedStrings.
///     Only supports inserting other NSAttributedStrings with `%@` [Sep 2025]
///     It's a wrapper around `[NSAttributedString attributedStringWithAttributedFormat:]` defined in `NSAttributedString+Additions.h` [Sep 2025]

#define astringf(format, args_...) ({                   \
    NSAttributedString *__strong _args[] = { args_ };   \
    id _format = (format);                              \
    _format = isclass((_format), NSString) ? [_format attributed] : (_format); /** Automatically map NSString to NSAttributedString for convenience */  \
    [NSAttributedString attributedStringWithAttributedFormat: _format args: _args argcount: arrcount(_args)];                        \
})

///
/// Define xxxMFLocalizedString macro,
///     which is replaced with nothing by the preprocessor.
///     The purpose of this is to 'turn off' MFLocalizedString() statements that we don't need at the moment.
#define xxxMFLocalizedString(...)

/// Logical implication operator (Usually written as `a -> b`).
///     Meaning "if a is true, then b must be true as well."
///     Example: `assert(ifthen(it_rains, street_is_wet));`
#define ifthen(a, b) (!(a) || (b))

/// Helper macro: bitpos(): Get the position of the bit in a bitmask
///     - We use this for debug-printing bitflags [Mar 2026]
///     - (a one-bit-mask is an integer with a single bit set – it specifies what that bit means in a bitflags datatype)
///     - Example usage: This expression will always evaluate to true: `mask == (1 << bitpos(mask))` (Given that exactly 1 bit is set in `mask`)
///     - If `mask` is compile-time-constant, this whole macro is compile-time-constant! Therefore you can use it inside `static_assert()` and other places.
#define bitpos(mask) (                                                  \
    __builtin_popcount(mask) != 1 ? -1 :                                /** Fail: Not exactly one bit set. */\
    __builtin_ctz(mask)                                                 /** Sucess! – Count trailling zeros*/ \
)

/// Autotype convenience
///     Just `auto` wouldn't be searchable (and might produce conflict with C++ `auto` keyword?)
///         Update: [Sep 2025] Actually I don't care about greppability for this. Renamed to `auto`
///         Update: [Mar 2026] Could just use C23 where auto is a native feature
#define auto __auto_type

/// safeindex() - bound-checked array access with fallback value
///     - Works with any subscriptable type: C arrays, C Strings, NSArray, etc.
///     - Usage example:
///         ```
///         const char *fruits[] = {"apple", "banana", "orange"};
///         const char *fruit = safeindex(fruits, arrcount(fruits), 3, "<no fruit at index 3>");`
///         // Returns "<no fruit at index 3>"
///         ```
#define safeindex(list, count, i, fallback) /*(typeof((list)[0]))*/ ({          \
    __auto_type __i = (i);                                                      \
    __auto_type __cnt = (count);                                                \
    nowarn_push(-Wsign-compare)                                                 /** Addressing issues by checking that both i and count are > 0 before comparing them [Oct 2025] */\
    nowarn_push(-Wnullable-to-nonnull-conversion)                               /** -Wnullable-to-nonnull-conversion triggers here when the fallback is NULL (nonsensically, I think). Guess these quirks are why it's not enabled by default. See `Xcode Nullability Settings.md` */    \
    ((0 <= __i) && (0 < __cnt) && (__i < __cnt)) ? (list)[__i] : (fallback);    /** We're making sure `count` and `i` are both positive before comparing them. Otherwise we might have subtle issues because `(int)-1 < (unsigned int)1` is false in C.*/\
    nowarn_pop()                                                                \
    nowarn_pop()                                                                \
})

/// NULL-safe wrappers around common CF methods
#define MFCFRetain(cf)           (typeof(cf))  ({ __auto_type __cf = (cf); (!__cf ? NULL : CFRetain(__cf)); })                                                                  /// NULL-safe CFRetain || Note: Is a macro not a function for generic typing.
#define MFCFAutorelease(cf)      (typeof(cf))  ({ __auto_type __cf = (cf); (!__cf ? NULL : CFAutorelease(__cf)); })                                                             /// NULL-safe CFAutorelease || Dicussion: Probably use CFBridgingRelease() instead (it is already NULL safe I think.). Autorelease might be bad since autoreleasepools aren't available in all contexts. E.g. when using `dispatch_async` with a queue that doesn't autorelease. Or when running on a CFRunLoop which doesn't drain a pool after every iteration. (Like the mainLoop does) See Quinn "The Eskimo"s write up: https://developer.apple.com/forums/thread/716261
#define MFCFRelease(cf)          (void)        ({ __auto_type __cf = (cf); if (__cf) CFRelease(__cf); })                                                                        /// NULL-safe CFRelease
#define MFCFEqual(cf1, cf2)      (Boolean)     ({ __auto_type __cf1 = (cf1); __auto_type __cf2 = (cf2); ((__cf1 == __cf2) || (__cf1 && __cf2 && CFEqual(__cf1, __cf2))); })     /// NULL-safe CFEqual

/// mfsign()
///     - Returns 1 if positive, -1, if negative, 0 otherwise.
#define mfsign(x) (int) ({ __auto_type __x = (x); (__x > 0) - (0 > __x); })

/// `bcase()`/`fcase()` macros
///     - Use these inside switches instead of `case` and `default` for more concise syntax
///     - `bcase()` automatically (b)reaks after each case! (Treat this as the default)
///     - If you ever do need to (f)all through, use `fcase()`.
///     - When you pass 0 arguments to bcase()/fcase(), they expand to the 'default' case.
///
/// Example usage:
///     ```
///     switch (x) {
///         bcase (A):          doA();
///         bcase (B, C):       doBC();
///         fcase (D):          doBCD();
///         bcase ():           doDefault();
///     }
///     ```
///     ... This expands to:
///         ```
///         switch (x) {
///             break; case A:          doA();       // The leading break statement is simply ignored
///             break; case B: case C:  doBC();
///                    case D:          doBCD();     // Since we used fcase(), there's no break statement, and we (f)all through from the previous case.
///             break; default:         doDefault(); // 0 arguments expand to the `default` case
///         }
///         ```
///     ... Which is equivalent to the traditional style of writing this switch:
///         ```
///         switch (x) {
///             case A:
///                 doA();
///                 break;
///             case B:
///             case C:
///                 doBC();
///             case D:
///                 doBCD();
///                 break;
///             default:
///                 doDefault();
///         }
///         ```
/// Meta:
///     - [Feb 2025]
///         These macros are a bit complex for what they do – you could achieve similar conciseness and clarity for 95% of cases (ha ha) with a simple `#define bcase break; case`.
///         However, then you'd still have to use `case` both to match multiple values *and* to get fallthrough behavior.
///         I think using bcase by default, fcase to get fallthrough, and using comma-separated-list to match multiple values is significantly nicer and clearer.
///         -> So we'll stick with this complicated implementation for now.
///             That way we can do anything we'd ever wanna do with switches using `bcase()`/`fcase()` – which has very clear semantics, and we'd never have to go back to using the raw `case` keyword for anything.

/// fcase – (f)allthrough variant

#define _fcase_0()              default
#define _fcase_1(x)             case x
#define _fcase_2(x, rest)       case x: _fcase_1(rest)
#define _fcase_3(x, rest...)    case x: _fcase_2(rest)
#define _fcase_4(x, rest...)    case x: _fcase_3(rest)
#define _fcase_5(x, rest...)    case x: _fcase_4(rest)
#define _fcase_6(x, rest...)    case x: _fcase_5(rest)
#define _fcase_7(x, rest...)    case x: _fcase_6(rest)
#define _fcase_8(x, rest...)    case x: _fcase_7(rest)
#define _fcase_9(x, rest...)    case x: _fcase_8(rest)

#define _fcase_selector(_dummy_, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, macroname, ...) macroname

#define fcase(values...) \
    _fcase_selector(_dummy_, ## values, _fcase_9, _fcase_8, _fcase_7, _fcase_6, _fcase_5, _fcase_4, _fcase_3, _fcase_2, _fcase_1, _fcase_0)(values) /** Trick: `_dummy_` arg is necessary because ## only deletes commas (,) to its left (I think). */

/// bcase – (b)reaking variant

#define bcase(values...) \
    break; fcase(values)

/// `threadobject()` and `staticobject()`  macros – creates an objc object whose state is retained between invocations.
///     Scope:
///     > `threadobject()` retains the state between all invocations on the same thread. (like a `static __thread` variable)
///     > `staticobject()` retains the state between all invocations in the same process. (like a `static` variable)
///
///     Example usage:
///     `staticobject()`:
///         ```
///         NSCache *cache = staticobject([[NSCache alloc] init]);
///         id fromCache = [cache valueForKey: @"SomeKey"];
///         if (fromCache) return fromCache;
///         <...>
///         [cache setValue: expensiveValue forKey: @"SomeKey"]; /// (Caution: Generally, modifying the result of staticobject() isn't thread-safe. This particular example is thread-safe because NSCache uses locks internally.)
///         ```
///     `threadobject()`:
///         ```
///         NSMutableArray *arr = threadobject([NSMutableArray alloc] init]);
///         [arr addObject: @"a"];
///         NSLog("%@", arr);       // Will print more and more "a" strings as this code is invoked multiple times on the same thread.
///         ```
///
///     Meta: why is the threadobject implementation so complicated?
///         Objc objects aren't compatible with `static __thread` variables under ARC. That's why our implementation uses `[[NSThread currentThread] threadDictionary]` under the hood.
///
///     Meta: Only use mutable objects.
///         Overriding the returned pointer will not update the static/thread-local state. Instead you have to create mutable objects in static/thread-local storage, and then modify them.
///
///     Meta: what about storing non-objects?
///        To create non-objects variables that are static or thread-local, you can just use the `static`/`static __thread` keywords directly.
///        How to initialize non-objects?
///         - If your initial value is a compile-time-constant:          you can even initialize them very simply, like this `static int count = 99;`.
///         - If your initial value is not compile-time-constant:       you can use `dispatch_once()` (for static vars) or a `static __thread bool is_initialized` flag (for thread local vars.).
///
///     Off-topic:
///         - [ ] Go through MMF project and replace `static NSMutable...` with  staticobject / threadobject / NSCache. (NSMutableDictionary and NSMutableArray are not thread safe!) (Once we move everything to a single 'IOThread' some of this might be unnecessary.)

#define staticobject(initializer_expr)              \
    (typeof(initializer_expr))                      \
    ({                                              \
        static_assert(_isobject(initializer_expr), "Use `static` for static variables that are not Objective-C objects."); \
        static typeof(initializer_expr) __result;   \
        static dispatch_once_t __oncetoken;         \
        dispatch_once(&__oncetoken, ^{              \
            __result = (initializer_expr);          \
        });                                         \
        __result;                                   \
    })

#define threadobject(initializer_expr)                                  \
    (typeof(initializer_expr))                                          \
    ({                                                                  \
        static_assert(_isobject(initializer_expr), "Use `static __thread` for thread-local variables that are not Objective-C objects."); \
        static NSString *__key;                                         \
        static dispatch_once_t __oncetoken;                             \
        dispatch_once(&__oncetoken, ^{                                  \
            __key = stringf(@"mf.threadobject.%p", &__key);             \
        });                                                             \
        NSMutableDictionary *__thread_dict =                            \
            [[NSThread currentThread] threadDictionary];                \
        typeof(initializer_expr) __result = __thread_dict[__key];       \
        if (!__result) {                                                \
            __result = (initializer_expr);                              \
            __thread_dict[__key] = __result;                            \
        }                                                               \
        __result;                                                       \
    })

/// Debugging helper - get binary representation
///     Discussion:
///     - This is a macro to make this function generic -> The output string's width will automatically match the byte count of the input type (by using sizeof())
///     Alternatives:
///         - Consider using `bitflagstring()` to debug-print enums.
///         - Previously we used a `binaryRepresentation` method which did the same thing

#define binarystring(__v) \
    (NSString *) \
    ({ \
        typeof(__v) m_value = __v; /** We call it `m_value` so there's no conflict in case `__v` is `value`. `m_` stands for `macro`. */ \
        int nibble_size = 8; \
        int nibble_count = sizeof(m_value)*8 / nibble_size; \
        int bit_str_len = (nibble_count * (nibble_size+1)) - 1; \
        char bit_str[bit_str_len + 1]; \
        bit_str[bit_str_len] = '\0'; /** Null terminator */ \
        for (int i = bit_str_len-1; i >= 0; i--) { \
            if (i % (nibble_size+1) == nibble_size) { /** Add a space every `nibble_size` bits for better legibility */ \
                bit_str[i] = ' '; \
            } else { \
                bit_str[i] = (m_value & 1) ? '1' : '0'; \
                m_value = m_value >> 1; \
            } \
        } \
        [NSString stringWithUTF8String: bit_str]; \
    })

/// mfcycle
///     - Generalization of modulo.
///     - Is a macro to work with multiple types.
///         ... should probably just make this a function that works on double.
///     - Moves n into the half-open interval `[lower, upper)` (if includeUpper == false) or `(lower, upper]` (if includeUpper == true)
///     - If lower > upper, the result will be mirrored (see code)  – feels like a natural extension of this operation?
///     -`mfcycle(n, 0, z, false)` is equivalent to `n % z`
///         ... Actually not quite true bc `%` is weird for negative inputs in C. Something about euclidian modulo iirc.
/// Also see:
///     [May 22 2025] mfround, mffloor, mfceil function in our IDAPython scripts – They use a similar idea of 'extending' round/floor/ceil
///     Math.swift > cycle()
#define mfcycle(n, lower, upper, includeUpper)                                              \
(typeof((n)+(lower)+(upper)))                                                               \
({                                                                                          \
    typeof((n)+(lower)+(upper)) __n = (n);                                                  /** typeof((n)+(lower)+(upper))` should 'promote' the internal calculations to a type that can support them. E.g. if `n` is double but `lower` is int, the internal calculations (and return type) will be double */\
    typeof(__n) __lower             = (lower);                                              /** We create local variables to prevent multiple-evaluation in case the macro args are complex expressions. || We prefix local vars with `__` to prevent conflicts in case a macro param is a variable of the same name. */ \
    typeof(__n) __upper             = (upper);                                              \
    bool __inclup                   = (includeUpper) != 0;                                  \
    if (__upper == __lower) { __n = __lower; }                                              \
    else {                                                                                  \
        if (__lower > __upper) {                                                            /** Mirror – If we didn't, there'd be an infinite loop. */ \
            swapvars(__lower, __upper);                                                     /** Mirror lower and upper along the center of the interval */ \
            __inclup = !__inclup;                                                           \
            __n = __upper + __lower - __n;                                                  /** Mirror n along the center of the interval. */ \
        }                                                                                   \
        typeof(__n) __stride = __upper - __lower;                                           \
        while (1) {                                                                         \
            bool __tooSmall;                                                                \
            bool __tooLarge;                                                                \
            if (!__inclup) {                    /** Include lower bound */                          \
                __tooSmall = (__n     <  __lower);                                          \
                __tooLarge = (__upper <= __n);                                              \
            } else {                            /** Include upper bound */                          \
                __tooSmall = (__n     <= __lower);                                          \
                __tooLarge = (__upper <   __n);                                             \
            }                                                                               \
            if      (__tooSmall)    __n += __stride;                                        \
            else if (__tooLarge)    __n -= __stride;                                        \
            else                    break;                                                  \
        }                                                                                   \
    }                                                                                       \
    __n;                                                                                    \
})

/// ifcast & ifcastn
///
/// What:   Check if objc object O is of class C. If so, cast O to C and make O available in a dedicated scope.
/// Why:    Makes working with objc objects of unknown type more concise.
/// Note:   Similar to Swift if-let-as statement.
///
/// Caution: Uses for-loops to insert vars into scope, so will behave unexpectedly with `break` and `continue` statements.
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
///         obj = nil;                              // obj can be overriden when using ifcastn (it would be shadowed when using ifcast())
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
        for (int _once = 1; _once;) \
        for (id __ifcast_temp = varname; _once;)                                                               /** The temp var allows us to shadow `varname` if `newvarname` == `varname` */ \
        for (classname *_Nonnull const __attribute__((unused)) newvarname = __ifcast_temp; _once; _once = 0)   /** 1. Notice `_Nonnull`. We're not only guaranteed the class but also the non-null-ity of newvarname || 2. Notice __attribute__((unused)) – it turns off warnings when the macro user doesn't use newvarname. 3. Notice `const` it warns the user when they try to override the inner variable. (Since they're probably trying to override the outer one.) */ \

#define ifcast(varname, classname)  \
    ifcastn(varname, classname, varname)
