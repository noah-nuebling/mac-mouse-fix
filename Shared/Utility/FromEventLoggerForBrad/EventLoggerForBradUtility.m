//
//  EventLoggerForBradUtility.m
//  EventLoggerForBrad
//
//  Created by Noah Nübling on 16.04.25.
//

#import "EventLoggerForBradUtility.h"
#import "SharedMacros.h"
#import "SharedUtility.h"


@implementation EventLoggerForBradUtility

/// Debug-printing for enums

static inline NSString *_Nonnull bitflagstring(int64_t flags, NSString *const _Nullable bitToNameMap[_Nullable], int bitToNameMapCount) {
    
    /// Build result
    NSMutableString *result = [NSMutableString string];
    
    int i = 0;
    while (1) {
        
        /// Break
        if (flags == 0) break;
        
        if ((flags & 1) != 0) { /// If `flags` contains bit `i`
            
            /// Insert separator
            if (result.length > 0) {
                [result appendString:@" | "];
            }
            
            /// Get string describing bit `i`
            NSString *bitName = safeindex(bitToNameMap, bitToNameMapCount, i, nil);
            NSString *str = (bitName && bitName.length > 0) ? bitName : stringf(@"(1 << %d)", i);
            
            /// Append
            [result appendString:str];
        }
        
        /// Increment
        flags >>= 1;
        i++;
    }
    
    /// Wrap result in ()
    result = [NSMutableString stringWithFormat:@"(%@)", result];
    
    /// Return
    return result;
}

@end
