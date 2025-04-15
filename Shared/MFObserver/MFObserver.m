//
//  MFObserver.m
//  objc-test-july-13-2024
//
//  Created by Noah Nübling on 30.07.24.
//

#import "MFObserver.h"
#import "objc/runtime.h"
#import "CoolMacros.h"
#import "EXTScope.h"
#import "objc/objc-sync.h"


/// I think we can replace any need for reactive frameworks in our app with a very simple custom API providing a thin wrapper around Apple's Key-Value-Observation.
/// 
/// Comparison with Reactive frameworks:
///     - Key-value-observation should be extremely fast, since it's quite old and mature and at the core of many of Apple's libraries.
///         It should be much faster than ReactiveSwift, and perhaps even faster than Combine. Update: Combine also seems to use KVO under the hood at least when observing properties @objc objects, but it adds a lot of overhead.
///     - Most reactive features like backpressure, errors, hot & cold signals etc, are totally unnecessary for us.
///     - Any 'maps' or 'filters' or similar transforms on 'streams of values over time' we can simply do inside our observation callback block.
///         E.g. filter is just an `if (xyz) return;` statement. compactMap is just `if (newValue == nil) return;`
///     - We can do scheduling by just calling functions like `dispatch_async()` inside the callback block.
///     - As far as I can think of, the only useful thing for MMF  in Reactive frameworks that goes beyond this basic API would be debouncing,
///             but even that we could replace by adding an NSTimer and 3 lines of code inside an observation callback block.
///     - Basically all properties or other values assigned to any NSObject (even NSDictionary) should be observable with KVO - and by extension our MFObserver API.
///         (KVO works on any setters that use the `setValue:` naming scheming afaik) (Update: with our KVOMutationSupport.m code it even works for mutations on types like NSMutableString!)
///
///     -> Overall this should provide a very performant, simple and modular interface for doing everything we want to do with a Reactive framework.
///
/// Also see:
///     - KVOBasics: https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/KeyValueObserving/Articles/KVOBasics.html
///     - Key Value Coding Programming Guide: https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/KeyValueCoding/index.html#//apple_ref/doc/uid/10000107-SW1
///
/// Benchmarks:
///     Just ran benchmarks on kvo wrapper and this is 3.5x - 5.0x (Update: 4.5x - 6x after optimizations) faster than Combine!! And combine can already be around 2x as fast as ReactiveSwift and 1.5x as fast as RxSwift according to benchmarks I found on GitHub. So this should outperform the Reactive framework we're currently using by several factors, while offering an imo nicer interface, which is great!
///
///     However, I also tested against a 'primitive' implementation in swift and objc that replaces observation with manual invokations of the callback block whenever the underlying value changes, and the difference is staggering! The 'primitive' Swift implementation is 134x faster than our kvo wrapper for a simple example and 929x (!!) faster than our kvo wrapper for the 'combineLatest' logic. (And combine is another factor 5x - 10x slower)
///
///     The checksums all matched, so they computed the same thing and we built with optimizations.
///
///     Here's one of test run outputs:
///     ------------------
///     MFObserver Bench:
///     ------------------
///     Running simple tests with 10000000 iterations...
///     Combine time: 45.459512
///     kvo time: 9.590202
///     primitive objc time: 0.302365
///     primitive swift time: 0.071346
///     swift is **4.23x** faster than objc. objc is **31.71x** faster than kvo. kvo is **4.74x** faster than Combine
///     Running combineLatest tests with 2500000 iterations....
///     Combine time: 54.844566
///     kvo time: 14.305337
///     primitive objc time: 0.059409
///     primitive swift time: 0.015361
///     swift is **3.86x** faster than objc. objc is **240.79x** faster than kvo. kvo is **3.83x** faster than Combine
///     Program ended with exit code: 0
///
///     Caveat:
///         - These bad Combine results were for using the `someObject.publisher(for:<keyPath>)` API which is actually a wrapper for KVO. When using the more swift-native `@Published` macro, Combine is almost as fast as our implementation:
///         -> Based on one test, ours is only  1.14x faster than Combine for the basic observation and 1.08x faster for the combineLatest observation when using `@Published` in Combine.
///
/// Technical details:
///     On thread safety and use of `@synchronized`:
///         We use `@synchronized(observedObject)`in 2 places and `objc_sync_enter` in 1 place inside this implementation to ensure thread-safety. All functions and methods exposed through the interface should be thread safe.
///         Generally, when making things thread-safe I was thinking about:
///             What are the shared mutable resources, and how can we ensure that when they are being mutated, nothing else is accessing or trying to mutate them at the same time. It also helps to think about the big-picture control flow - we don't need to do finegrained locking and unlocking everywhere, if we can just ensure that, when the control flow enters Observe.m, then, before any shared state encapsulated by Observe.m is mutated or read, a lock is always acquired - then we're good! Since the control flow and interface for Obseve.m is relatively simple, that makes things relatively managable. Deadlocks can be avoided by ensuring that you never try to acquire another lock while you already hold a lock. (so you probably shouldn't invoke a callback with foreign code while holding your lock, since it might try to acquire further locks).
///
/// Conclusion: Should we use this?
///     - This adds a light "reactive style" convenience interface on top of kvo.
///     - It's available in objc which I like writing more than swift.
///     - It's usually slightly faster than combine but in the same ballpark.  For performance critical things, you'd still want to use simple function calls since they are much faster, and for UI stuff the performance difference doesn't matter.
///         - Actually, when using Combine as a wrapper for kvo, using `someObject.publisher(for:<keyPath>)`, then Combine is around 3-6x slower than our code in our tests, but for UI Stuff this still probably doesn't matter.
///         - Using swift's more lower-level wrapper around KVO `observe(_:options:changeHandler:)` is also much much slower in our tests.
///     - I wrote it and control it so I might understand how to use it better.
///     - I have a general dislike for Swift. But I should be pragmatic. It's a useful too.
///     - The build times for MMF 3 are quite slow. And I suspect that swift is a big factor in that.
///         > I might want to move away from Swift and write more of the UI Stuff in objc. And this might enable that. Some of the main reasons we use so much swift is that we wanted to use reactive patterns for the UI of MMF, which lead us to include the ReactiveSwift framework and build much of the UI code in Swift. MMF 2 which was pure objc iirc, had much faster build times iirc.
///     - BIG CON: This needs to be thread safe. I tried but thread safety is hard. If there are subtle bugs in this, we might make the app less stable vs using an established framework or API.
///         Update: I thought about it again and I'm pretty confident this is thread safe now. There are only a small number of paths through which the control flow can enter the core logic of this file:
///             `mfobs_add_observer()`, `mfobs_cancel_observer()`, `[MFObserver dealloc]`, `observeValueForKeyPath:ofObject:change:context:`, and the callback inside `mfobs_observe_latest_values()`. If we ensure that all these entry points are thread-safe, which we did, then entire file should be thread safe to use. Maybe I missed something but I think it's not too bad to make this thread safe after all.
///
///     -> Overall this was a cool experiment. It was fun and I learned a bunch of things. Maybe we can adopt this into MMF at some point, but we should probably only adopt it for a new major release where we can thoroughly test this before rolling it out to non-beta users.
///
///     Other takeaways:
///         - Due to the Benchmarks we made for this I saw that, for simple arithmetic and function calling, pure swift seems to be around 4 - 6x faster than our pure C code!! That's incredible and very unexpected.
///             Unfortunately, when you use frameworks or higher level datatypes with Swift, and interoperate with objc, that can sometimes slow things down a lot in unpredictable ways. (See the whole `SWIFT_UNBRIDGED` hassle in MMF., or Combine being 6x slower when used with KVO) Objc/C and its frameworks seem more predictable and consistent to me. But for really low level routines or if you use it right, swift can actually be incredibly fast, which is cool and good to know, and makes me like the language a bit more.
///
///     Update: [Apr 2025]
///         After working on/thinking through the code again, and writing some tests confirming the memory management works as expected, I'm very confident that this is production-ready.
///         This API is probably the best tradeoff between performance and convenience out of any available observation APIs for Swift/objc.
///         I'm still not sure if this was a massive waste of time though, because the increased performance may not ever matter, and it's not really more convenient or powerful than the alternatives.
///             Currently, in MMF, we're using ReactiveSwift, which is probably a bit more convenient, but likely slower (src [3], haven't tested) and also probably increases bundle size and build-times somewhat.
///             But still, moving over from ReactiveSwift is probably a waste of time.
///
/// Technical discussion: `Lifetime-management`: [Apr 2025]
///     Terminology:
///         observee         -> observed object
///         observer          -> MFObserver instance observing the object
///         observation     -> The record that the KVO machinery stores about the observer <-> observee connection (See `-[NSObject observationInfo]`)
///     Goals:
///         - We want to automatically manage the lifetime of the **observation**, such that
///             the observation is created, when the observer is created
///             the observation is removed, when the observer is 'canceled' by the user, or when either the observer or the observee is deallocated.
///         - We want to automatically manage the lifetime of the **observer**, such that
///             the observer is created when the the user starts observing a keypath on an object
///             the observer is kept alive by the observee, which holds a reference to it. This reference is removed if the observer is 'canceled' or the observee is deallocated. If there are additional, external references to the observer, it could outlive the observee.
///         - We are not trying to manage/change the lifetime of the **observee**. We avoid any owning references to it, to avoid retain-cycles.
///     Problem:
///         The tricky part here is trying to remove the observation upon deallocation of observer/observee. Some sources say (Comments on src [1]) that removing the observation inside a -dealloc method is too late and can cause crashes.
///         Think-through: (... the cases where observer/observee gets deallocated, and we wanna remove the observation in their -dealloc methods)
///             There are two cases:
///                 1. observee is dealloc'd *before* the observer        (~observee > ~observer)
///                 2. observee is dealloc'd *after*    the observer        (~observer > ~observee)
///                 Let's think about what we need to do when the *observer* (whose code we control) is deallocated in these 2 cases:
///                     1.  (~observee > ~observer)
///                         - In this case, we don't need to do anything, because the observation is automatically removed by KVO when the observee was dealloc'd (Tested and confirmed this, see below)
///                     2. (~observer > ~observee)
///                         - In this case, we *also* don't need to do anything because this can only happen, if the observer was already manually 'canceled' (which removed the observation). If the observer wasn't canceled, the observer is retained by the observee, preventing its deallocation.
///                 -> Therefore, we don't ever have to remove the observation inside of a -dealloc method – which means we're safe from those weird crashes that src [1] warned us about.
///     Tests:
///         Tested and confirmed that observation is automatically removed by KVO when observee is deallocated. See `MFObserverTests.m`.
///             - (I have reason to believe that this only works on macOS 11+, and that older versions could experience leaks or crashes in some situations. See the comments by the tests.)
///
/// Update:
///     I just spent a while trying to move MMF to using this, and it's quite a lot of work, definitely a few-days refactor. Also, questionable whether combine would be a better choice than this (Combine API might be a bit shorter / cleaner, and easier to translate from ReactiveSwift, and we'd still be removing a library dependency which should speed up builds. It would be sort of nice to move the UI code away from swift to further improve build times but that would be way too much work! We're stuck with Swift for now.
///
/// Update: [Apr 2025]
///     - This is sort of a reimplementation of Swift's `observe(_:options:changeHandler:)`, but that only supports Swift keypaths which are super annoying IIRC.
///         - I'm not sure about the ownership semantics of `observe(_:options:changeHandler:)` (I doesn't have a documentation page.) – Our implementation has the observee retain the observer.
///
/// Sources:
///     [1] SO Answer by Rob Mayoff: https://stackoverflow.com/a/18065286/10601702
///     [2] Apple Developer Forums – is there documentation for `observe(_:options:changeHandler:)`? https://developer.apple.com/forums/thread/768796
///     [3] GitHub Issue about bad performance of ReactiveSwift compared to Rx and Combine: https://github.com/ReactiveCocoa/ReactiveSwift/issues/751

