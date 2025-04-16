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

/// Convenience macro to check whether one value is a bitwise-subset of another
#define bitsub(sub, super) (bool) ({    \
    __auto_type __sub = (sub);          \
    (__sub & (super)) == __sub;         \
})

/// Logical implication operator (Usually written as `a -> b`).
///     Meaning "if a is true, then b must be true as well."
///     Example: `assert(ifthen(it_rains, it_is_wet))`
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

/// array count convenience
#define arrcount(x) (sizeof(x) / sizeof((x)[0]))

/// Autotype convenience
///     Just `auto` wouldn't be searchable (and might produce conflict with C++ `auto` keyword?)
#define auto_t __auto_type

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
#define safeindex(list, count, i, fallback) (typeof((list)[0])) ({ \
    __auto_type __i = (i); \
    __auto_type __cnt = (count); \
    ((0 <= __i) && (0 < __cnt) && (__i < __cnt)) ? (list)[__i] : (fallback); /** We're making sure `count` and `i` are both positive before comparing them. Otherwise we might have subtle issues because `(int)-1 < (unsigned int)1` is false in C.*/\
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

/// sign()
///     - Returns 1 if positive, -1, if negative, 0 otherwise.
///     - Is a macro to work with different types, int, float, char, etc.
///     - Won't work if the input value is variable called `__x`
///     - Sidenote: The natural type of this expression is `int`. `typeof(1 > 0)` is also int. I didn't know that. Also see: https://stackoverflow.com/a/7687444/10601702
#define sign(x) (int) ({ __auto_type __x = (x); (__x > 0) - (0 > __x); })

/// Branch-prediction hints
///     Explanation and example: https://stackoverflow.com/a/133555/10601702
#define mflikely(b)    (long)__builtin_expect((0!=(b)), 1)
#define mfunlikely(b)  (long)__builtin_expect((0!=(b)), 0)

/// Clamp
///     Notes:
///     - Edgecase: If min > max, the result will always be min.
///     - Caution: Things can break if you mix `int` and `uint` in the input values – due to problems with C's `<` operator. See https://stackoverflow.com/q/2084949/10601702
#define mfclamp(x, min, max) (MAX((min), MIN((max), (x))))

/// mfcycle
///     - Generalization of modulo.
///     - Is a macro to work with multiple types.
///         ... should probably just make this a function that works on double.
///     - Moves n into the half-open interval `[lower, upper)` (if includeUpperNotLower == false) or `(lower, upper]` (if includeUpperNotLower == true)
///     - If lower > upper, the result will be mirrored (see code)  – feels like a natural extension of this operation?
///     -`mfcycle(n, 0, z, false)` is equivalent to `n % z`
///         ... Actually not quite true bc `%` is weird for negative inputs in C. Something about euclidian modulo iirc.
#define mfcycle(n, lower, upper, includeUpperNotLower)                                      \
(typeof((n)+(lower)+(upper)))                                                               \
({                                                                                          \
    typeof((n)+(lower)+(upper)) __n = (n);                                                  /** typeof((n)+(lower)+(upper))` should 'promote' the internal calculations to a type that can support them. E.g. if `n` is double but `lower` is int, the internal calculations (and return type) will be double */\
    typeof(__n) __lower = (lower);                                                          /** We create local variables to prevent multiple-evaluation in case the macro args are complex expressions. || We prefix local vars with `__` to prevent conflicts in case a macro param is a variable of the same name. */ \
    typeof(__n) __upper = (upper);                                                          \
    bool __inclup = (includeUpperNotLower) != 0;                                            \
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

