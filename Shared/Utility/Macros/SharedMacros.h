//
//  SharedMacros.h
//  EventLoggerForBrad
//
//  Created by Noah Nübling on 10.02.25.
//

/// Macro naming pattern
///     Short & all-lowercase   -> easy to type
///     Unique                          -> easy to grep
///
///     If the name isn't unique, prefix `mf` to make it unambiguous.
///     Sweetspot seems to be combining two words.
///
/// -------------------------------------

#import <Foundation/Foundation.h>

#pragma mark - Macros from mac-mouse-fix > SharedUtility.h

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

#define FOR_EACH(macro, macroargs...) \
    _FOR_EACH_SELECTOR(macroargs, _FOR_EACH_20, _FOR_EACH_19, _FOR_EACH_18, _FOR_EACH_17, _FOR_EACH_16, _FOR_EACH_15, _FOR_EACH_14, _FOR_EACH_13, _FOR_EACH_12, _FOR_EACH_11, _FOR_EACH_10, _FOR_EACH_9, _FOR_EACH_8, _FOR_EACH_7, _FOR_EACH_6, _FOR_EACH_5, _FOR_EACH_4, _FOR_EACH_3, _FOR_EACH_2, _FOR_EACH_1)(macro, macroargs)
    
#define _FOR_EACH_SELECTOR(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16, arg17, arg18, arg19, arg20, macroname, ...) macroname

#define _FOR_EACH_1(macro, macroarg)          macro(macroarg)
#define _FOR_EACH_2(macro, macroarg, rest...) macro(macroarg) _FOR_EACH_1(macro, rest)
#define _FOR_EACH_3(macro, macroarg, rest...) macro(macroarg) _FOR_EACH_2(macro, rest)
#define _FOR_EACH_4(macro, macroarg, rest...) macro(macroarg) _FOR_EACH_3(macro, rest)
#define _FOR_EACH_5(macro, macroarg, rest...) macro(macroarg) _FOR_EACH_4(macro, rest)
#define _FOR_EACH_6(macro, macroarg, rest...) macro(macroarg) _FOR_EACH_5(macro, rest)
#define _FOR_EACH_7(macro, macroarg, rest...) macro(macroarg) _FOR_EACH_6(macro, rest)
#define _FOR_EACH_8(macro, macroarg, rest...) macro(macroarg) _FOR_EACH_7(macro, rest)
#define _FOR_EACH_9(macro, macroarg, rest...) macro(macroarg) _FOR_EACH_8(macro, rest)
#define _FOR_EACH_10(macro, macroarg, rest...) macro(macroarg) _FOR_EACH_9(macro, rest)
#define _FOR_EACH_11(macro, macroarg, rest...) macro(macroarg) _FOR_EACH_10(macro, rest)
#define _FOR_EACH_12(macro, macroarg, rest...) macro(macroarg) _FOR_EACH_11(macro, rest)
#define _FOR_EACH_13(macro, macroarg, rest...) macro(macroarg) _FOR_EACH_12(macro, rest)
#define _FOR_EACH_14(macro, macroarg, rest...) macro(macroarg) _FOR_EACH_13(macro, rest)
#define _FOR_EACH_15(macro, macroarg, rest...) macro(macroarg) _FOR_EACH_14(macro, rest)
#define _FOR_EACH_16(macro, macroarg, rest...) macro(macroarg) _FOR_EACH_15(macro, rest)
#define _FOR_EACH_17(macro, macroarg, rest...) macro(macroarg) _FOR_EACH_16(macro, rest)
#define _FOR_EACH_18(macro, macroarg, rest...) macro(macroarg) _FOR_EACH_17(macro, rest)
#define _FOR_EACH_19(macro, macroarg, rest...) macro(macroarg) _FOR_EACH_18(macro, rest)
#define _FOR_EACH_20(macro, macroarg, rest...) macro(macroarg) _FOR_EACH_19(macro, rest)

