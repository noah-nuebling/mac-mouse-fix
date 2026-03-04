//
// --------------------------------------------------------------------------
// xxxSharedMacros.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2026
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// Old stuff from `SharedMacros.h` which is not worth the complexity [Mar 4 2026]
///     The old `SharedMacros.h` code had two sections denoting origin of the macros:
///         1. `#pragma mark - Macros from mac-mouse-fix > SharedUtility.h`
///         2. `#pragma mark - Macros from EventLoggerForBrad > SharedMacros.h`
///         We removed these sections and reshuffled the macros.

/// ---

/// Old note about naming patterns: (I still think combining two words producing global uniqueness for greppability is a good insight [Mar 2026])
///     Macro naming pattern
///         Short & all-lowercase   -> easy to type
///         Unique                          -> easy to grep
///
///         If the name isn't unique, prefix `mf` to make it unambiguous.
///         Sweetspot seems to be combining two words.

#pragma mark - Helper macros

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

#pragma mark - Enduser macros

/// Convenience macro to check whether one value is a bitwise-subset of another
#define bitsub(sub, super) (bool) ({    \
    __auto_type __sub = (sub);          \
    (__sub & (super)) == __sub;         \
})

    /// `makerange_fromto` macro
    ///     Alternative to NSMakeRange(), lets you specify the range in terms of (firstindex, lastindex) instead of (firstindex, count) – which I find more intuitive.
    #define makerange_fromto(firstindex, lastindex) ({                     \
        __auto_type __firstindex = (firstindex);                    \
        NSMakeRange(__firstindex, (lastindex) - __firstindex + 1);  \
    })

    /// Clamp
    ///     Notes:
    ///     - Edgecase: If min > max, the result will always be min.
    ///     - Caution: Things can break if you mix `int` and `uint` in the input values – due to problems with C's `<` operator. See https://stackoverflow.com/q/2084949/10601702
    #define mfclamp(x, min, max) (MAX((min), MIN((max), (x))))


    /// isbetween macro
    ///     Checks whether `lower <= x <= upper`
    ///     ... Do we need a macro for this? ... Yes it's nice, I ended up using it quite a few times.
    ///     ... We already had an ISBETWEEN macro ... and this is barely useful [Mar 2026]
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

    /** sifelse
        (s)tatic (aka compile-time) if-else statement.
        
        - Arguments are ((condition), (iftrue), (iffalse))
        - Use a ({ statement-expression )} to put any code into the iftrue and iffalse slots.
        - Not sure this is actually useful. Afaik `_Generic()` is syntax sugar around this for the only usecase I can think of – and it's barely useful.
            See why `_Generic()` isn't useful here: https://www.chiark.greenend.org.uk/~sgtatham/quasiblog/c11-generic/
    */
    #define sifelse __builtin_choose_expr

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

/// `MFNSSetMake()`
///     Substitute for missing NSSet literal
///     You could also do `[NSSet setWithArray:@[objects...]]`, but I assume that's less efficient.

#define MFNSSetMake(objects...) ({                                          \
    id __objects[] = { objects };                                           \
    [[NSSet alloc] initWithObjects: __objects count: arrcount(__objects)];    \
})

/// `isprotocol` macro
///     - Works on normal objects and class objects just like `isclass()`
///     - The docs say this is slow, and to use -[respondsToSelector:] instead See: https://developer.apple.com/documentation/objectivec/nsobject/1418893-conformstoprotocol?language=objc
#define isprotocol(x, protocolname) [[x class] conformsToProtocol: @protocol(protocolname)]

/// `isclass` macro
///     (xxxSharedMacros.h note: We're actually still using this macro but removed all this verbose documentation/notes. [Mar 4 2026])
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

/// weakify/strongify macros
///     These are used to prevent retain cycles when using objc blocks.
///     Commentary: [Sep 2025]
///         - Traditionally defined in libextobjc/EXTScope.h as @weakify and @strongify.
///         - I thought we had that in the MMF project? But I can't find it. Might as well do our own simplified implementation.
///         - ... I didn't actually end up using this [Sep 2025]

#define weakify(varnames...)   FOR_EACH(_weakify,   (), varnames)
#define strongify(varnames...) FOR_EACH(_strongify, (), varnames)

#define _weakify(varname) \
    __weak __auto_type _weakified_##varname = varname;

#define _strongify(varname) \
    __strong __auto_type varname = _weakified_##varname;


/// ifcastp & ifcastpn
///     Works just like ifcast & ifcastn but for objc protocols instead of classes.

#define ifcastpn(varname, protocolname, newvarname)                                                             \
    if (varname && [varname conformsToProtocol: @protocol(protocolname)])                                        \
        _scopeins_var(id __ifcast_temp = varname)                                                                   \
            _scopeins_var(id<protocolname> _Nonnull const __attribute__((unused)) newvarname = __ifcast_temp)

#define ifcastp(varname, protocolname)  \
    ifcastpn(varname, protocolname, varname)
