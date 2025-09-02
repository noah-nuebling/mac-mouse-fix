//
//  MFLoop.h
//  EventLoggerForBrad
//
//  Created by Noah Nübling on 22.12.24.
//

#pragma once
#import <Foundation/Foundation.h>

#import "MFDefer.h"
#import "Logging.h"

/// looping convenience
///     Notes:
///         - Advantages
///             - Caches the `count` arg in case it's a function call or complex expression – preventing it from being evaluated every iteration. (Which happens when you call a function in a normal for-loop header)
///             - Easily iterate up (or down) a range of integers – works similar to for-in-range loops in python.
///         - Caution:
///             Differences to python:
///                 A python `for i in range(0,3,+1):` loop iterates `[0,1,2]` but `loopr(i, +1,0,3)` iterates `[0,1,2,3]`. (The upper bound is included.).
///                 A python `for i in range(3,0,-1):` loop iterates `[3,2,1]` but `loopr(i, -1,0,3)` iterates `[3,2,1,0]`. (The lower and upperbound args always have the same position, while in python they are swapped if `step < 0`) (That's why, in python, the args are called 'start' and 'stop', but ours are called 'lower' and 'upper')
///             Other details:
///                 - If lower > upper, no iterations will take place, it's how we specify the a 'null' range.
///                     Tried repurposing this to iterate backwards, but having a 'null' range feature is crucial. – better to let the 'step' specify iteration direction.
///                 - If `step == 0` that causes an assert-fail and the loop to be turned off. (Otherwise we'd infinite-loop)
///     Examples:
///         Standard iteration:
///             ```
///             loopr(i, +1, 0, 3) { printf("%lld ", i); }
///             // prints "0 1 2 3 "
///             ```
///         Descending in steps of 2:
///             ```
///             loopr(i, -2, 3, 9) { printf("%lld ", i); }
///             // prints "9 7 5 3 "
///             ```
///         Iterating negative numbers also works:
///             ```
///             loopr(i, +2, -50, -41) { printf("%lld ", i); }
///             // prints "-50 -48 -46 -44 -42" || Also note how the last num -42 != the upperbound -41. Can happen if abs(step) > 1
///             ```
///         Array convenience: (loopc)
///             ```
///             int arrayCount = 4;
///             loopc(i, arrayCount) { printf("%lld ", i); }
///             // prints "0 1 2 3"
///             ```
///
///     Array slicing?
///         We had a python-slicing-like API, but it was more verbose than the base `loopr()` API and offered no real benefits.
///             It worked like this:
///                                        `loops(i, arrayCount, -2, z(1), n(-1))` /// z() meant 'relative to zero', n() means 'relative to the length of the array'.
///                  > corresponded to python       `array[1:-1:-2]` slice.
///                  > Corresponds to                    `loopr(i, -2, 1, arrayCount-1)`
///                  Aside from the syntactic sugar via negative indexes, It also included bounds checks – but I don't think they are important, since `EXC_BAD_ACCESS` is enough of a bounds check.
///            Interesting: When writing this API, I tried to implement -1 referencing the last element without the n() wrapper (like python) but this caused ambiguities with null ranges.
///                (python also has these ambiguities e.g. [n:0:-1] doesn't include the first element. To include it, you have to use [n:None:-1], which is weird – also we're working with C integers which don't have a NULL value. (NAN is only for floats afaik.)
///                (I think adding extra params –– n and z –– was the best solution to avoid ambiguities – but it also goes against the purpose of array-slicing - conciseness)
///            Also I think the point of slices is to have a 'window' into a list that you can treat as if it was itself a list – store it in a var, iterate through its elements, etc. – none of that is feasible here.
///            -> Conclusion: loops() (s stands for slice) is pretty verbose and not worth using over loopr() – so we removed it.
///
///     I knowww this is totally unnecessary, I'm just obsessed with designing my own shitty language with macros and I can't stop.
///         > But it seriously feels kinda wrong to wrap such a fundamental language feature in macros?

struct loop_range {
    /** Notes:
        - struct-member's are prefixed with `_` to avoid conflicts in our macros.
        - Discussion from when we used to create these values directly in the loopr() macro:
            By using int here instead of `__auto_type` there should be no problems even if start/end are double or unsigned. 64 bit should prevent any realistic chance of overflows I think.
    */
    int64_t _step; int64_t _lower; int64_t _upper;
};

#define _loop_over_range(varname, params) /** Powerful base macro */ \
    struct loop_range _unique(_loop_range) = (params); /** This var is created in the callers scope, so we need to make it unique. */\
    if (_unique(_loop_range)._step == 0) {                                                                                 \
        mfassert(false, @"loop macro on line %d: step must not be 0. Default is 1 (or -1 to iterate backwards). Overriding params to turn off loop.", __LINE__);   \
        _unique(_loop_range)._lower = 0;                                                                                   \
        _unique(_loop_range)._upper = -1;                                                                                  \
    }                              \
    for (                                                                                                                   \
        int64_t varname = (_unique(_loop_range)._step > 0) ? _unique(_loop_range)._lower : _unique(_loop_range)._upper;     \
                          (_unique(_loop_range)._step > 0) ? (varname <= _unique(_loop_range)._upper) : (varname >= _unique(_loop_range)._lower);        \
        varname += _unique(_loop_range)._step  \
    )

#define loopr(varname, step, lower, upper) /** Iterate an arbitrary (r)aw (r)ange of integers */ \
    _loop_over_range(varname, ((struct loop_range){ ._step = (step), ._lower = (lower), ._upper = (upper) }))

#define loopc(varname, count) /** (c)onveniently iterate all indexes of an array, given the (c)ount. */ \
    for (typeof((count) + 0) varname = 0; varname < (count); varname++)

#pragma mark - Unused

#define __DONT_USE_loops(varname, arrcount, step, lower, upper) /** Iterate a (s)lice of an array - python style!*/\
    _loop_over_range((varname), _arrslice_preprocess((arrcount), (step), __loops__decodeindex_ ## lower, __loops__decodeindex_ ## upper))

#define __DONT_USE__loops__decodeindex_z(i) (i), false      /// Index is relative to the first index of the array – (z)ero
#define __DONT_USE__loops__decodeindex_n(i) (i), true       /// Index is relative to the le(n)gth of the array.        This macro expands into 2 function args – it's meant to set an index param and correxponding `isendrel` (is end-relative?) param of `_arrslice_preprocess()` to true.

#define __DONT_USE_loop_over_rangee(elm_varname, list, count)             /** Extract list elements automatically. Don't use this, it's not any clearer than `loopc()` imo. */\
__auto_type _unique(forinloop_list) = (list);     \
loopc(__forinloop_idx, count)                      \
    _Pragma("clang diagnostic push")                                      \
    _Pragma("clang diagnostic ignored \"-Wignored-attributes\"")       /**Ignore warnings about __unsafe_unretained usage. Without __unsafe_unretained this won't compile if the list elements are objc objects. */\
    for (                                           \
        typeof((list)[0]) __unsafe_unretained                          /** This inner loop only iterates once. It's sole purpose is to make the `elm_varname` variable available in the loop body. Very hacky. */ \
            elm_varname = _unique(forinloop_list)[__forinloop_idx], \
            *__forinloop_guard = &(elm_varname);                        /** Hacky way to make the loop only run once. */ \
        __forinloop_guard != NULL;                                  \
        __forinloop_guard = NULL                                    \
    )\
    _Pragma("clang diagnostic pop")


@interface MFLoop : NSObject

@end