/// weakify/strongify macros
///     These are used to prevent retain cycles when using objc blocks.
///     Commentary: [Sep 2025]
///         - Traditionally defined in libextobjc/EXTScope.h as @weakify and @strongify.
///         - I thought we had that in the MMF project? But I can't find it. Might as well do our own simplified implementation.
///         - ... I didn't actually end up using this [Sep 2025]

#define weakify(varnames...)   FOR_EACH(_weakify, varnames)
#define strongify(varnames...) FOR_EACH(_strongify, varnames)

#define _weakify(varname) \
    __weak __auto_type _weakified_##varname = varname;

#define _strongify(varname) \
    __strong __auto_type varname = _weakified_##varname;

/// `vardesc` and `vardescl` macros
///  Naming:
///      vardesc -> (var)iable (desc)ription
///      vardescl -> (var)iable (desc)ription with (l)inebreaks
///  For a given set of expressions, captures their source text and corresponding value and inserts them into the output string in a key-value style. All values have to be objects.
///  This is similar to NSDictionaryOfVariableBindings() – But this is better-suited for debug-printing because: Dictionaries don't preserve order. Dictionaries can't contain nil. Using NSDictionaryOfVariableBindings requires importing NSLayoutConstraint.h
///  Example usage:
///      ```
///      NSLog(@"Local variables %@", vardesc(@(some_int), some_object)); // Prints: `Local variables: { @(some_int) = 79 | some_object = Turns out I'm a string! }`
///      ```
#define vardesc(vars...)  _vardesc(false, @#vars, vars)         /** Need to stringify `vars` here not inside `_vardesc`, otherwise sourcetext of passed-in macros will be expanded. Not sure why [Jul 2025] */
#define vardescl(vars...) _vardesc(true,  @#vars, vars)

#define _vardesc(linebreaks, keys, vars...) ({                  \
    id _values[] = { vars };                                    /** Using a C array instead of NSArray to be able to capture nil. NSDictionaryOfVariableBindings uses a variadic function. */\
    __vardesc(keys, _values, arrcount(_values), (linebreaks));  \
})
NSString *_Nullable __vardesc(NSString *_Nonnull keys_commaSeparated, id _Nullable __strong *_Nonnull values, size_t count, bool linebreaks);

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

/// `_isobject()` – internal helper macro.
///     Check if an expression evaluates to an objc object.
#define _isobject(expression) __builtin_types_compatible_p(typeof(expression), id)

/// `makerange_fromto` macro
///     Alternative to NSMakeRange(), lets you specify the range in terms of (firstindex, lastindex) instead of (firstindex, count) – which I find more intuitive.
#define makerange_fromto(firstindex, lastindex) ({                     \
    __auto_type __firstindex = (firstindex);                    \
    NSMakeRange(__firstindex, (lastindex) - __firstindex + 1);  \
})

/// array count convenience
#define arrcount(x) (sizeof(x) / sizeof((x)[0]))

/// `MFNSSetMake()`
///     Substitute for missing NSSet literal
///     You could also do `[NSSet setWithArray:@[objects...]]`, but I assume that's less efficient.

#define MFNSSetMake(objects...) ({                                          \
    id __objects[] = { objects };                                           \
    [[NSSet alloc] initWithObjects: __objects count: arrcount(__objects)];    \
})

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
#define _fcase_7(x, rest...)    case x: _fcase_6(rest) /** 7 should be more than enough */

#define _fcase_selector(_dummy_, arg1, arg2, arg3, arg4, arg5, arg6, arg7, macroname, ...) macroname

