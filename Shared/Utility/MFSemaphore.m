//
// --------------------------------------------------------------------------
// MFSemaphore.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2025
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// Traditional counting semaphore
///     See this Wikipedia Article: https://en.wikipedia.org/wiki/Semaphore_(programming)
///
/// Note: Maybe we should implement this using `dispatch_semaphore` or POSIX semaphores (`sem_init()`) instead of `NSCondition`? Probably a bit faster.

#import "MFSemaphore.h"

@implementation MFSemaphore {
    int _freeUnits;
    NSCondition *_condition;
};

- (instancetype) initWithUnits: (int)nOfUnits {
    self = [super init];
    if (!self) return nil;
    _freeUnits = nOfUnits;
    _condition = [[NSCondition alloc] init];
    return self;
}

- (bool) acquireUnit: (NSDate *_Nullable)timeLimit {
    
    [_condition lock];
    _freeUnits--; /// Claim a unit
    bool didTimeOut = false;
    while (_freeUnits < 0) { /// Wait if the claimed unit is not available. (aka, while `_freeUnits` is negative) || Nice property: If `_freeUnits < 0`, then `abs(_freeUnits)` is the number of threads waiting for a unit.
        if (!timeLimit)
            [_condition wait];
        else {
            didTimeOut = ![_condition waitUntilDate: timeLimit];
            if (didTimeOut) break;
            /// Note: Other implementations increment `_freeUnits` on timeout. We don't. With our implementation, the caller must simply make sure that `acquireUnit:` and `releaseUnit` invocations are balanced. (Regardless of whether `acquireUnit:` times out or not)
        }
    }
    [_condition unlock];
    
    return didTimeOut;
}
- (void) releaseUnit {
    [_condition lock];
    _freeUnits++;           /// Release a unit
    [_condition signal];    /// You can also call `broadcast` to wake up all waiters. But I don't think we need that here. (Since we're only freeing one unit?)
    [_condition unlock];
}

@end
