//
//  DeallocTracker.m
//  objc-test-july-13-2024
//
//  Created by Noah Nübling on 02.08.24.
//

#import "DeallocTracker.h"
#import "objc/runtime.h"

/// Note: Should be thread-safe

@implementation DeallocTracker

- (void)dealloc {
    _deallocCallback(_trackedObject); /// Afaik, the `_trackedObject`will be in the process of dealloc'ing when the callback is invoked. Using some of its methods or properties would probably lead to errors! Weak ptrs to it are already nil
}

@end

static NSMutableArray *getDeallocTrackers(NSObject *object) {
        
    static const char *key = "mfDeallocTrackers";
    NSMutableArray *result = objc_getAssociatedObject(object, key);
    
    if (result != nil) {
        return result;
    }
    
    @synchronized (object) {
        /// Double-checked locking pattern, says Claude, makes sense when you think about it. Concurrency is hard.
        result = objc_getAssociatedObject(object, key);
        if (result == nil) {
            result = [NSMutableArray array];
            objc_setAssociatedObject(object, key, result, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
    
    return result;
}

static void addDeallocTracker(NSObject *object, void (^deallocCallback)(NSObject *deallocatingObject)) {
    
    /// Note:
    ///     If the deallocCallback retains `object` that's a retain cycle
    
    /// Create tracker
    DeallocTracker *newTracker = [[DeallocTracker alloc] init];
    newTracker.deallocCallback = deallocCallback;
    newTracker.trackedObject = object;
    
    /// Get trackers
    NSMutableArray *deallocTrackers = getDeallocTrackers(object);
    
    /// Add tracker
    ///     `newTracker` is retained by `object` after this step.
    ///
    /// Explanation:
    ///     When `object` is `dealloc`ed the
    ///     associated `deallocTrackers` array and all its contents are released.
    ///     Subsequently, `deallocTrackers` contents are then also all `dealloc`ed,
    ///     (as long as the contents are not retained anywhere else, which would be an error)
    ///     this will cause the `deallocCallback` of our `newTracker` (as well as all other dealloc trackers in the array) to fire.
    
    @synchronized (object) {
        [deallocTrackers addObject:newTracker];
    }

}