#define fcase(values...) \
    _fcase_selector(_dummy_, ## values, _fcase_7, _fcase_6, _fcase_5, _fcase_4, _fcase_3, _fcase_2, _fcase_1, _fcase_0)(values) /** Trick: `_dummy_` arg is necessary because ## only deletes commas (,) to its left (I think). */

/// bcase – (b)reaking variant

#define bcase(values...) \
    break; fcase(values)

/// `isclass` macro
/// Behavior:
///     isclass(x, classname) works on both normal objects and class objects.
///         If `x` is a normal object:                  Checks whether *the class of x*  is equivalent to, or a subclass of, the class called `classname`
///         If `x` is a class-object:                    Checks whether *x itself*             is equivalent to, or a subclass of, the class called `classname`
///         -> Therefore, this replaces both [isKindOfClass:] and [isSubclassOfClass:]
/// Why does this work?
///     On a normal object:    `class` returns the class-object, and `object_getClass()` also returns the class-object.
///     On a class-object:       `class` returns the class-object, but `object_getClass()` returns the *meta-class-object*.
/// Performance:
///     Not how much slower this is compared to [isKindOfClass:] or [isSubclassOfClass:]. Prolly not significant.
/// Alternative implementation:
///     `[[(x) class] isSubclassOfClass: [classname class]]`
///         -> Isn't that a simpler way to achieve the same thing?
///         Meta: I think I used `object_getClass()` because I read somewhere that it is safer than some alternative.
///             I though the alternative might be `-isSubclassOfClass:` but I think the alternative was actually `objc_getMetaClass()` and I read about this here: https://stackoverflow.com/a/20833446/10601702
///

#import <objc/runtime.h> /// Necessary for `object_getClass`

#define isclass(x, classname) \
    [[(x) class] isKindOfClass: object_getClass([classname class])]

/// `isclassd` macro
///     `isclass`, but (d)ynamic. Meaning the compiler doesn't have to know about the class we're comparing against.

#define isclassd(x, classname) \
    [[(x) class] isKindOfClass: object_getClass(NSClassFromString(@#classname))]

/// `isprotocol` macro
///     - Works on normal objects and class objects just like `isclass()`
///     - The docs say this is slow, and to use -[respondsToSelector:] instead See: https://developer.apple.com/documentation/objectivec/nsobject/1418893-conformstoprotocol?language=objc

#define isprotocol(x, protocolname) \
    [[x class] conformsToProtocol: @protocol(protocolname)]

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

/// `isavailable()` macro
///     Return true iff `lo <= currentMacOSVersion < hi`.
///     Tip: To remove one of the bounds, use `1` or `INT_MAX`.
///     Usage example:
///         ```
///         if (isavailable(13.0, 15.0)) {
///             if (@available(macOS 13.0, *)) {        // A second @available() guard of exactly this form might be necessary to silence compiler warnings about API-availability
///                 NSLog(@"Running macOS 13 or 14!");
///             }
///         }
///         else {
///             NSLog(@"Not running macOS 13 or 14!");
///         }
///         ```
///     Meta:
///         - If you only need a lower bound, probably just use `if (@available(xxx, *)` directly.
///         - To silence compiler warnings for new APIs, you still need to use `if (@available(xxx, *)` in addition to this, which is awkward.
///         - This might not be worth adding to the codebase. (Just like a lot of these macros) We'll probably use it rarely. And NSProcessInfo should also work fine. But I like how the syntax for specifying versions here is closer to @available() than NSProcessInfo.
///         - Update: [Jul 2025] We should probably turn this into isunavailable() instead of this range-based check. Because, if we need a lower-bound, we're still going to have `if @available(xxx, *)` in addition to this.
#define isavailable(lo_inclusive, hi_exclusive) ({          \
    bool _isavailable = false;                              \
    if (@available(macOS lo_inclusive, *)) {                \
        if (@available(macOS hi_exclusive, *)) { } else {   \
            _isavailable = true;                            \
        }                                                   \
    }                                                       \
    _isavailable;                                           \
})

///
/// Define xxxNSLocalizedString macro,
///     which is replaced with nothing by the preprocessor.
///     The purpose of this is to 'turn off' NSLocalizedString() statements that we don't need at the moment.

#define xxxNSLocalizedString(...)

///
/// Check if ptr is objc object
///     Copied from https://opensource.apple.com/source/CF/CF-635/CFInternal.h
///     Also see:
///         - https://blog.timac.org/2016/1124-testing-if-an-arbitrary-pointer-is-a-valid-objective-c-object/
#define CF_IS_TAGGED_OBJ(PTR)    ((uintptr_t)(PTR) & 0x1)

///
/// MFStringEnum macros
///     These macros simplify creating an `NS_TYPED_ENUM` with underlying NSString values
///
/// Example usage:
///     ```
///     MFStringEnum(MFLinkID)
///     MFStringEnumCase(kMFLinkID, CapturedButtonsGuide)
///     MFStringEnumCase(kMFLinkID, CapturedScrollWheelsGuide)
///     MFStringEnumCase(kMFLinkID, VenturaEnablingGuide)
///     ```
///
/// ... which would expand to:
///     ```
///     typedef NSString * MFLinkID NS_TYPED_ENUM;
///     static MFLinkID const kMFLinkIDCapturedButtonsGuide       = @"CapturedButtonsGuide";
///     static MFLinkID const kMFLinkIDCapturedScrollWheelsGuide  = @"CapturedScrollWheelsGuide";
///     static MFLinkID const kMFLinkIDVenturaEnablingGuide       = @"VenturaEnablingGuide";
///     ```
///
/// Discussion:
/// - Using `static` in `MFStringEnumCase()` to prevent linker errors. This makes it so every source file has its own copy of these constants afaik, which is inefficient. More efficient way afaik would be to use `extern` for the declaration
///     and then define the underlying NSString values inside the .m file. However, using static is easier since it lets us declare everything in one place and I'm sure the performance difference is negligible.
///
/// Probably don't use this:
///     Using `NS_TYPED_ENUM` makes swift rename the cases. E.g. `kMFLinkIDCapturedButtonsGuide` -> `MFLinkID.capturedButtonsGuide`. However this breaks for some of our cases (MMFLActivate), and makes it harder to search the project for usages of the cases.
///     The main benefit of this is that Swift lets you omit the enum name (so you just have to type `.capturedButtonsGuide` instead of `MFLinkID.capturedButtonsGuide`), but omitting stuff like that makes compile time slower afaik, which I really want to prevent - so I wouldn't do that anyways. (Swift compile times are painfully slow) (Update: [Apr 2025] I still don't like swift, and don't plan to use this but the reasoning here doesn't really make sense. I think compile times were so slow mainly due to app-signing or something and are ok now.)
///     So in conclusion - we don't want the renaming.
///
///     I think the renaming shenanigans is the whole reason why `NS_TYPED_ENUM` even exists? (Don't know of anything else that it does.) And the `MFStringEnum` macros exist to make `NS_TYPED_ENUM` easier to use for me.
///     So perhaps it's better to not use the `MFStringEnum` macros at all and instead just declare the enum with a simple `typedef` and the cases with simple `#define`s.
///     That would look like this:
///     ```
///     typedef NSString * MFLinkID;
///     #define kMFLinkID_CapturedButtonsGuide      @"CapturedButtonsGuide"
///     #define kMFLinkID_CapturedScrollWheelsGuide @"CapturedScrollWheelsGuide"
///     #define kMFLinkID_VenturaEnablingGuide      @"VenturaEnablingGuide"
///     ```
///
/// Update: [Apr 2025]
///     Unused as of now.
///     Also see `CodeStyle.md`

#define MFStringEnum(__enumName) \
    typedef NSString * __enumName NS_TYPED_ENUM; \

#define MFStringEnumCase(__enumName, __caseName) \
    static __enumName const k ## __enumName ## __caseName = @(#__caseName);

/// -------------------------------------
///     Macros that are tooo crazy
/// -------------------------------------

#if 0

    /// `_O_` and `_I_` macros:
    ///     Shorthand for `_Nullable` and `_Nonnull`.
    ///     Mnemonics:
    ///         o -> nothing (`_Nullable`)
    ///         i -> something (`_Nonnull`)
    ///     Surrounding underscores make the identifiers unique and easily greppable
    ///     [Apr 2025] Wrote these because we managed to enable compiler warnings for nullability (See `Xcode Nullability Settings.md`) but cluttering up business logic with `_Nullable` and `_Nonnull` is a bit annoying.
    ///     [Sep 2025] These just look too weird. Haven't gotten myself to get used to them. Removing this for now.
    #define _O_ _Nullable
    #define _I_ _Nonnull

    /// `allequal` macro
    /// Example usage:
    ///     `allequal(a, b, c)`
    ///     ... This expands to:
    ///         `({ __auto_type __y3 = (b); (a) == __y3 && ((__y3) == (c)); })`
    ///     ... which is equivalent to the following (minus deduplication of macro arg b):
    ///         `(a == b && b == c)`
    ///

    #define _allequal2(x, y)          ((x) == (y))
    #define _allequal3(x, y, rest)    ({ __auto_type __y3 = (y); (x) == __y3 && _allequal2(__y3, rest); })
    #define _allequal4(x, y, rest...) ({ __auto_type __y4 = (y); (x) == __y4 && _allequal3(__y4, rest); })
    #define _allequal5(x, y, rest...) ({ __auto_type __y5 = (y); (x) == __y5 && _allequal4(__y5, rest); })
    #define _allequal6(x, y, rest...) ({ __auto_type __y6 = (y); (x) == __y6 && _allequal5(__y6, rest); })
    #define _allequal7(x, y, rest...) ({ __auto_type __y7 = (y); (x) == __y7 && _allequal6(__y7, rest); }) /// 7 Should be more than enough

    #define _allequal_selector(a1, a2, a3, a4, a5, a6, a7, macroname, ...) macroname

    #define allequal(x, y, rest...) \
        _allequal_selector(x, y, ## rest, _allequal7, _allequal6, _allequal5, _allequal4, _allequal3, _allequal2) (x, y, ## rest)

    /// `chaincmp` macro
    /// Example usage:
    ///     `chaincmp(a, ==, b, <, c)`
    ///     ... This expands to:
    ///         `({ __auto_type __y3 = (b); ((a) == __y3) && ((__y3) < (c)); })`
    ///     ... which is equivalent to the following (minus deduplication of macro arg b):
    ///         `(a == b && b < c)`
    ///
    /// -> Not sure this is sensible to use. I'm crazy.

    #define _chaincmpf(args...) ({ static_assert(false, "chaincmp() requires an odd number of arguments (alternating values and operators)."); 0; })

    #define _chaincmp2(x, op, y) ((x) op (y))
    #define _chaincmp3(x, op, y, rest...)   ({ __auto_type __y3 = (y); ((x) op __y3) && _chaincmp2(__y3, rest); })
    #define _chaincmp4(x, op, y, rest...)   ({ __auto_type __y4 = (y); ((x) op __y4) && _chaincmp3(__y4, rest); })
    #define _chaincmp5(x, op, y, rest...)   ({ __auto_type __y5 = (y); ((x) op __y5) && _chaincmp4(__y5, rest); })
    #define _chaincmp6(x, op, y, rest...)   ({ __auto_type __y6 = (y); ((x) op __y6) && _chaincmp5(__y6, rest); })
    #define _chaincmp7(x, op, y, rest...)   ({ __auto_type __y7 = (y); ((x) op __y7) && _chaincmp6(__y7, rest); }) /// 7 Should be more than enough

    #define _chaincmp_selector(_1, o1, _2, o2, _3, o3, _4, o4, _5, o5, _6, o6, _7, macroname, ...) macroname

    #define chaincmp(x, op, y, rest...) _chaincmp_selector(x, op, y, ## rest, _chaincmp7, _chaincmpf, _chaincmp6, _chaincmpf,  _chaincmp5, _chaincmpf, _chaincmp4, _chaincmpf, _chaincmp3, _chaincmpf, _chaincmp2) (x, op, y, ## rest)
#endif


#pragma mark - Macros from EventLoggerForBrad > SharedMacros.h

/// Convenience macro to check whether one value is a bitwise-subset of another
#define bitsub(sub, super) (bool) ({    \
    __auto_type __sub = (sub);          \
    (__sub & (super)) == __sub;         \
})

/// Logical implication operator (Usually written as `a -> b`).
///     Meaning "if a is true, then b must be true as well."
///     Example: `assert(ifthen(it_rains, street_is_wet));`
#define ifthen(a, b) (!(a) || (b))

/// Helper macro: bitpos(): Get the position of the bit in a one-bit-mask
///     - (a one-bit-mask is an integer with a single bit set – it specifies what that bit means in a bitflags datatype)
///     - Example usage: This expression will always evaluate to true: `mask == (1 << bitpos(mask))` (Given that exactly 1 bit is set in `mask`)
///     - If `mask` is compile-time-constant, this whole macro is compile-time-constant! Therefore you can use it inside `static_assert()` and other places.
#define bitpos(mask) (                                                  \
    (mask) == 0               ? -1 :                                    /** Fail: less than one bit set */\
    ((mask) & (mask)-1) != 0  ? -1 :                                    /** Fail: more than one bit set (aka not a power of two) */\
    __builtin_ctz(mask)                                                 /** Sucess! – Count trailling zeros*/ \
)