#pragma mark - Constants
/// Define context
///     Kind of unncecessary. The context in the KVO framework is designed for when a superclass also observes the same keyPath on the same object and that can't happen here.
static void *_MFObserverKVOContext = "MFObserverContext";

#pragma mark - MFObserver class
/// [Apr 2025] We try to put as little into this as possible and as much as possible in the `Core C "Glue Code"` below – I think that makes things clearer.

@interface MFObserver ()
@end

@implementation MFObserver {
    
    /// Immutables
    ///     These shouldn't change after initialization
    /// Notes:
    /// - Retain cycles will occur if `callbackBlock` captures the observed object. This clients need to use weak/strong dance to avoid. (Use @weakify and @strongify)
    /// - weakObservedObject being weak actually makes this noticable slower since we always need to unwrap it and check for nil
    @public NSObject                    *__weak _weakObservedObject;   /// Making the ivars public bc I just learned that that's possible. Not sure why we're using ivars vs properties. I guess speed?
    @public NSString                    *_observedKeyPath;
    @public NSKeyValueObservingOptions  _observingOptions;
    @public id                          _callbackBlock;
    
    /// Mutables
    @public int                         _observationCount;              /// This state mostly exists to validate that we're producing balanced calls to the add/remove methods.
}

- (void)observeValueForKeyPath:(NSString *_Nullable)keyPath ofObject:(id _Nullable)object change:(NSDictionary *_Nullable)change context:(void *_Nullable)context {
        
    /// Handle KVO callback
        
    /// Thread safe
    ///     As we're not interacting with any shared mutable state.
    
    /// This function is called when the observed value changes.
    
    /// Guard context
    if (context != _MFObserverKVOContext) {
        assert(false); /// [Apr 2025] Don't think this can happen? I guess if MFObserver is subclassed?
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }
    
    /// Parse options
    BOOL receivesOldAndNewValues =  (self->_observingOptions & NSKeyValueObservingOptionNew)  &&
                                    (self->_observingOptions & NSKeyValueObservingOptionOld)  ;
    /// Extract new and old values
    NSObject *_Nullable newValue = change[NSKeyValueChangeNewKey];
    NSObject *_Nullable oldValue = receivesOldAndNewValues ? change[NSKeyValueChangeOldKey] : nil;
    
    /// Validate
#if DEBUG
    
    /// Validate options
    assert(self->_observingOptions & NSKeyValueObservingOptionNew);
    
    /// Handle change-kind
    NSKeyValueChange changeKind = [change[NSKeyValueChangeKindKey] unsignedIntegerValue];
    assert(changeKind == NSKeyValueChangeSetting); /// We just handle values being set directly - none of the array and set observation stuff.
    
    /// Handle indexes
    NSIndexSet *changedIndexes = change[NSKeyValueChangeIndexesKey];
    assert(changedIndexes == nil); /// We don't know how to handle the array and set observation stuff
    
    /// Handle prior values
    BOOL isPrior = [change[NSKeyValueChangeNotificationIsPriorKey] boolValue];
    assert(!isPrior); /// We don't handle prior-value-observation (getting a callback *before* the value changes)
    
    /// Validate changed value
    if (!receivesOldAndNewValues) {
        assert(oldValue == nil);
    }
    assert(newValue != nil);
    
#endif
    
    /// Send callback.
    if (receivesOldAndNewValues)    ((MFObserver_CallbackBlock_OldAndNew)self->_callbackBlock)(oldValue, (id)newValue);
    else                            ((MFObserver_CallbackBlock_New)self->_callbackBlock)((id)newValue);
    
}

