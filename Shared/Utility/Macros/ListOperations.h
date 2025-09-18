//
//  ListOperations.h
//  EventLoggerForBrad
//
//  Created by Noah Nübling on 25.12.24.
//

/// List-Operation macros
///     Overview:
///     - Functional-style syntax-sugar for simple list operations, such as 'findfirst()', 'allsatisfy()' or 'countmatches()'
///     - The macros (mostly) work on any subscriptable[] type – C arrays, C pointers, NSArrays, probably C++ vectors, etc. (Any caveats in the comments above each implementation)
///     - Typesafe and type-generic. Through use of `typeof()` and `__auto_type`
///
///     Should we actually use these?
///         - Contra: This is just syntax sugar around simple for-loops. Adding unnecessary abstractions is bad.
///         - Pro: Can be kinda fun and expressive for very simple stuff. E.g. `long nNulls = countmatches(arr, arrcount(arr), x, x == NULL);`.
///         - Pro: The macros are pretty short and simple and probably won't have to be updated much. So not really error prone or hard-to-maintain like macros sometimes are.
///
///     Why did I make this?
///         For fun ok mom.

/// ---------------------

#pragma once

#import "Logging.h"
#import "MFLoop.h"

///
/// Checking for items that meet a condition.
///
/// Examples:
///
/// `allsatisfy` - Check if all elements meet a condition
///     `bool allLongStrings = allsatisfy(stringsArray, [stringsArray count], str, str.length > 5);`
///
/// `anysatisfy` - Check if any element meets a condition
///     `bool containsSpace = anysatisfy(str, strlen(str), c, (c == ' '));`
///
/// `firstmatchi/lastmatchi` - Get index of first/last matching element (-1 if none found)
///     `int64_t firstDigitIdx    = firstmatchi(str, strlen(str), c, isdigit(c));`
///     `int64_t lastZeroIdx      = lastmatchi(numbers, arrcount(numbers), x, x == 0);`
///
/// `firstmatch/lastmatch` - Get first/last matching element (Or a `fallback` value if none found)
///     `char firstVowel       = firstmatch(str, strlen(str), '\0', c, (strchr("aeiou", c) != NULL));`
///     `NSString *lastCaps    = lastmatch(stringsArray, [stringsArray count], @"<fallback value: found no allcaps string>", str, [str isEqualToString:[str uppercaseString]]);`
///
/// Hint: You can also use multiple expressions and declare variables inside the `condition` by using a `({ statement-expression )}`, but at that point you should probably just use a for-loop (because you cannot set a debugger breakpoint inside the macro.)
/// Hint: You can access the index of the current item inside the `condition` through `__i`.

/// Define powerful base macro
///     Note: Will crash with `EXC_BAD_ACCESS` if the provided `lower` and `upper` indexes are out of range of the `list`. `list` can safely be NULL if `lower > upper`, because then the list will never get indexed. (If you set the `count` arg to 0 in the higher-level functions this is the case.)
#define __firstmatch(list, step, lower, upper, varname, condition...) /** The elipses `...` make it so the condition can contain commas without confusing the macro parser */\
(int64_t)                                                                   \
({                                                                          \
    __auto_type __list   = (list);                                          /** `__auto_type` makes this work with different sub[scriptable] types, such as C arrays, C ptrs and NSArrays! */ \
    int64_t     __result = -1;                                              /** Return-1 if no match is found */\
    loopc(__i, (lower), (upper), (step)) {                                  \
        __auto_type varname = __list[__i];                                  \
        if (condition) {                                                    \
            __result = __i;                                                 \
            break;                                                          \
        }                                                                   \
    }                                                                       \
    __result;                                                               \
})

#define     firstmatchi(list, count, varname, condition...)             (int64_t)                   __firstmatch((list),  1, 0, (count)-1, varname, condition)
#define      lastmatchi(list, count, varname, condition...)             (int64_t)                   __firstmatch((list), -1, 0, (count)-1, varname, condition)
#define      firstmatch(list, count, fallback, varname, condition...)                               ({ __auto_type ___list = (list); __auto_type ___i = firstmatchi(___list, (count), varname, condition); (___i == -1) ? (fallback) : ___list[___i]; }) /// Using triple underscore `___list` to avoid conflicts with vars in inner `__firstmatch()`macro.
#define       lastmatch(list, count, fallback, varname, condition...)                               ({ __auto_type ___list = (list); __auto_type ___i =  lastmatchi(___list, (count), varname, condition); (___i == -1) ? (fallback) : ___list[___i]; }) /** Not casting since casting result to `(typeof(list[0]))` didn't always work. (for a list of structs it said it 'expected an arithmetic or pointer type') */

#define      anysatisfy(list, count, varname, condition...)             (bool)                      (firstmatchi(list, count, varname, condition) != -1)
#define      allsatisfy(list, count, varname, condition...)             (bool)                      !anysatisfy(list, count, varname, !(condition))

