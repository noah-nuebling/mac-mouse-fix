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

#pragma mark - Helper macros

/// Helper macros
///     To implement other macros

#define UNPACK(args...) args                /// This allows us to include `,` inside an argument to a macro (but the argument then needs to be wrapped inside `()` by the caller of the macro )
#define APPEND_ARGS(args...) , ## args      /// This is like UNPACK but it also automatically inserts a comma before the args. The ## deletes the comma, if `args` is empty. I have no idea why. But this lets us nicely append args to an existing list of arguments in a function call or function header.

#define TOSTR(x)    #x                      /// `#` operator but delayed – Sometimes necessary when order-of-operations matters
#define TOSTR_(x)   TOSTR(x)                /// `#` operator but delayed even more

#define _IFELSE_TRUE(iftrue, iffalse)                  UNPACK iftrue
#define _IFELSE_TRUE_JUST_KIDDING(iftrue, iffalse)     UNPACK iffalse

#define _IFEMPTY(iftrue, iffalse, ...)                 _IFELSE_TRUE ## __VA_OPT__(_JUST_KIDDING) (iftrue, iffalse)
#define IFEMPTY(condition, body...)                    _IFEMPTY((body), (),     condition)
#define IFEMPTY_NOT(condition, body...)                _IFEMPTY((),     (body), condition)

#define FOR_EACH(function, separator, functionargs...) \
    _FOR_EACH_SELECTOR(functionargs, _FOR_EACH_20, _FOR_EACH_19, _FOR_EACH_18, _FOR_EACH_17, _FOR_EACH_16, _FOR_EACH_15, _FOR_EACH_14, _FOR_EACH_13, _FOR_EACH_12, _FOR_EACH_11, _FOR_EACH_10, _FOR_EACH_9, _FOR_EACH_8, _FOR_EACH_7, _FOR_EACH_6, _FOR_EACH_5, _FOR_EACH_4, _FOR_EACH_3, _FOR_EACH_2, _FOR_EACH_1)(function, separator, functionargs)
    
#define _FOR_EACH_SELECTOR(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16, arg17, arg18, arg19, arg20, macroname, ...) macroname

#define _FOR_EACH_1(function, separator, functionarg)           function(functionarg)
#define _FOR_EACH_2(function, separator, functionarg, rest...)  function(functionarg) UNPACK separator _FOR_EACH_1(function, separator, rest)
#define _FOR_EACH_3(function, separator, functionarg, rest...)  function(functionarg) UNPACK separator _FOR_EACH_2(function, separator, rest)
#define _FOR_EACH_4(function, separator, functionarg, rest...)  function(functionarg) UNPACK separator _FOR_EACH_3(function, separator, rest)
#define _FOR_EACH_5(function, separator, functionarg, rest...)  function(functionarg) UNPACK separator _FOR_EACH_4(function, separator, rest)
#define _FOR_EACH_6(function, separator, functionarg, rest...)  function(functionarg) UNPACK separator _FOR_EACH_5(function, separator, rest)
#define _FOR_EACH_7(function, separator, functionarg, rest...)  function(functionarg) UNPACK separator _FOR_EACH_6(function, separator, rest)
#define _FOR_EACH_8(function, separator, functionarg, rest...)  function(functionarg) UNPACK separator _FOR_EACH_7(function, separator, rest)
#define _FOR_EACH_9(function, separator, functionarg, rest...)  function(functionarg) UNPACK separator _FOR_EACH_8(function, separator, rest)
#define _FOR_EACH_10(function, separator, functionarg, rest...) function(functionarg) UNPACK separator _FOR_EACH_9(function, separator, rest)
#define _FOR_EACH_11(function, separator, functionarg, rest...) function(functionarg) UNPACK separator _FOR_EACH_10(function, separator, rest)
#define _FOR_EACH_12(function, separator, functionarg, rest...) function(functionarg) UNPACK separator _FOR_EACH_11(function, separator, rest)
#define _FOR_EACH_13(function, separator, functionarg, rest...) function(functionarg) UNPACK separator _FOR_EACH_12(function, separator, rest)
#define _FOR_EACH_14(function, separator, functionarg, rest...) function(functionarg) UNPACK separator _FOR_EACH_13(function, separator, rest)
#define _FOR_EACH_15(function, separator, functionarg, rest...) function(functionarg) UNPACK separator _FOR_EACH_14(function, separator, rest)
#define _FOR_EACH_16(function, separator, functionarg, rest...) function(functionarg) UNPACK separator _FOR_EACH_15(function, separator, rest)
#define _FOR_EACH_17(function, separator, functionarg, rest...) function(functionarg) UNPACK separator _FOR_EACH_16(function, separator, rest)
#define _FOR_EACH_18(function, separator, functionarg, rest...) function(functionarg) UNPACK separator _FOR_EACH_17(function, separator, rest)
#define _FOR_EACH_19(function, separator, functionarg, rest...) function(functionarg) UNPACK separator _FOR_EACH_18(function, separator, rest)
#define _FOR_EACH_20(function, separator, functionarg, rest...) function(functionarg) UNPACK separator _FOR_EACH_19(function, separator, rest)