static void mfobs_cancel_observer(MFObserver *_Nonnull mfobserver); /// Forward-declaration

- (void)dealloc {
    if ((0)) /// Not necessary – see our discussion on `Lifetime-management` at the top of the file [Apr 2025]
        mfobs_cancel_observer(self); /// Thread-safe
}

@end

#pragma mark - Core C Glue Code

/// Should be thread safe
///     and therefore all the interface functions below should also be threadsafe since they are just wrappers around this.

static NSMutableSet *_Nonnull mfobs__get_observers(NSObject *_Nonnull observableObject) {
    
    /// Not thread safe
    ///     -> Only call when synced on `observableObject`
    /// Retrieve the MFObservers observing an object.
    
    static const char *key = "MFObservers";
    
    NSMutableSet *_Nullable result = objc_getAssociatedObject(observableObject, key);
    if (result) return (id)result;

    result = [NSMutableSet set];
    objc_setAssociatedObject(observableObject, key, result, OBJC_ASSOCIATION_RETAIN_NONATOMIC); /// Nonatomic since we're already synchronizing.
    
    return (id)result;
}

static BOOL mfobs_observer_is_active(MFObserver *_Nullable observer) {
    /// [Apr 2025] Not thread safe
    ///     -> in the sense that it might give slightly outdated/premature result when called during state-transitions.
    /// - This is currently only used for debugging and the slight race-conditions don't matter.
    /// - If the caller needs this to be absolutely thread-safe they can perhaps wrap calling this (and using its result) with `@synchronized (observableObject)`. (Since that's the lock we use for mutating state in here as of [Apr 2025])
    return  observer                                &&
            observer->_observationCount > 0         &&
            (observer->_weakObservedObject != nil   );
}

