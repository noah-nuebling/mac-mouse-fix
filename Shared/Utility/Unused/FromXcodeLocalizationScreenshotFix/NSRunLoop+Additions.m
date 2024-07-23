//
//  NSRunLoop+Additions.m
//  CustomImplForLocalizationScreenshotTest
//
//  Created by Noah Nübling on 18.07.24.
//

#import "NSRunLoop+Additions.h"

@implementation NSRunLoop (Additions)

- (NSDictionary *)observeLoopActivities:(CFRunLoopActivity)activities withCallback:(void (^)(CFRunLoopObserverRef observer, CFRunLoopActivity activity))callback {
    
    CFRunLoopRef runLoop = self.getCFRunLoop;
    
    CFIndex priority = 0;
    Boolean repeats = true;
    CFRunLoopObserverRef runLoopObverver = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault, activities, repeats, priority, callback);
    
    NSArray *allModes = (__bridge_transfer NSArray *)CFRunLoopCopyAllModes(runLoop);
    for (NSString *mode in allModes) {
        CFRunLoopAddObserver(runLoop, runLoopObverver, (__bridge CFStringRef)mode);
    }
    
    NSDictionary *result = @{
        @"runLoop": self,
        @"modes": allModes,
        @"observer": (__bridge id)runLoopObverver,
    };
    
    CFRelease(runLoopObverver);
    
    return result;
}

- (void)stopObservingLoopActivitiesWithResultDict:(NSDictionary *)resultDict {
    
    /// Pass in the resultDict from `observeLoopActivities:`
    
    assert(false); /// Untested
    
    NSRunLoop *runLoop = resultDict[@"runLoop"];
    NSArray *modes = resultDict[@"modes"];
    CFRunLoopObserverRef observer = (__bridge CFRunLoopObserverRef)resultDict[@"observer"];
    
    assert([runLoop isEqual:self]);
    
    for (NSString *mode in modes) {
        CFRunLoopRemoveObserver(runLoop.getCFRunLoop, observer, (__bridge CFStringRef)mode);
    }
}

@end
