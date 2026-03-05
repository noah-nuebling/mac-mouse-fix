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

/// `arr()` et al.
///     Python-style 'comprehension' sugar --- turns simple array transformations into a single expression. --- more flexible/intuitive version of map/filter.

#define arr(expr, header) ({ /** Python-style 'list-comprehension' sugar. */\
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
#define countof(x) ({ static_assert(!_isobject(x), "Use a method like -[count] for objects."); (sizeof(x) / sizeof((x)[0])); })

/// `isclass` macro
///     Shorthand for `-[isKindOfClass:]` and `-[isSubclassOfClass:]`
#define isclass(x, classname) [[(x) class] isSubclassOfClass: [classname class]]

/// `isclassd` macro
///     `isclass`, but (d)ynamic. Meaning the compiler/linker doesn't have to know about the class we're comparing against.
#define isclassd(x, classname) [[(x) class] isSubclassOfClass: NSClassFromString(classname)]

/// trycast
/// Similar to Swift if-let-as statement
/// Example:
///     ```
///     id obj = @"hello";
///     if trycast(obj, NSString, str)            // Try to cast obj to NSString. If success, store obj in typed var str, and then run the if-body
///         NSLog(@"Length: %lu", str.length);    // str is of type NSString, so NSString's properties can be accessed directly
///     ```
/// Caution: Uses for-loops to insert vars into scope, so will behave unexpectedly with `break` and `continue` statements.
/// Worth it? ... Not sure. Not much less boilerplate than using the super simple and flexible `isclass()/isclassd()` macros. Also, dynamic typing as id is fine in objc. [Mar 2026]

#define trycast(varname, classname, newvarname)                                                         \
    (varname && [varname isKindOfClass: [classname class]])                                          \
        for (int _once = 1; _once;) \
        for (id __trycast_temp = varname; _once;)                                                               /** The temp var allows us to shadow `varname` if `newvarname` == `varname` */ \
        for (classname *_Nonnull const __attribute__((unused)) newvarname = __trycast_temp; _once; _once = 0)   /** 1. Notice `_Nonnull`. We're not only guaranteed the class but also the non-null-ity of newvarname || 2. Notice __attribute__((unused)) – it turns off warnings when the macro user doesn't use newvarname. 3. Notice `const` it warns the user when they try to override the inner variable. (Since they're probably trying to override the outer one.) */ \

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
    [NSAttributedString attributedStringWithAttributedFormat: _format args: _args argcount: countof(_args)];                        \
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
///         const char *fruit = safeindex(fruits, countof(fruits), 3, "<no fruit at index 3>");`
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