static MFObserver *_Nonnull mfobs_add_observer(NSObject *_Nonnull observableObject, NSString *keyPath, BOOL receiveInitialValue, BOOL receiveOldAndNewValues, MFObserver_CallbackBlock _Nonnull callback) {
    
    /// Thread safe
    
    @synchronized (observableObject) {
        
        /// Create & init mfobserver
        MFObserver *_Nonnull mfobserver = [[MFObserver alloc] init];
        ({
            /// Set up options
            NSKeyValueObservingOptions options = 0;
            options |= NSKeyValueObservingOptionNew;
            options |= (receiveOldAndNewValues ? NSKeyValueObservingOptionOld      : 0);
            options |= (receiveInitialValue    ? NSKeyValueObservingOptionInitial  : 0);
            
            /// Store args
            mfobserver->_weakObservedObject  = observableObject;
            mfobserver->_observedKeyPath     = keyPath;
            mfobserver->_observingOptions    = options;
            mfobserver->_callbackBlock       = callback;
            
            /// Init other state
            mfobserver->_observationCount = 1;
        });
        
        /// Add mfobserver to object
        ///     Now it is retained and the client won't have to retain it for the observation to stay active.
        ///     Thread-safety: [Apr 2025] This definitely has to be locked to be safe. I'm not sure the other stuff has to be locked.
        [mfobs__get_observers(observableObject) addObject:mfobserver];
        
        /// Start the mfobserver
        [observableObject addObserver:mfobserver forKeyPath:mfobserver->_observedKeyPath options:mfobserver->_observingOptions context:_MFObserverKVOContext];
        
        /// Return mfobserver
        ///     Primarily intended as a handle to let the client cancel the observation
        return mfobserver;
    }
}

