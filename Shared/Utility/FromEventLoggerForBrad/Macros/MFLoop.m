//
//  MFLoop.m
//  EventLoggerForBrad
//
//  Created by Noah Nübling on 22.12.24.
//

/// Python-style loops and slicing.

#import "MFLoop.h"

@implementation MFLoop

+ (void)load {
    
    /// Run tests

}

/// vvv Unused
///     arrayslicing API (`loops()`) is worse than generic API `loopr()` – so we're disabling it.

//static inline struct loop_range _arrslice_preprocess(int64_t list_count, int64_t step, int64_t lower, bool lower_isendrel, int64_t upper, bool upper_isendrel) {
//    
//    /// Helper function – Converts arrayslice params to params for our loopr() macro
//
//    #define nullslice (struct loop_range){ ._step = 1, ._lower = 0, ._upper = -1 }; /// These params disable the loopr.
//
//    /** Validate count  */
//    if (list_count < 0) {
//        mfassert(false, "arrayslice: list_count (%lld) is < 0", list_count);
//        return nullslice;
//    }
//    if (list_count == 0) {
//        return nullslice;
//    }
//    
//    /** Make indexes relative to last element of array. */
//    if (lower_isendrel) lower = (list_count) + lower;
//    if (upper_isendrel) upper = (list_count) + upper;
//    
//    /// Check nullslice
//    bool isnull = lower > upper; /// This is a 'null' range.
//    if (isnull) {
//        if (lower-1 > upper) mfassert(false, "arrayslice: nullslice's lower-upper > 1. Setting upper==lower-1 is the expected way to turn off a loop, but upper is even smaller than that. Might indicate a logic error. slice: [%lld, %lld]", lower, upper);
//    }
//    
//    /** Check bounds */
//    bool lowerok = isbetween(lower, 0, list_count-1);
//    bool upperok = isbetween(upper, 0, list_count-1);
//    if (isnull) {
//        mfassert(lowerok || upperok, "arrayslice: no index of null slice [%lld, %lld] is in range. Usually at least one idx is in the array bounds [0, %lld]. Might indicate a logic error.", lower, upper, list_count-1);
//    } else {
//        mfassert(lowerok && upperok, "arrayslice: some index of non-null array slice [%lld, %lld] is out of the array bounds [0, %lld]. Need to clamp it to prevent out-of-bounds access.", lower, upper, list_count-1);
//    }
//    if (!lowerok) {
//        lower = mfclamp(lower, 0, list_count-1);
//    }
//    if (!upperok) {
//        upper = mfclamp(upper, 0, list_count-1);
//    }
//    
//    /** Buffer validation
//        We used to care about filling a buffer from the slice instead of just iterating over it. */
//    
////    if (buffer_count < 0) {
////        mfassert(false, "arraysliceb: buffer_count is not greater zero (%lld)", buffer_count);
////        return (struct arrslice_loop_range){ ._step = 1, ._lower = 0, ._upper = -1 }; /// These params will  will cause The loopr() to iterate 0 times
////    }
////    if (upper-lower+1 > buffer_count) {
////        mfassert(false, "arraysliceb: Calculated slice is too large for buffer. buffer count: %lld, slice [%lld, %lld] [%lld elements]", (int64_t)buffer_count, (int64_t)lower, (int64_t)upper, (int64_t)upper-lower+1);
////        upper = lower+buffer_count-1;
////    }
//
//    #undef nullslice
//    
//    /** Success! */
//    return (struct loop_range){ ._step = step, ._lower = lower, ._upper = upper };
//}

@end