/// Internal helper macro
///     Deferred concat
#define __deferred_concat(a, b) a##b
#define _deferred_concat(a, b) __deferred_concat(a, b)

/// Internal helper macro
///     > Makes an identifier unique between macro invocations
///     > That way, if the macro creates variables in the current scope, and is called several times in the same scope – the variables of the different macro invocations won't conflict.
///     ... We make the identifier unique by adding the current line number
///         (Note that macros are always expanded on one line, so for the same input, the resulting identifier will be unique *per macro* [Except if multiple macros are on the same line])
///
///     We also prepend `__` to the indentifier to mark it as 'internal' (to the macro) – that way, hopefully the user of the macro (who has a variable magically created in their scope) isn't confused.
///
///     Only use this if necessary! Creating a new scope inside the macro with `do { ... } while(0)` or `({ ... })` makes this unnecessary (but in rare cases that's impossible.)
///         > Update: Also consider using the `_scopeins_var()` macro over this.
#define _unique(varname) _deferred_concat(__##varname##_on_line_, __LINE__)

/** sifelse
    (s)tatic (aka compile-time) if-else statement.
    
    - Arguments are ((condition), (iftrue), (iffalse))
    - Use a ({ statement-expression )} to put any code into the iftrue and iffalse slots.
    - Not sure this is actually useful. Afaik `_Generic()` is syntax sugar around this for the only usecase I can think of – and it's barely useful.
        See why `_Generic()` isn't useful here: https://www.chiark.greenend.org.uk/~sgtatham/quasiblog/c11-generic/
*/
#define sifelse __builtin_choose_expr