static void mfobs_cancel_observer(MFObserver *_Nonnull mfobserver) {
    
    /// Thread safe
    
    /// Get & unwrap observedObject
    NSObject *strongObservedObject = mfobserver->_weakObservedObject;
    if (!strongObservedObject) return; /// If the observedObject is already nil that means its deallocated or currently deallocating, which will make KVO cancel the observation (see notes for more) [Apr 2025]
    
    @synchronized (strongObservedObject) {
        
        /// Guard multiple cancelations
        if (mfobserver->_observationCount <= 0) { return; }
        mfobserver->_observationCount -= 1;
        
        /// Remove observer
        [strongObservedObject removeObserver:mfobserver forKeyPath:mfobserver->_observedKeyPath context:_MFObserverKVOContext];
        
        /// Release the mfobserver
        ///     It should then normally be dealloced, unless its retained by an outsider.
        ///     [Apr 2025] The deallocation will cause this function to be called *again* which is a bit inefficient. Maybe we could use a recursion tracking (with `static __thread` variable) to speed that up?
        [mfobs__get_observers(strongObservedObject) removeObject:mfobserver];
    }
}

static void mfobs_cancel_observers(NSArray<MFObserver *> *_Nonnull mfobservers) {
    
    /// Thread safe
    
    for (MFObserver *observer in mfobservers) {
        mfobs_cancel_observer(observer);
    }
}

#pragma mark - Main Interface