/// Functional--style `reduce()`
///     Works with any subscriptable type – C Strings, C Arrays, NSArrays, etc.
///
///     Examples:
///     `countmatches`: Get number of matching elements:
///         ```
///         int64_t nNulls         = countmatches(arr, arrcount(arr), x, x == NULL);
///         ```
///     Notes:
///         - `partres_initval` means "Initial value of the partial result"
///         - `partres_updater` is an expression that modifies the `partres` using an `element` of the list.
///             After the `partres_updater` has been applied to every element of the list, the `partres` is the result of the macro.
///         - When list `count <= 0`, the `partres_initval` is returned verbatim.
///     Is this useful:
///         As of [Apr 2025] I haven't found a use for this. Reduce is way more confusing than a for-loop anyways imo.

#define mfreduce(list, count, partres_varname, partres_initval, element_varname, partres_updater...) \
(typeof(partres_initval))                               \
({                                                      \
    __auto_type __list = (list);                        \
    __auto_type partres_varname = (partres_initval);    /** Accumulator (aka partres) type is automatically inferred from `partres_initval` */\
    loopc(__i, (count)) {                               \
        __auto_type element_varname = (__list)[__i];    \
        partres_updater;                                \
    }                                                   \
    partres_varname;                                    \
})

#define countmatches(list, count, varname, condition...) (int64_t) mfreduce(list, count, __n, (int64_t)0, varname, ({ if (condition) __n += 1; }))

/// Find `listmax()`
///     > Find the 'maximum' element in the list by some measure.
///     All macros in this group return an anonymous struct with 3 fields:
///       - 1. key: The "comparison key" for the found elment      ("comparison keys" are explained below)
///       - 2. index: Index of the found element
///       - 3. element: The found element itself
///       - Empty lists return `{.key = 0/NULL, .index = -1, .element = 0/NULL}` – which can be checked via the .index field.
///       - The struct is anonymous, so you need to use `__auto_type` to store it in a variable.
///
///     Notes:
///         - Works on any subscriptable type – NSArray, C Array, C String, probably various C++ types.
///         - Could have implemented this using mfreduce, but that's confusing.
///         - These macros have two types of user-provided expression:
///             - `keyfn` is an expression that maps a list element to its **comparison key**. All elements are compared by their comparison key.
///             - `compfn` is an expression that determines which of two *comparison keys* is larger. `>0` means the first key is larger `<0` means the second is larger. The simplest `compfn` is `(key1 - key2)`. C's `strcmp(key1, key2)` also works as expected.!
///                 > The element with the largest/smallest *comparison key* according to the *compfn* is returned from the macro.
///
///     Caution:
///         There are various potential problems if a comparison key is an `unsigned int`:
///             1. The greater-than `>` operator breaks when comparing uint with int of the same size. E.g: `INT64_MIN < ((uint64_t)123)` is - strangely - false. See https://stackoverflow.com/q/2084949/10601702. (Not sure this can happen here, but bit me in the a.. elsewhere.)
///             2. If the `compfn` subtracts the keys from eachother, unsigned ints could very easily underflow – causing unexpected results.
///         -> Solution:
///             In your `listmax()` keyfn, consider casting your key to a `double` or signed int. (`listmaxk()` does this automatically)
///
///     Examples:
///
///     Find string with maximum length:
///         ```
///         const char* strings[] = {"helloooo", "world", "test"};
///         __auto_type result = listmaxk(strings, arrcount(strings), str, strlen(str));
///         // result.key = 8, result.index = 0, result.element = "helloooo"
///         ```
///     Find number with minimum absolute value
///         ```
///         int nums[] = {5, -3, 4, -7};
///         __auto_type result = listmink(nums, arrcount(nums), n, abs(n));
///         // result.key = 3, result.index = 1, result.element = -3,
///         ```
///     Custom comparison: find person with highest age, break ties by alphabetic name order
///         ```
///         struct Person { char* name; int age; } people[] = {
///           {"Alice", 25}, {"Bob", 25}, {"Charlie", 20}
///         };
///         __auto_type result = listmax(people, arrcount(people), p, p, a, b, ({
///             (a.age - b.age) ?: strcmp(a.name, b.name);
///         }));
///         /// result.key = <bob's struct>, result.index = 1, result.element = <bob's struct>
///         ///     (Note how result.key and result.element are the same because with "... p, p, ..." we made key = element.)
///         ```
///         Note: To find the minimum instead you can simply invert the comparison function by multiplying it `* -1`
///

