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

/// loopc macro – (loop)ing (c)onvenience.
///    - Advantages
///        - Concise, consistent way of iterate up (or down) a range of integers
///        - works very similarly to for-in-range loops in Python.
///        - Automatically chooses/casts to appropriate type (usually int64_t) to avoid underflows/overflows – all the choices about types in for-loops are centralized here.
///    - Examples / comparison to Python:
///        Iterate [0,1,2]
///            Macro:   `loopc(i, 0,3,+1)`
///            Python: `for i in range(0,3,+1):`
///        You can omit args for convenience:
///            Iterate [0,1,2] omitting step:
///                Macro: `loopc(i, 0,3)`
///                Python: `for i in range(0,3):`
///            Iterate [0,1,2] omitting lower bound:
///                Macro: `loopc(i, 3)`
///                Python: `for i in range(3):`
///        You can iterate backwards:
///            Iterate [2,1,0]:
///                 Macro: `loopc(i, 0,3,-1)`                       (Same as forward iteration, just with step=-1)
///                 Python: `for i in range(2,-1,-1):`    (Difference in Python: Upper bound comes before lower bound, and the bounds are offset by -1 compared to the forward iteration.)
///    - Other details:
///        - If lowerBound > upperBound, no iterations will take place, it's how we specify the a 'null' range.
///            Tried repurposing this to iterate backwards, but having a 'null' range feature is crucial. – better to let the 'step' specify iteration direction.
///        - Args are re-evaluated every iteration if they are expressions. (Similar to normal for-loop) Could cache this using `_unique` or `_scopeins_var`macro, but sometimes you want the loop params to update during the iteration. Prolly not worth making things more error prone for micro-optimizations.
///        - Previously there was a loopc and loopr macro, but we merged them on [Sep 18 2025]
///
///     - Failed experiment: Array slicing
///         We had a python-slicing-like API, but it was more verbose than the base `loopc()` API and offered no real benefits.
///             It worked like this:
///                                        `loops(i, arrayCount, -2, z(1), n(-1))` /// z() meant 'relative to zero', n() means 'relative to the length of the array'.
///                  > corresponded to python       `array[1:-1:-2]` slice.
///                  > Corresponds to                    `loopc(i, -2, 1, arrayCount-1)`
///                  Aside from the syntactic sugar via negative indexes, It also included bounds checks – but I don't think they are important, since `EXC_BAD_ACCESS` is enough of a bounds check.
///            Interesting: When writing this API, I tried to implement -1 referencing the last element without the n() wrapper (like python) but this caused ambiguities with null ranges.
///                (python also has these ambiguities e.g. [n:0:-1] doesn't include the first element. To include it, you have to use [n:None:-1], which is weird – also we're working with C integers which don't have a NULL value. (NAN is only for floats afaik.)
///                (I think adding extra params –– n and z –– was the best solution to avoid ambiguities – but it also goes against the purpose of array-slicing - conciseness)
///            Also I think the point of slices is to have a 'window' into a list that you can treat as if it was itself a list – store it in a var, iterate through its elements, etc. – none of that is feasible here.
///            -> Conclusion: loops() (s stands for slice) is pretty verbose and not worth using over loopc() – so we removed it.
///
///     - I knowww this is totally unnecessary, I'm just obsessed with designing my own shitty language with macros and I can't stop.
///         - But it seriously feels kinda wrong to wrap such a fundamental language feature in macros?
///         - Update [Sep 2025] This actually seems quite valuable:
///             - For quick iteration, the `loopc(i, arrcount(arr))` syntax has proven valuable.
///             - It's nice I think having all the worries/decisions about types of the loop variable and params centralized in one place.
///                 - Example of tricky decision: Backwards loops have a footgun due to unsigned integer underflows. (See `Clang Diagnostic Flags - Sign.md`) (Not that I write too many backwards loops)
///             - I think it's nice to have a 'small delta' between syntax for forward and backward loops over the same range of numbers.
///             - Criticism: `loopc(i, arrcount(arr))` is used dramatically more often than the other variants. Maybe we should only keep that, but remove the more complex cases – perhaps, for the more complex cases, the abstraction is not worth learning and we should just use native c for-loops. I think the only thing I dislike about native C for loops for more complex cases is backwards iteration. But I could probably just get used to that.

#define loopc(varname, args...) _loopc_selector(args, _loopc_3, _loopc_2, _loopc_1)(varname, args)

#define _loopc_selector(arg1, arg2, arg3, macroname, ...) macroname
    
#define _loopc_1(varname, count) /** 1 arg */ \
    for (typeof((count) + 0) varname = 0; varname < (count); varname++)

#define _loopc_2(varname, lo, hi) /** 2 args */ \
    for (int64_t varname = (lo); varname < (int64_t)(hi); varname++)                        /** Cast hi to int64_t to prevent underflow issue if hi is unsigned and lo is negative [Sep 2025] */\

#define _loopc_3(varname, lo, hi, step) /** 3 args */                                           \
    static_assert((step) != 0, "_loopc_3: step must not be 0");                            \
    for (                                                                                  \
        int64_t varname = ((step) > 0) ? (lo) : ((int64_t)(hi))-1;                         /** [Sep 2025] I'm prettyy sure we only need to cast `hi` to `int64_t` to prevent underflow issues. But this is hard to think about. */ \
                          ((step) > 0) ? (varname < (int64_t)(hi)) : (varname >= (lo));    \
        varname += (step)                                                                  \
    )

@interface MFLoop : NSObject

@end