/// This is a pure wrapper around the `Core C Glue Code` functions defined above.
///     Since that is thread safe, this should also be thread safe.
///
///     Interfaces return nil, only if passed nil (which can only happen from objc) – This way interface should be safe from both objc and Swift – See top of file for more.
///     The `Core C Glue Code` actually adheres to nullability, and never expects to receive nil, if args are declared `_Nonnull`

@implementation NSObject (MFBlockObservationInterface)

- (MFObserver *_Nonnull)mf_observe:(NSString *_Nonnull)keyPath block:(MFObserver_CallbackBlock_New _Nonnull)callbackBlock {
    BOOL receiveInitialValue = YES;
    BOOL receiveOldAndNewValues = NO;
    return mfobs_add_observer(self, keyPath, receiveInitialValue, receiveOldAndNewValues, callbackBlock);
}

- (MFObserver *_Nonnull)mf_observe:(NSString *_Nonnull)keyPath immediate:(BOOL)receiveInitialValue withOld:(BOOL)receiveOldAndNewValues block:(MFObserver_CallbackBlock _Nonnull)callbackBlock {
    /// Null-safety
    if (!keyPath.length) return (id)nil;
    if (!callbackBlock) return (id)nil;
    return mfobs_add_observer(self, keyPath, receiveInitialValue, receiveOldAndNewValues, callbackBlock);
}

@end

@implementation MFObserver (MFBlockObservationInterface)

- (void)cancel                                                          { mfobs_cancel_observer(self); }
+ (void)cancelObservers:(NSArray<MFObserver *> *_Nonnull)observers      { if (!observers) return; return mfobs_cancel_observers(observers); }

- (BOOL)_isActive                                                       { return mfobs_observer_is_active(self); }

@end

#pragma mark - ObserveLatest

#pragma mark Core implementation

