//
//  MFObserverTests.m
//  objc_tests
//
//  Created by Noah Nübling on 14.04.25.
//

#pragma mark - Cleanup tests

///
/// Test results [Apr 2025]
///     Tested under macOS 15.4 (24E248) [Apr 2025]
///     Everything seems to work as expected!
///     Observers as well as observations get cleaned up, regardless of whether the observation is invalidated due to the observee being deallocated, or by manual cancellation of the observation.
///     This works even though the observee (`TestObject_KVORuleBreaker` instance) breaks the condition under which KVO automatically cleans up observations, which are described in the macOS 10.13 release notes. (See src [1])
///         -> Based on that, it seems that newer macOS versions (probably macOS 11+) have removed these restrictions on KVO's auto-cleanup entirely.
///             This is also supported by this quote from the macOS 11 release notes (See src [1]):
///                 > Instances of NSKeyValueObservation, produced by the Swift `NSObject.observe(_:changeHandler:)` method, take
///                 > advantage of integration with this bookkeeping so they now invalidate automatically when the observed object is released, **regardless of how the object implements its KVO behavior.**
///         - For earlier macOS versions, the cleanup may not work at all or under certain conditions, which could produce crashes and leaks (See src [1], and the 'detailed thoughts' below.)
///
/// Detailed thoughts on supporting older macOS versions:
///     - What exactly do we know about KVO auto-cleanup in different macOS versions?
///         Knowledge: Our tests tell us that in 15.4, it works in all cases we tested, and at least one of the 2 edge cases (src [1]) that the 10.13 release notes warned about, *do* work now. (Didn't test the other one, cause I didn't understand it.)
///         Speculation: Based on the tests and src [1], my interpretation is that KVO auto-cleanup, was introduced in macOS 10.13 – where it would apply in all except certain edge-cases – and then improved in macOS 11, where it started to apply in all cases. I haven't found anything pointing to the behavior changing between macOS 11 and macOS 15.4 (which we tested.)
///
///     - Could we make things work, even if KVO doesn't clean up on observee dealloc?
///         (This should only be necessary pre-macOS 11. Since MMF only offically supports macOS 11+, we shouldn't waste any more time on this.)
///
///         - This would pose a significant challenge because we'd have to hook into the -dealloc method of the observee. (We tried to do this in `DeallocTracker.m`)
///             - We architected things such that the observee retains the observer. If we'd done it the other way around, this would be simpler, since we'd only have to hook into the -dealloc method of the observer (whose code we control) (That's because the observee would never get -dealloc'd before the observer, which retains it.)
///                 But even then, I'm not sure things would be safe, since I don't know what the order of operations is during object-deallocation. (IIRC I researched this at some point and couldn't find anything)
///             - I'm not sure the DeallocTracker is safe, or would cause the observation to be removed too late (See below – observation must perhaps be removed *before* -dealloc is called....)
///         - I even heard that removal of observation has to happen *before*, not while, dealloc is called, to prevent crashes (See comments on src [1])
///             - In this case, I think it might be impossible to safely tie the removal of the observation to the lifecyle of the observer/observee at all. (Which is one of the main goals of `MFObserver.m`)
///             - However, since Swift has `observe(_:options:changeHandler:)`, (which I think was introduced in 10.10, before the auto-observation cleanup of 10.13 – but there's not doc page for it so I'm not sure) does something very similar to this, I feel like it should be possible to make this safe. But I'm unsure.
///                 - Src [1] also mentions how, since macOS 11, the Swift implementation 'integrates with the KVO bookkeeping' to 'invalidate automatically when the observed object is released'. I don't know if that means there's some private 'bookkeeping' APIs it interacts with. I did some very minimal assembly-stepping but couldn't find anything special. But based on the KVO cleanup tests we did, It sounds like we could pretty easily replicate this behavior by simply declaring the observer 'invalid' when the weak observer->observee ptr is nil (?)
///         - Memory-leak problem: If we try to hook into observee dealloc, and we have a weak ptr to the observee, this ptr would already be nil'ed out in our hook, making it so we can't successfully call KVO's `removeObserver:` method. So we'd have to use an unmanaged pointer to the observee instead.
///
///     Idea: Maybe it's ok to keep the observation around a bit longer than the observee?
///          I don't even know why it's such a problem. (I just read about crashes and stuff in src [1] but I didn't fully understand.)
///              Even if the observationCallback is called while the observee is deallocating, that should only be dangerous, if we access some invalid data from the callback – right?
///              We could even use the weak observer->observee ptr to check if the observee is currently _being_ deallocated. (In that case the weakptr would be nil) and then just return from the callback ... But I don't understand this stuff deeply enough to know if it's safe.
///                  Also, I assume that with the improved KVO auto-cleanup indroduced in macOS 11, it would take care of any such problems anyways.
///
/// Other thoughts/mental model:
///     - It makes sense that observee dealloc would auto-cancel the observation, since observees hold references to all their observations inside -[NSObject observationInfo] (Tested [Apr 2025], macOS 15.4)
///     - Observers don't have a standardized way of referencing the observations they are involved in AFAIK, but that's ok since we control the observer's code directly, so we can just manually cancel the observation.
///
/// Sources:
///     [1] SO Answer by Rob Mayoff: https://stackoverflow.com/a/18065286/10601702
///     [2] Apple Developer Forums – is there documentation for `observe(_:options:changeHandler:)`? https://developer.apple.com/forums/thread/768796

