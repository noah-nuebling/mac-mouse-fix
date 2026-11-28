// Created for Mac Mouse Fix by Noah Nuebling; licensed under the MMF License.
// Cleanup added for the MX Master 3 Bluetooth fork.
#import "UNIXSignals.h"
#import "LogitechButtonDiverter.h"
#import <dispatch/dispatch.h>
#import <signal.h>
#import <stdlib.h>

@implementation UNIXSignals
+ (void)load_Manual {
    static dispatch_source_t term, interrupt;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // A signal handler cannot safely call IOKit/Objective-C. Dispatch on a
        // separate queue, then serialize restoration onto the HID++ worker.
        dispatch_queue_t queue = dispatch_queue_create("mmf.logitech.exit", DISPATCH_QUEUE_SERIAL);
        signal(SIGTERM, SIG_IGN);
        signal(SIGINT, SIG_IGN);
        term = dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL, SIGTERM, 0, queue);
        interrupt = dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL, SIGINT, 0, queue);
        dispatch_block_t cleanup = ^{
            [LogitechButtonDiverter restoreNativeBehavior];
            exit(0);
        };
        dispatch_source_set_event_handler(term, cleanup);
        dispatch_source_set_event_handler(interrupt, cleanup);
        dispatch_resume(term);
        dispatch_resume(interrupt);
    });
}
@end