/// Autotype convenience
///     Just `auto` wouldn't be searchable (and might produce conflict with C++ `auto` keyword?)
///         Update: [Sep 2025] Actually I don't care about greppability for this. Renamed to `auto`
#define auto __auto_type

/// isbetween macro
///     Checks whether `lower <= x <= upper`
///     ... Do we need a macro for this? ... Yes it's nice, I ended up using it quite a few times.
#define isbetween(x, lower, upper) (int) ({ \
    __auto_type __x = (x); \
    ((lower) <= __x) && (__x <= (upper)); \
})
/// isbetween macro – objc variant
///     Uses the `compare:` selector
#define isbetween_objc(obj, lower_obj, upper_obj) (int) ({ \
    __auto_type __x = (obj); \
    __auto_type __l = (lower_obj); \
    __auto_type __u = (upper_obj); \
    (__x && __l && __u) && ([__l compare:__x] != NSOrderedDescending) && ([__x compare:__u] != NSOrderedDescending); \
})

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
    nowarn_push(-Wnullable-to-nonnull-conversion)                              /** -Wnullable-to-nonnull-conversion triggers here when the fallback is NULL (nonsensically, I think). Guess these quirks are why it's not enabled by default. See `Xcode Nullability Settings.md` */ \
    ((0 <= __i) && (0 < __cnt) && (__i < __cnt)) ? (list)[__i] : (fallback);    /** We're making sure `count` and `i` are both positive before comparing them. Otherwise we might have subtle issues because `(int)-1 < (unsigned int)1` is false in C.*/\
    nowarn_pop()                                                                \
})