/// `_isobject()` – internal helper macro.
///     Check if an expression evaluates to an objc object.
#define _isobject(expression) __builtin_types_compatible_p(typeof(expression), id)

/// Branch-prediction hints
///     Explanation and example: https://stackoverflow.com/a/133555/10601702
#define mflikely(b)    (long)__builtin_expect(!!(b), 1)
#define mfunlikely(b)  (long)__builtin_expect(!!(b), 0)

#pragma mark - Enduser macros

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

/// `mfabort` macro
///     Like abort() but with the goal of writing a specific message into the crash report
///     (Writing the message into the crash-report doesn't work yet as of [Aug 2025])
///     Note on old investigation: [Aug 2025]
///         IIRC we did a longer investigation into writing custom messages into crash reports. I don't remember where. Maybe some side-repo? I remember finding some global c variable but it was ignored unless it was written to from the crash reporter module or something. I also remember discovering some elaborate private API (CFType-based I think), but not pursuing it further.
///     TODO: Move this into Logging.h when merging this code from master into feature-strings-catalog

#define mfabort(format, args...) ({ \
    DDLogError(@"mfabort failure: " format, ## args); \
    [DDLog flushLog];               /** [Aug 2025] Without this, nothing would be logged, due to async logging of CocoaLumberjack and and the abort right after. But this should make it work (I think – haven't tested any of this.) Claude 4.0 also tells me to sleep for 10ms after flushing, but I don't trust it.*/\
    abort();                        \
})

/// `vardesc` and `vardescl` macros
///  Naming:
///      vardesc -> (var)iable (desc)ription
///      vardescl -> (var)iable (desc)ription with (l)inebreaks
///  For a given set of expressions, captures their source text and corresponding value and inserts them into the output string in a key-value style.
///  This is similar to NSDictionaryOfVariableBindings() – But this is better-suited for debug-printing because: Dictionaries don't preserve order. Dictionaries can't contain nil. Using NSDictionaryOfVariableBindings requires importing NSLayoutConstraint.h
///  Handling of primitives: This uses `mfbox` with `FOR_EACH` to be able to accept primitive values as well as objects. Otherwise caller could still easily @(box) primitives. (And we could remove the `@()` before printing if it bothers us) Not sure this is worth the complexity. I'm kinda just doing this for fun (LIke most of the macro stuff). [Oct 2025]
///  Performance: It's fine. See `vardesc_benchmarks.m`
///  Example usage:
///      `NSLog(@"Local variables %@", vardesc(some_int, some_object)); // Prints: "Local variables: { some_int = 79 | some_object = Turns out I'm a string! }"`
#define vardesc(vars...)  _vardesc(false, @#vars, vars)         /** Need to stringify `vars` here not inside `_vardesc`, otherwise sourcetext of passed-in macros will be expanded. Not sure why [Jul 2025] */
#define vardescl(vars...) _vardesc(true,  @#vars, vars)

#define _vardesc(linebreaks, keys, vars...) ({                  \
    id _values[] = { FOR_EACH(mfbox, (,), vars) };                                    /** Using a C array instead of NSArray to be able to capture nil. NSDictionaryOfVariableBindings uses a variadic function. */\
    __vardesc(keys, _values, arrcount(_values), (linebreaks));  \
})
NSString *_Nullable __vardesc(NSString *_Nonnull keys_commaSeparated, id _Nullable __strong *_Nonnull values, size_t count, bool linebreaks);

/// `mfbox` macro
/// Alternative to objc @(boxed) expressions.
///     Advantage: You can pass in a pointer to anything – including an object – and it 'normalizes' everything to an object – this is useful for our `vardesc` macro.
///     Disadvantage: @(boxed) expressions are more convenient.
///     Note: I think I implemented this before in some side-repo [Oct 2025]