static NSArray<MFObserver *> *_Nonnull mfobs_observe_latest_values(NSArray<NSObject *> *_Nonnull objects, NSArray<NSString *> *_Nonnull keyPaths, MFObserver_CallbackBlock_Latest _Nonnull callbackBlock) {
    
    /// Thread safety:
    ///     The core function we call, `mfobs_add_observer()` is thread safe, the only shared state we handle - the latestValueCache - is locked with a mutex, so thread safe.
    ///         What happens inside the callbackBlock is not our responsibility.
    ///
    /// Memory safety:
    ///     The callbackBlock will be retained by each object in `objects`. If any of them are retained/captured in the callbackBlock there's a retain cycle!
    ///     The latestValues are only referenced as weak pointers to help with preventing retain cycles. Since we don't retain them, it's the clients responsibility to make sure that the latestValues are not deallocated during observation (e.g. by retaining the observed`objects`). If an object becomes deallocated during observation, its latest value might also become deallocated, and will appear as 'nil' in the callbackBlock.
    ///
    /// Why use 9 local variables for the latestValueCache?
    ///     - Using an NSArray won't let us reference the values weakly, leading to unavoidable retain cycles in some scenarios (When one of the latest values retains one of the observedObjects)
    ///     - Using an NSPointerArray lets us reference latestValues weakly. But using it made performance measurably worse. (IIRC)
    ///     - Update: [Apr 2025] Cleaned things up by using C array instead. (Had to wrap it in struct, see below.)
    
    /// Declare convenience macros
    ///     TODO: Replace these with macros from our mac-mouse-fix utility headers
    #define arrcount(arr) \
        (sizeof(arr)/sizeof((arr)[0]))
    #define loopc(varname, count) \
        for (int64_t varname = 0; varname < count; varname++)
    
    /// Constants
    const int indexForWhichToReceiveInitialCallback = 0;
    const int nmax = 9;
    
    /// Extract
    int n = (int)objects.count;
    
    /// Validate
    assert(keyPaths.count == objects.count);
    assert(n <= nmax);
    
    /// Declare result
    NSMutableArray<MFObserver *> *observers = [NSMutableArray array];
    
    /// Create cache
    ///     Trick: wrap stack array in struct to make clang capture it in the block. (It doesn't allow capturing arrays directly for 'performance reasons' – See: https://lists.llvm.org/pipermail/cfe-dev/2013-June/030246.html)
    typedef struct { __weak id _Nullable _[nmax]; } LatestValueCache;
    __block LatestValueCache latestValueCache = {0}; /// Init all values to nil
    
    /// Init cache
    loopc(i, nmax)
        latestValueCache._[i] = (i >= n || i == indexForWhichToReceiveInitialCallback) ?
                                nil :
                                [objects[i] valueForKeyPath:keyPaths[i]];
    
    /// Create mutex token for cache access
    ///     [Apr 2025] We used `pthread_mutex` before, but I'm not sure when to clean that up, since the lock should be 'owned' by all n MFObservers.
    __block id cache_sync_token = @"the_sync_token";
    
    loopc(i, n) {
        
        /// Iterate objects
        
        /// Define params
        ///     Note: Only receive initialValue on one object, so the `callbackBlock` doesn't receive the same initial values n times.
        BOOL doReceiveInitialValue = i == indexForWhichToReceiveInitialCallback;
        BOOL receiveOldAndNewValues = NO;
        
        /// Create observer
        MFObserver *_Nonnull mfobserver = mfobs_add_observer(objects[i], keyPaths[i], doReceiveInitialValue, receiveOldAndNewValues, ^void (NSObject *newValue) {
            
            /// Note: If we capture any of the `objects` here (or in `callbackBlock`) that's a retain cycle!
            
            /// Acquire lock
            ///     On locking: [Apr 2025] I'm not 100% sure this lock is necessary, since each latestValue is stored kinda 'independently' (They each have their own address in our C-array cache.)
            objc_sync_enter(cache_sync_token);
            
            /// Update cache
            ///     On  concurrency: We want to lock cache updates and retrievals to avoid race conditions, however, we don't want to lock around the callbackBlock invocation since depending on what the callback code does it could cause deadlocks.
            latestValueCache._[i] = newValue;
        
            /// Retrieve cache
            ///     Get a local, strong ref to each cache variable while we still have the lock
            __strong id _Nonnull retrievedLatestValues[n];
            loopc(j, n) retrievedLatestValues[j] = latestValueCache._[j];
            
            /// Release lock
            ///     Note: We could invoke the callbackBlock while we still hold the lock, then we could skip the cache-retrieval step, possibly speeding things up a bit. But that could lead to deadlocks depending on what the callbackBlock code does.
            objc_sync_exit(cache_sync_token);
            
            /// Call the callback
            #define getCache(__index) \
                retrievedLatestValues[__index]
            if      (n == 2) ((MFObserver_CallbackBlock_Latest2)callbackBlock)((int)i, getCache(0), getCache(1));
            else if (n == 3) ((MFObserver_CallbackBlock_Latest3)callbackBlock)((int)i, getCache(0), getCache(1), getCache(2));
            else if (n == 4) ((MFObserver_CallbackBlock_Latest4)callbackBlock)((int)i, getCache(0), getCache(1), getCache(2), getCache(3));
            else if (n == 5) ((MFObserver_CallbackBlock_Latest5)callbackBlock)((int)i, getCache(0), getCache(1), getCache(2), getCache(3), getCache(4));
            else if (n == 6) ((MFObserver_CallbackBlock_Latest6)callbackBlock)((int)i, getCache(0), getCache(1), getCache(2), getCache(3), getCache(4), getCache(5));
            else if (n == 7) ((MFObserver_CallbackBlock_Latest7)callbackBlock)((int)i, getCache(0), getCache(1), getCache(2), getCache(3), getCache(4), getCache(5), getCache(6));
            else if (n == 8) ((MFObserver_CallbackBlock_Latest8)callbackBlock)((int)i, getCache(0), getCache(1), getCache(2), getCache(3), getCache(4), getCache(5), getCache(6), getCache(7));
            else if (n == 9) ((MFObserver_CallbackBlock_Latest9)callbackBlock)((int)i, getCache(0), getCache(1), getCache(2), getCache(3), getCache(4), getCache(5), getCache(6), getCache(7), getCache(8));
            else assert(false);
            #undef getCache
        });
        
        /// Store the new observer
        [observers addObject:mfobserver];
    }
    
    /// Return
    return observers;
}