/// NULL-safe wrappers around common CF methods
#define MFCFRetain(cf)           (typeof(cf))  ({ __auto_type __cf = (cf); (!__cf ? NULL : CFRetain(__cf)); })                                                                  /// NULL-safe CFRetain || Note: Is a macro not a function for generic typing.
#define MFCFAutorelease(cf)      (typeof(cf))  ({ __auto_type __cf = (cf); (!__cf ? NULL : CFAutorelease(__cf)); })                                                             /// NULL-safe CFAutorelease || Dicussion: Probably use CFBridgingRelease() instead (it is already NULL safe I think.). Autorelease might be bad since autoreleasepools aren't available in all contexts. E.g. when using `dispatch_async` with a queue that doesn't autorelease. Or when running on a CFRunLoop which doesn't drain a pool after every iteration. (Like the mainLoop does) See Quinn "The Eskimo"s write up: https://developer.apple.com/forums/thread/716261
#define MFCFRelease(cf)          (void)        ({ __auto_type __cf = (cf); if (__cf) CFRelease(__cf); })                                                                        /// NULL-safe CFRelease
#define MFCFEqual(cf1, cf2)      (Boolean)     ({ __auto_type __cf1 = (cf1); __auto_type __cf2 = (cf2); ((__cf1 == __cf2) || (__cf1 && __cf2 && CFEqual(__cf1, __cf2))); })     /// NULL-safe CFEqual