#define mfbox(thing) ({                                     \
    nowarn_push(-Wauto-var-id)                              \
    __auto_type thing_ = (thing);                           \
    nowarn_pop()                                            \
    _mfbox((void *)&thing_, @encode(typeof(thing_)));       \
})
id __nullable _mfbox(const void *__nonnull thing, const char *__nonnull objc_type); /// Not sure this can actually return nil [Oct 2025]

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
    IFEMPTY_NOT (w, _Pragma(TOSTR(clang diagnostic ignored #w)))            \

#define nowarn_pop()                                                        \
    _Pragma("clang diagnostic pop")

/// array count convenience
#define arrcount(x) ({ static_assert(!_isobject(x), "Use a method like -[count] for objects."); (sizeof(x) / sizeof((x)[0])); })

/// bcase – (b)reaking variant

#define bcase(values...) \
    break; fcase(values)

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

/// Helper macros:`_scopeins_var` / `_scopeins_statement_start` / `_scopeins_statement_end`
/// What:   Insert a variable declaration or statement into the scope following the macro
/// Why:    Useful for implementing other macros – The macro can be used as a 'header' for a scope and insert useful variables or statements into it.
///         -> The real benefit of this is that the scope, which effectively acts like an argument to the macro, is *outside* the macro. And scopes outside a macro have much better debugging support. (Setting breakpoints inside a macro argument doesn't work in Xcode [Feb 2025])
/// How:    The macros use for-loop(s). Little hacky. Alternatives: In CPP there's `If Statement with Initializer`, but afaik, in C, this is the only way to insert a declaration into a scope from outside the scope.
///
/// Caution: Using`break` or `continue` inside a `_scopeins_...()` macro's scope will simply break out of that scope. It won't interact with any enclosing loops (since the `_scopeins_...()` macros use for-loops under-the-hood)
///         > `break` and `continue` also won't work for **any macros that use _scopeins_...() macros** – Don't forget this!
///
/// Examples:
///
///     1. Insert var – into a scope without braces.
///         `_scopeins_var(int x = 5) printf("%d", x);  // Despite the lack of braces, this is a scope. x only exists for this printf`
///
///     2. Insert var – into a scope with { braces }
///         ```
///         _scopeins_var(NSMutableString *str = [NSMutableString string]) // str only exists inside { ... }
///         {
///             [str appendString:@"Hello"];
///             [str appendString:@" World"];
///             NSLog(@"%@", str);
///         }
///     3. Insert statements - at the start and end of a scope
///         ```
///         _scopeins_statement_start(pthread_mutex_lock(&mutex))
///             _scopeins_statement_end(pthread_mutex_unlock(&mutex))
///                 {
///                     // (mutex is locked here)
///                     shared_state++;
///                     // (mutex is unlocked here)
///                 }
///         ```
///     4. Insert multiple statements using ({ statement-expressions })
///         ```
///             _scopeins_var(FILE* f = fopen("test.txt", "r"))
///                 _scopeins_statement_start(printf("file %p was opened\n", f))
///                     _scopeins_statement_end( ({ fclose(f); printf("file %p was closed\n", f); }) ) // Insert an fclose and a printf statement at the end of the scope.
///                         {
///                             // File operations here
///                             char buf[100];
///                             fgets(buf, sizeof(buf), f);
///                             ...
///                         }
///         ```

/// Variable inserter
    
#define _scopeins_var(declaration...)                                                                   /** vararg... so the declaration may contain commas without being interpreted as multiple macro args */\
    for (int __scopeins_oncetoken = 0;     __scopeins_oncetoken == 0;)                                \
    for (declaration;                      __scopeins_oncetoken == 0; __scopeins_oncetoken = 1)      \

/// Statement inserters

#define _scopeins_statement_start(statement...)                         \
    for (                                                               \
        int __scopeins_oncetoken = 0;                                   \
        __scopeins_oncetoken == 0 ? ({ statement; true; }) : false;     \
        __scopeins_oncetoken = 1                                        \
    )

#define _scopeins_statement_end(statement...)                           \
    for (                                                               \
        int __scopeins_oncetoken = 0;                                   \
        __scopeins_oncetoken == 0;                                      \
        ({ statement; __scopeins_oncetoken = 1; })                      \
    )

/// Other
#define scoped_preprocess(statements...) /** Untested. Not well thought-through. Don't use this. Could perhaps be useful for validation or compile-time-checks of a _scopeins_var(). Since this is an if statement, the macro args could also easily prevent the scope from being executed entirely. */\
    if (({ statements }))

/// ifcast & ifcastn
///
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
        _scopeins_var(id __ifcast_temp = varname)                                                           /** The temp var allows us to shadow `varname` if `newvarname` == `varname` */ \
            _scopeins_var(classname *_Nonnull const __attribute__((unused)) newvarname = __ifcast_temp)     /** 1. Notice `_Nonnull`. We're not only guaranteed the class but also the non-null-ity of newvarname || 2. Notice __attribute__((unused)) – it turns off warnings when the macro user doesn't use newvarname. 3. Notice `const` it warns the user when they try to override the inner variable. (Since they're probably trying to override the outer one.) */ \

#define ifcast(varname, classname)  \
    ifcastn(varname, classname, varname)

/// ifcastp & ifcastpn
///     Works just like ifcast & ifcastn but for objc protocols instead of classes.

#define ifcastpn(varname, protocolname, newvarname)                                                             \
    if (varname && [varname conformsToProtocol: @protocol(protocolname)])                                        \
        _scopeins_var(id __ifcast_temp = varname)                                                                   \
            _scopeins_var(id<protocolname> _Nonnull const __attribute__((unused)) newvarname = __ifcast_temp)

#define ifcastp(varname, protocolname)  \
    ifcastpn(varname, protocolname, varname)

