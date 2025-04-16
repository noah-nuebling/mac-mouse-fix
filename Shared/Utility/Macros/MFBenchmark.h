//
//  MFBenchmark.h
//  EventLoggerForBrad
//
//  Created by Noah Nübling on 21.12.24.
//

/**
 Simple benchmarking utility
    Not sure this is actually useful... I''m obsessed with making macros at the moment.
 
 Usage example:
 
     mfbench_init(10);  // Allocate buffers for up to 10 benchmarks
     
     // Benchmark individual expressions
     NSArray *array = mfbench("array creation") @[@1, @2, @3];
     array          = mfbench("operation 1")    [array filteredArrayUsingPredicate:...];
     array          = mfbench("operation 2")    [array sortedArrayUsingComparator:...];
     
    // Benchmark multiple lines
    mfbench("complex operation") {
        NSMutableArray *result = [NSMutableArray array];
        for (id obj in array) {
            // ... complex operations
        }
    }
 
    // Get and print results
    NSArray<MFBenchResult *> *results = mfbench_results();
    NSLog(@"Benchmark results:\n%@", mfbench_format_results(results));
 
 Output example:
    ```
    Benchmark results:
    array creation    : 0.123 ms
    operation 1       : 1.456 ms
    operation 2       : 0.789 ms
    complex operation : 2.743 ms
    ```
 
 To enable benchmarking set the `MFBENCH_ENABLE` preprocessor flag to 1
 
 !! Caution !!
    break and continue keywords won't work as expected inside mfbench()
        mfbench() macro uses `_scopeins_statement_end()` which expands to a for-loop. So break and continue will jump to the end of the mfbench() scope.
    
 */

#pragma once

#import <Foundation/Foundation.h>
#import "MFDataClass.h"
#import "SharedMacros.h"

/// TODO: Add onLoad validation against `const char *` props into MFDataClass . - KVC doesn't work with them (Tried to do that here.)
///     -> **Done** in MMF master branch [Feb 2025]

MFDataClassInterface2(MFDataClassBase, MFBenchResult,   /// Note: Why not just turn this into a struct? 
                      readonly, strong, nonnull, NSString *,        label,
                      readonly, assign,        , double,            duration)

#define MFBENCH_ENABLE 0 /** Set 1 to enable benchmarks  */

#if !MFBENCH_ENABLE

    #define mfbench_init(x)
    #define mfbench(benchmark_label)                                (expression_to_benchmark)
    #define mfbench_results()                                       ((NSArray *)nil)
    
#else
    
    #define mfbench_init(max_benchmarks)                /** Creates various local variables in the current scope. TODO: Think about making these thread_local statics – That way we could benchmark inside multiple functions and aggregate the results. */ \
        int __mfbench_n = 0;                            /** Number of recorded benchmarks */ \
        int __mfbench_nmax = (max_benchmarks);          /** Benchmark buffer size */ \
        const char *__mfbench_labels[__mfbench_nmax];   /** Array holding benchmark labels */ \
        double __mfbench_ts[__mfbench_nmax*2];          /** Array holding benchmark timestamps */ \
    
    #define mfbench(benchmark_label)                                \
        _scopeins_statement_start(({                                \
            __mfbench_labels[__mfbench_n] = (benchmark_label);      \
            __mfbench_ts[__mfbench_n*2] = CACurrentMediaTime();     \
        }))                                                         \
            _scopeins_statement_end(({                                  \
                __mfbench_ts[__mfbench_n*2+1] = CACurrentMediaTime();   \
                __mfbench_n++;                                          \
            }))                                                         \
    
    #define mfbench_results()                                                                              \
    (NSMutableArray<MFBenchResult *> *)                                                                    \
    ({                                                                                                     \
        NSMutableArray<MFBenchResult *> *mfbench_results = [NSMutableArray array];                         \
        for (int i = 0; i < __mfbench_n; i++) {                                                            \
            double delta = __mfbench_ts[(i*2)+1] - __mfbench_ts[i*2];                                      \
            NSString *label = @(__mfbench_labels[i]);                                                      \
            [mfbench_results addObject: [[MFBenchResult alloc] initWith_label: label duration: delta]];    \
        }                                                                                                  \
        mfbench_results;                                                                                   \
    })

#endif

NSString *_Nullable mfbench_format_results(NSArray<MFBenchResult *> *_Nullable mfbench_results);