/// Deferred release
///     Goal:                                   Turn acquiring a resource and scheduling it to be `CFReleased` into a one-liner. E.g. `CFStringRef str = MFCFDeferredRelease(CopySerialNumber());`
///     Doesn't work because:       mfdefer executes the cleanup block before exiting the current scope. So it will trigger prematurely at the end of the ({ statement expression }). Could not think of any solution.
///     Alternatives:                        Use `MFCFAutorelease()` if you need it to be a one-liner or just use `mfdefer ^{ MFCFRelease(cf); };` on a separate line.
#define __DO_NOT_USE_MFCFDeferredRelease(cf)     ((typeof(cf))  ({ typeof(cf) __cf = (cf); mfdefer ^{ if (__cf) CFRelease(__cf); }; __cf; }))

/// swapvars macro
///      - Based on: https://stackoverflow.com/a/8862167/10601702
///      - If one of the variables is called `__tmp`, then this won't work.
///      - Usage example:
///         ```
///         int a = 0; int b = 1;
///         swapvars(a, b)
///         // Now (a == 1), and (b == 0)
///         ```
#define swapvars(a, b) ({ __auto_type __tmp = a; a = b; b = __tmp; })

/// mfsign()
///     - Returns 1 if positive, -1, if negative, 0 otherwise.
///     - Is a macro to work with different types, int, float, char, etc.
///     - Won't work if the input value is variable called `__x`
///     - Called mfsign instead of sign to be greppable.
///     - Sidenote: The natural type of this expression is `int`. `typeof(1 > 0)` is also int. I didn't know that. Also see: https://stackoverflow.com/a/7687444/10601702
#define mfsign(x) (int) ({ __auto_type __x = (x); (__x > 0) - (0 > __x); })

/// Branch-prediction hints
///     Explanation and example: https://stackoverflow.com/a/133555/10601702
#define mflikely(b)    (long)__builtin_expect(!!(b), 1)
#define mfunlikely(b)  (long)__builtin_expect(!!(b), 0)

/// Clamp
///     Notes:
///     - Edgecase: If min > max, the result will always be min.
///     - Caution: Things can break if you mix `int` and `uint` in the input values – due to problems with C's `<` operator. See https://stackoverflow.com/q/2084949/10601702
#define mfclamp(x, min, max) (MAX((min), MIN((max), (x))))

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