#define _listmax(list, count, varname_keyfn, keyfn, varname_compfn_1, varname_compfn_2, compfn) ({ \
    __auto_type __list = (list);                        \
    __auto_type __count = (count);                      \
    typeof((list)[0]) varname_keyfn;                    /** Declare up here so that `typeof(keyfn)` works in the struct decl below. */\
    struct {                                            \
        typeof(keyfn)       key;                        \
        int64_t             index;                      \
        typeof((list)[0])   element;                    \
    }                                                   \
    __result = {                                        \
        .key        = 0,                                /** `= 0` compiles even for structs in this context. Not sure why (usually you need `= {0}` to init structs) */\
        .index      = -1,                               \
        .element    = 0,                                \
    };                                                  \
    loopc(__i, __count) {                               \
        varname_keyfn = __list[__i];                    \
        __auto_type __currkey = (keyfn);                /** Comparison key for the current element */        \
        bool __replace;                                 \
        if (__i == 0) {                                 \
            __replace = true;                           \
        } else {                                        \
            __auto_type varname_compfn_1 = __currkey;           \
            __auto_type varname_compfn_2 = __result.key;        \
            __replace = (compfn) > 0;                           \
        }                                                       \
        if (__replace) {                                        \
            __result.key = __currkey;                           \
            __result.index = __i;                               \
        };                                                      \
    }                                                           \
    if (__result.index != -1)                                   \
        __result.element = __list[__result.index];              /** Fill in the .element field. */ \
    __result;                                                   /** Returns anonymous struct. Use __auto_type to store the struct in a variable. */ \
})

#define listmax(list, count, varname_keyfn, keyfn, varname_compfn_1, varname_compfn_2, compfn)      _listmax((list), (count), varname_keyfn, (keyfn), varname_compfn_1, varname_compfn_2, (compfn)) /// Find using custom comparison function.
#define listmaxk(list, count, varname, keyfn...)                                                    _listmax((list), (count), varname, (double)(keyfn), __a, __b,  (__a - __b))                     /// Find maximum by "comparison (k)ey"
#define listmink(list, count, varname, keyfn...)                                                    _listmax((list), (count), varname, (double)(keyfn), __a, __b, -(__a - __b))                     /// Find minimum by "comparison (k)ey"

/// mfsort - in-place sort
///     Only works on C arrays, not NSArrays. (Cause we're using c's `qsort_b`.)
///
///     API is almost the same as the `listmax` macros – see it's docs for explanation of "comparison key", compfn, etc.
///
///     Examples:
///
///     Sort numbers in descending order
///         ```
///         int nums[] = {3, 1, 4, 1, 5};
///         sortlistk(nums, arrcount(nums), n, -n);
///         // nums becomes {5, 4, 3, 1, 1}
///         ```
///     Sort by string-length
///         ```
///         const char *words[] = {"tree", "larbre", "bicycle", "fahrrad", "velo"};
///         sortlistk(words, arrcount(words), w, strlen(w));
///         ```
///     Sort alphabetically:
///         ```
///         const char *words[] = {"tree", "larbre", "bicycle", "fahrrad", "velo"};
///         sortlist(words, arrcount(words), w1, w2, strcmp(w1, w2));
///         ```
///     Sort reverse-alphabetically
///         ```
///         const char *words[] = {"tree", "larbre", "bicycle", "fahrrad", "velo"};
///         sortlist(words, arrcount(words), w1, w2, -strcmp(w1, w2));
///         ```
///     Custom comparison: sort people by highest age, break ties by alphabetic name order
///         ```
///         struct Person { char* name; int age; } people[] = {
///           {"Alice", 25}, {"Bob", 25}, {"Charlie", 20}
///         };
///         sortlist(people, arrcount(people), p1, p2, ({
///             (p1.age - p2.age) ?: strcmp(p1.name, p2.name);
///         }));
///         ```
///
///
#define _sortlist(list, count, varname_keyfn, keyfn, varname_compfn_a, varname_compfn_b, compfn) ({        \
    qsort_b((list), (count), sizeof((list)[0]), ^int (const void *__a, const void *__b) {               \
        typeof((list)[0]) varname_keyfn     = *(typeof((list)[0])*)__a; \
        __auto_type       __keya            = (keyfn);                  /** Compute first comparison key using `keyfn`*/ \
                          varname_keyfn     = *(typeof((list)[0])*)__b; \
        __auto_type       __keyb            = (keyfn);                  /** Compute second comparison key */ \
        int __result;                                                   \
        do {                                                            /** Create new scope so that the user's varnames for the keyfn and the compfn don't collide */\
            __auto_type varname_compfn_a = __keya;                      \
            __auto_type varname_compfn_b = __keyb;                      \
            __result = (int)(compfn);                                   /** Compare the 2 keys using `compfn` */ \
        }                                                               \
        return __result;                                                \
    });                                                                 \
})
#define sortlistk(list, count, varname, keyfn)              _sortlist((list), (count), varname, (double)(keyfn), __a, __b, (__a - __b)) /** Casting the key to double for same reason we do it in `listmaxk`. (Potential unsigned int problems.) */
#define sortlist(list, count, varname1, varname2, compfn)   _sortlist((list), (count), ___element, ___element, varname1, varname2, (compfn))