#pragma mark Interface

@implementation MFObserver (MFBlockObservationInterface_LatestValues)

+ (NSArray<MFObserver *> *_Nonnull)_observeLatest:(NSArray<NSArray *> *_Nonnull)objectsAndKeyPaths block:(MFObserver_CallbackBlock_Latest _Nonnull)callbackBlock {
    
    /// Null-safety
    ///     If caller breaks nullability, we break nullability. See notes above for more.
    if (!objectsAndKeyPaths)    return (id)nil;
    if (!callbackBlock)         return (id)nil;
    
    /// Parse input
    NSMutableArray *objects = [NSMutableArray array];
    NSMutableArray *keyPaths = [NSMutableArray array];

    for (NSArray *x in objectsAndKeyPaths) {
        
        assert(x.count == 2);
        assert([x[1] isKindOfClass:[NSString class]]); /// KeyPaths need to be strings

        [objects addObject:x[0]];
        [keyPaths addObject:x[1]];
    }
    
    /// Call core
    return mfobs_observe_latest_values(objects, keyPaths, callbackBlock);
}

+ (NSArray<MFObserver *> *_Nonnull)observeLatest2:(NSArray<NSArray *> *_Nonnull)objectsAndKeypaths block:(MFObserver_CallbackBlock_Latest2 _Nonnull)callbackBlock { assert(objectsAndKeypaths.count == 2); return [self _observeLatest:objectsAndKeypaths block:callbackBlock]; }
+ (NSArray<MFObserver *> *_Nonnull)observeLatest3:(NSArray<NSArray *> *_Nonnull)objectsAndKeypaths block:(MFObserver_CallbackBlock_Latest3 _Nonnull)callbackBlock { assert(objectsAndKeypaths.count == 3); return [self _observeLatest:objectsAndKeypaths block:callbackBlock]; }
+ (NSArray<MFObserver *> *_Nonnull)observeLatest4:(NSArray<NSArray *> *_Nonnull)objectsAndKeypaths block:(MFObserver_CallbackBlock_Latest4 _Nonnull)callbackBlock { assert(objectsAndKeypaths.count == 4); return [self _observeLatest:objectsAndKeypaths block:callbackBlock]; }
+ (NSArray<MFObserver *> *_Nonnull)observeLatest5:(NSArray<NSArray *> *_Nonnull)objectsAndKeypaths block:(MFObserver_CallbackBlock_Latest5 _Nonnull)callbackBlock { assert(objectsAndKeypaths.count == 5); return [self _observeLatest:objectsAndKeypaths block:callbackBlock]; }
+ (NSArray<MFObserver *> *_Nonnull)observeLatest6:(NSArray<NSArray *> *_Nonnull)objectsAndKeypaths block:(MFObserver_CallbackBlock_Latest6 _Nonnull)callbackBlock { assert(objectsAndKeypaths.count == 6); return [self _observeLatest:objectsAndKeypaths block:callbackBlock]; }
+ (NSArray<MFObserver *> *_Nonnull)observeLatest7:(NSArray<NSArray *> *_Nonnull)objectsAndKeypaths block:(MFObserver_CallbackBlock_Latest7 _Nonnull)callbackBlock { assert(objectsAndKeypaths.count == 7); return [self _observeLatest:objectsAndKeypaths block:callbackBlock]; }
+ (NSArray<MFObserver *> *_Nonnull)observeLatest8:(NSArray<NSArray *> *_Nonnull)objectsAndKeypaths block:(MFObserver_CallbackBlock_Latest8 _Nonnull)callbackBlock { assert(objectsAndKeypaths.count == 8); return [self _observeLatest:objectsAndKeypaths block:callbackBlock]; }
+ (NSArray<MFObserver *> *_Nonnull)observeLatest9:(NSArray<NSArray *> *_Nonnull)objectsAndKeypaths block:(MFObserver_CallbackBlock_Latest9 _Nonnull)callbackBlock { assert(objectsAndKeypaths.count == 9); return [self _observeLatest:objectsAndKeypaths block:callbackBlock]; }

@end
