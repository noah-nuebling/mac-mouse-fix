//
// --------------------------------------------------------------------------
// MFGate.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2025
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//


/// Usage: Thread A schedules work on thread B, then waits until the work is completed. [Sep 2026]
/// Behavior: Can deadlock. Should be able to avoid that architecturally after 'No more dispatch queues' refactor  since we only have 2 threads - main and GlobalEventTapThread [Sep 2026]
///     Extension idea: If we ever do need a timeout to catch deadlocks, we gotta either just crash (restarting the Helper), or return `Running` or `Canceled` state from the timed-out wait, so the caller can correctly recover. (We'd then also need to wrap thread B's work in a closure and pass it to the MFGate to ensure correct locking) [Sep 2026]
///
/// Note: Maybe we should implement this using `dispatch_semaphore` or POSIX semaphores (`sem_init()`) instead of `NSCondition`? Probably a bit faster.

#import "MFGate.h"

@implementation MFGate {
    NSCondition *_condition;
    bool _open;
};

- (instancetype) init {
    if (!(self = [super init])) return nil;
    _condition = [NSCondition new];
    _open = 0;
    return self;
}

- (void) waitForWork {
    /// Make thread A wait for the work to be completed

    [_condition lock]; {
        while (!_open) [_condition wait];
    } [_condition unlock];
}
- (void) signalWorkCompleted {
    /// Called by thread B after it has finished its work

    [_condition lock]; {
        _open = 1;
        [_condition signal];
    } [_condition unlock];
}

@end
