//
//  MFBenchmark.m
//  EventLoggerForBrad
//
//  Created by Noah Nübling on 21.12.24.
//

#import "MFBenchmark.h"
#import "Logging.h"
#import "SharedMacros.h"

MFDataClassImplement2(MFDataClassBase, MFBenchResult,
                      readonly, strong, nonnull, NSString *,        label,
                      readonly, assign,        , double,            duration)

inline NSString *mfbench_format_results(NSArray<MFBenchResult *> *mfBenchResults) {
    
    if (!mfBenchResults || mfBenchResults.count == 0) { /// We expect this when benchmarking is disabled.
        return nil;
    }
    NSUInteger longestLabelLen = arrmax(r.label.length, for (MFBenchResult *r in mfBenchResults));
    
    if (longestLabelLen <= 0) {
        mfassert(false, @"maxLabelLength %lu is <= 0. mfbench_results: %@", longestLabelLen, mfBenchResults);
        return nil;
    }
    
    NSMutableString *result = [NSMutableString string];
    
    for range(i, mfBenchResults.count) {
        double benchTime = mfBenchResults[i].duration;
        const char *label = [mfBenchResults[i].label cStringUsingEncoding:NSUTF8StringEncoding];
        if (i != 0) [result appendString:@"\n"];
        [result appendFormat:@"  %*s: %7.3f ms", (int)longestLabelLen, label, benchTime*1000]; /// printf formatting docs here: https://regex101.com/r/lu3nWp
    }
    
    return result;
}