#import "MFObserverTests.h"
#import "MFObserver.h"

/// Create KVORuleBreaker object
/// The 'rule' that this breaks is that it returns NO from `+automaticallyNotifiesObserversForKey:` [Apr 2025]
///     The macOS 10.13 release notes say that this turns off KVO's auto-cleanup (src [1])
///     The macOS 10.13 release notes also say that KVO's auto-cleanup is turned off if "the (private) accessors for internal KVO state are overriden" . But I'm not sure what this means or how to test for it.

@interface TestObject_KVORuleAdherer: NSObject
    @property (nonatomic, assign, readwrite) NSInteger theValue;
@end
@implementation TestObject_KVORuleAdherer @end

@interface TestObject_KVORuleBreaker: NSObject
    @property (nonatomic, assign, readwrite) NSInteger theValue;
@end
@implementation TestObject_KVORuleBreaker
    @synthesize theValue=_theValue;

    + (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key { return NO; }

    - (void)setTheValue:(NSInteger)theValue {
        [self willChangeValueForKey:@"theValue"];
        self->_theValue = theValue;
        [self didChangeValueForKey:@"theValue"];
    }
    - (NSInteger)theValue {
        return self->_theValue;
    }
@end
        
static CFDictionaryRef _MFKVO_GlobalObservationInfoDict(void) {
    /// Get global dict holding all KVO observations
    ///     -> Lets us check whether observations get cleaned up correctly.
    ///     Based on `[NSObject observationInfo]` disassembly from [Apr 13 2025]
    ///         ```
    ///         0x18e029e50 <+0>:  adrp   x8, 449382
    ///         0x18e029e54 <+4>:  ldr    x8, [x8, #0x488]
    ///         0x18e029e58 <+8>:  cbz    x8, 0x18e029e68           ; <+24>
    ///         0x18e029e5c <+12>: mvn    x1, x0
    ///         0x18e029e60 <+16>: mov    x0, x8
    ///         0x18e029e64 <+20>: b      0x18ea1cba8               ; symbol stub for: CFDictionaryGetValue
    ///         0x18e029e68 <+24>: mov    x0, #0x0                  ; =0
    ///         0x18e029e6c <+28>: ret
    ///         ```

    if ((0)) { /// Call [NSObject observationInfo] so we can reverse engineer it
        void *info = [[[NSObject alloc] init] observationInfo];
    }
    
    /// adrp instruction
    void *globalptr = (void *)0x0000000203e53000; /// Just hardcoding the result of the adrp instruction. (Cause I can't figure out how to emulate the adrp instruction) Seems to change after computer sleeps. (Writing this on 15.4 (24E248))
    /// ldr instruction
    CFDictionaryRef dictionary = *(CFDictionaryRef *)(globalptr + 0x488);
    return dictionary;
    
}

void mfobserver_cleanup_tests(void) {

    #define _mflog(msg...) NSLog(@"MFObserver.m: LoadTests: " msg)
    
    #define __observer_storage __weak /*__strong*/ /// The tests seems to work as expected with strong and weak storage.
    
    ///
    /// Observee lifecycle-driven cleanup
    ///
    
    #define mflog(msg...) _mflog("observee cleanup: " msg)
    ({
        MFObserver *__observer_storage observer;
        ({
            @autoreleasepool {
                __auto_type testObject = [[TestObject_KVORuleBreaker alloc] init];
                
                observer = [testObject mf_observe:@"theValue" block:^(id  _Nonnull newValueNS) {
                    NSInteger newValue = unboxNSValue(NSInteger, newValueNS);
                    mflog("theValue changed to: %ld", newValue);
                }];
                
                testObject.theValue = 1;
                testObject.theValue = 2;
                testObject.theValue = 3;
                
                mflog("in scope - observer: %@, isactive: %d, observations: %@",
                    observer,
                    [observer _isActive],
                    CFAutorelease(CFCopyDescription(_MFKVO_GlobalObservationInfoDict())));
            }
        });
        mflog("post scope - observer: %@, isactive: %d, observations: %@",        observer, [observer _isActive], CFAutorelease(CFCopyDescription(_MFKVO_GlobalObservationInfoDict())));
    });
    
    ///
    /// Cancel-driven cleanup
    ///
    #undef mflog
    #define mflog(msg...) _mflog("cancellation cleanup: " msg)
    ({
        __auto_type testObject = [[TestObject_KVORuleBreaker alloc] init];
        
        MFObserver *__observer_storage observer = [testObject mf_observe:@"theValue" block:^(id  _Nonnull newValueNS) {
            NSInteger newValue = unboxNSValue(NSInteger, newValueNS);
            mflog("theValue changed to: %ld", newValue);
        }];
        
        testObject.theValue = 1;
        testObject.theValue = 2;
        testObject.theValue = 3;
        
        mflog("pre cancellation - observer: %@, isactive: %d, observations: %@", observer, [observer _isActive], CFAutorelease(CFCopyDescription(_MFKVO_GlobalObservationInfoDict())));
        [observer cancel];
        mflog("post cancellation - observer: %@, isactive: %d, observations: %@", observer, [observer _isActive], CFAutorelease(CFCopyDescription(_MFKVO_GlobalObservationInfoDict())));
        
        testObject.theValue = 4; /// There should be no callback for this one.
    });
}