/// Functional-style map()
///     Example:
///         mapa:
///             `NSArray<NSString *> *wordsArray = @[@"Tree", @"Baum", @"Arbre", @"Bicycle", @"Fahrrad", @"Velo"];`
///             `NSUInteger *wordLengths = mapa(wordsArray, w, w.length);`
///             `mfdefer ^{ free(wordLengths); };`
///
///         mapns:
///             `NSArray<NSString *> *wordsButCool = mapns(wordsArray, w, [w stringByAppendingString:@" (butcool)"]);`
///
///     Discussion
///         - 2 variants: `mapa` and `mapns`:
///             (a): Stores the mapping result in newly allocated memory on the heap. (Use this for C types) (Don't forget to free() the result!)
///             (ns): Stores the mapping result in an NSArray. (Use this for objc objects.)
///             -> Both variants can take any subscriptable type as input, only the result will be stored in the specific collection type.
///
///     Should we use this?
///         - This is nice and concise, but massive downside: You can't set a debug breakpoint inside a macro
///             -> Except in the most simple cases cases, using a for-loop is probably better than these macros.
///
///     - Tangent: C Arrays for storing objc objects?
///         I tried to support that here, but it's not worth it. [Dec 2024]
///         To make C Arrays work with `__strong` object ptrs under ARC, you have to either
///             1. store the objects in a normal stack-allocated C array (Which we can't nicely hide behind a macro I think)
///             2. Heap-allocate memory but then be very careful not to confuse ARC:
///             a) Zero-init the alloced memory (e.g. using calloc() over malloc())
///             b) Before you free() the memory, you have to "deinitialize" it by looping through all elements and setting all objc pointers to nil. (memset to 0 doesn't work. You apparently have to explicitly store nil for ARC to release the objects in the dynamic memory.)
///             -> Read more:
///                 - This malloc-zeroinit-use-setnil-free pattern is shown in WWDC 2018 "What's new in LLVM" under *Structs with ARC Fields Need Care for Dynamic Memory Management*
///                     (From my testing, the same seems to apply whether you're storing structs or single ARC object ptrs using dynamic memory management.)
///                     WWDC Slides: https://devstreaming-cdn.apple.com/videos/wwdc/2018/409t8zw7rumablsh/409/409_whats_new_in_llvm.pdf
///                  - StackOverflow crash due to using malloc() without zero-inititng. See: https://stackoverflow.com/a/9119631/10601702
///                  - These section in the clang ARC documentation: 1. "Application of the formal C rules to nontrivial ownership qualifiers" " 2. "Conversion of pointers to ownership-qualified types"
///                     -> These are hard to read. > To give you a head start: AFAIK "A dynamic object of nontrivially ownership-qualified type" means a malloced/calloced array holding `__strong` or `__weak` object ptrs.
///                     -> Sidenote: IIRC the docs say that **dynamic memory** and **unions** have these ARC caveats, but every other C/C++ language feature should work with ARC just as expected.
///
///     - Sidenote: I also tried building this ontop of mfreduce macro, but that feels more complicated that the loops.

#define mapns(src, count, varname, transform...) ({         /** Creates a new NSMutableArray to store the mapped values. -> The mapped-to values need to be objc objects. */\
    __auto_type __src = (src);                              \
    __auto_type __count = (count);                          \
    typeof(src[0]) varname;                                 /** Declaring varname up here so that sizeof(transform) and typeof(transform) works below. */ \
    NSMutableArray<typeof(transform)> *__result;            /** This makes the type-system exactly infer the type of the transformed array - I didn't know C had such powerful generic typing! Kinda cool. */ \
    __result = [NSMutableArray array];                      \
    loopc(__i, __count) {                                   \
        varname = __src[__i];                               \
        [__result addObject:(transform)];                   \
    }                                                       \
    __result;                                               \
})

#define mapa(src, count, varname, transform...) ({          /** (a)llocates a new array for the mapped values. Don't forget to free() it! Not suited for storing objc object ptrs. (Need to use malloc-zeroinit-use-setnil-free pattern when storing `__strong` or `__weak` objects in dynamic memory under ARC [Dec 2024] – just avoid it and use mapns() instead.)*/\
    __auto_type __src = (src);                              \
    __auto_type __count = (count);                          \
    typeof(src[0]) varname;                                 \
    typeof(transform) *__result;                            \
    __result = malloc(__count * sizeof(__result[0]));       \
    loopc(__i, __count) {                                   \
        varname = __src[__i];                               \
        __result[__i] = (transform);                        \
    }                                                       \
    __result;                                               \
})
