//
// --------------------------------------------------------------------------
// MFEventTap.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2026
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "MFEventTap.h"
#import "Threads.h"
#import "SharedUtility.h"
#import <os/lock.h>

#pragma mark - MFEventType stuff

#if IS_HELPER | IS_MAIN_APP

NSString *MFEventTypeDescription(MFEventType type) {
    return bitflagsDescription(type, ^NSString *(uint64_t bitflag) {
        if (bitflag == kMFEventType_KeyboardModifier)   return @"KeyboardModifier";
        if (bitflag == kMFEventType_KeyPress)           return @"KeyPress";
        if (bitflag == kMFEventType_Sensor)             return @"Sensor";
        if (bitflag == kMFEventType_ScrollWheel)        return @"ScrollWheel";
        if (bitflag == kMFEventType_Experiment)         return @"Experiment";

        uint64_t buttonFlags = (bitflag >> _kMFEventType_ButtonShift) & _kMFEventType_ButtonMask;
        MFMouseButtonNumber button = __builtin_ctzll(buttonFlags) + 1;
        if (buttonFlags) return stringf(@"Button_%d", button);

        return nil;
    });
}
#endif

#if IS_HELPER

#pragma mark - General helpers

#define auto __auto_type
#define configure(it_, configuration...) ({ \
    auto it = (it_); \
    configuration; \
    it; \
})
#define range(i, n) (int i = 0; i < (n); i++)
#define reverse_range(i, n) (int i = (int)(n)-1; i >= 0; i--)

#define _DDLogDebug(x...) DDLogDebug("MFEventTap: " x)

#pragma mark - Descriptions

NSString *CGEventMaskDescription(CGEventMask eventMask) {
    return bitflagsDescription(eventMask, ^NSString * _Nonnull(uint64_t bitflag) {
        switch (bitflag) {
            case /*0*/CGEventMaskBit(NX_NULLEVENT):          return @"NULLEVENT";
            case /*1*/CGEventMaskBit(NX_LMOUSEDOWN):         return @"LMOUSEDOWN";
            case /*2*/CGEventMaskBit(NX_LMOUSEUP):           return @"LMOUSEUP";
            case /*3*/CGEventMaskBit(NX_RMOUSEDOWN):         return @"RMOUSEDOWN";
            case /*4*/CGEventMaskBit(NX_RMOUSEUP):           return @"RMOUSEUP";
            case /*5*/CGEventMaskBit(NX_MOUSEMOVED):         return @"MOUSEMOVED";
            case /*6*/CGEventMaskBit(NX_LMOUSEDRAGGED):      return @"LMOUSEDRAGGED";
            case /*7*/CGEventMaskBit(NX_RMOUSEDRAGGED):      return @"RMOUSEDRAGGED";
            case /*8*/CGEventMaskBit(NX_MOUSEENTERED):       return @"MOUSEENTERED";
            case /*9*/CGEventMaskBit(NX_MOUSEEXITED):        return @"MOUSEEXITED";
            case /*25*/CGEventMaskBit(NX_OMOUSEDOWN):        return @"OMOUSEDOWN";
            case /*26*/CGEventMaskBit(NX_OMOUSEUP):          return @"OMOUSEUP";
            case /*27*/CGEventMaskBit(NX_OMOUSEDRAGGED):     return @"OMOUSEDRAGGED";
            case /*10*/CGEventMaskBit(NX_KEYDOWN):           return @"KEYDOWN";
            case /*11*/CGEventMaskBit(NX_KEYUP):             return @"KEYUP";
            case /*12*/CGEventMaskBit(NX_FLAGSCHANGED):      return @"FLAGSCHANGED";
            case /*13*/CGEventMaskBit(NX_KITDEFINED):        return @"KITDEFINED";
            case /*14*/CGEventMaskBit(NX_SYSDEFINED):        return @"SYSDEFINED";
            case /*15*/CGEventMaskBit(NX_APPDEFINED):        return @"APPDEFINED";
            case /*22*/CGEventMaskBit(NX_SCROLLWHEELMOVED):  return @"SCROLLWHEELMOVED";
            case /*28*/CGEventMaskBit(NX_ZOOM):              return @"ZOOM";
            case /*23*/CGEventMaskBit(NX_TABLETPOINTER):     return @"TABLETPOINTER";
            case /*24*/CGEventMaskBit(NX_TABLETPROXIMITY):   return @"TABLETPROXIMITY";
            default:                                         return nil;
        }
    });
}

#pragma mark - Private helper class

@interface _MFEventTapListener : NSObject {
    @public
    MFEventListenerID    *_id;
    MFEventType           _events;
    MFEventTapCallback    _callback;
    bool                  _enabled;
} @end
@implementation _MFEventTapListener
    - (NSString *) description {
        return stringf(@"{ _id: '%@', _callback: %p, _enabled: %@, _events: %@ }", _id, _callback, @(_enabled), MFEventTypeDescription(_events));
    }
@end

#pragma mark - Main impl

@implementation MFEventTap

    #pragma mark Typedefs

    typedef enum {
        kCGTapID_Null = 0,

        kCGTapID_KeyboardModifier = 1,
        kCGTapID_KeyPress,

        kCGTapID_Sensor,
        kCGTapID_ScrollWheel,
        kCGTapID_Experiment,

        kCGTapID_PrimaryMouseButton,
        kCGTapID_SecondaryMouseButton,
        kCGTapID_OtherMouseButton,

        kCGTapID_Max,
    } CGTapID;

    static NSString *CGTapIDDescription(CGTapID tapID) {
        switch (tapID) {
            case kCGTapID_Null:                     return @"Null";
            case kCGTapID_KeyboardModifier:         return @"KeyboardModifier";
            case kCGTapID_KeyPress:                 return @"KeyPress";
            case kCGTapID_Sensor:                   return @"Sensor";
            case kCGTapID_ScrollWheel:              return @"ScrollWheel";
            case kCGTapID_Experiment:               return @"Experiment";
            case kCGTapID_PrimaryMouseButton:       return @"PrimaryMouseButton";
            case kCGTapID_SecondaryMouseButton:     return @"SecondaryMouseButton";
            case kCGTapID_OtherMouseButton:         return @"OtherMouseButton";
            case kCGTapID_Max:                      return @"Max";
            default:                                return stringf(@"%d", tapID);
        }
    }

    typedef struct {
        /// Static
        CGEventTapOptions options;
        CGEventMask mask;

        /// Lazy / runtime
        CFMachPortRef tap;

        /// State
        bool enabled;
    } CGTapData;

    NSString *CGTapDataDescription(CGTapData cgTapData[]) {
        NSMutableString *result = [NSMutableString new];
        [result appendString: @"{\n"];
        for range(i, kCGTapID_Max) if (i)
            [result appendFormat: @"    %@: { options: %d, tap: %p, enabled: %d, mask: %@ }\n", [CGTapIDDescription(i) stringByPaddingToLength: 21 withString: @" " startingAtIndex: 0], cgTapData[i].options, cgTapData[i].tap, cgTapData[i].enabled, CGEventMaskDescription(cgTapData[i].mask)];
        [result appendString: @"}"];
        return result;
    }

    #pragma mark State

    static NSMutableDictionary<NSString *, _MFEventTapListener *> *_listenerMap = nil;
    static NSMutableArray<_MFEventTapListener *> *_listenerList = nil;                  /// For consistent ordering when iterating over the listeners, which I'm not sure NSMutableDictionary provides. (I guess ordering is good so bugs are deterministic?) [Oct 2026]
    static CGTapData _cgTapData[] = {
        [kCGTapID_Null] = {}, /// This entry enables null-coalescing [Oct 2026]

        [kCGTapID_KeyboardModifier] = { .options = kCGEventTapOptionListenOnly, .mask = CGEventMaskBit(kCGEventFlagsChanged), },
        [kCGTapID_KeyPress] = { .options = kCGEventTapOptionDefault, .mask = CGEventMaskBit(kCGEventKeyDown) | CGEventMaskBit(NX_SYSDEFINED), },

        [kCGTapID_Sensor] = {
            .options = kCGEventTapOptionDefault,                ///< Older comment from ModifiedDrag.m [Oct 2026]: Using `Default` causes weird cursor jumping issues when clicking-dragging-and-holding during addMode. Not sure why that happens. This didn't happen in v2 while using `Default`. Not sure if `ListenOnly` has any disadvantages. Edit: In other places, I've had issues using listenOnly because it messes up the timestamps (I'm on macOS 12.4. right now). -> Trying default again.
                                                                ///< Older comment from PointerFreeze.m: [Oct 2026]: Using a listenOnly tap would be more appropriate but they sometimes behave weirdly
            .mask = CGEventMaskBit(kCGEventMouseMoved) |        ///< Older comment from ModifiedDrag.m [Oct 2026]: kCGEventMouseMoved is only necessary for keyboard-only drag-modification (which we've disable because it had other problems), and maybe for AddMode to work.
                    CGEventMaskBit(kCGEventOtherMouseDragged) |
                    CGEventMaskBit(kCGEventRightMouseDragged) |
                    CGEventMaskBit(kCGEventLeftMouseDragged)    ///< Older comment from ModifiedDrag.m [Oct 2026] This is necessary for modified drag to work during a left-click and drag. Concretely I added this to make drag and drop work. Not sure if there are other concrete applications outside of drag and drop.
        },
        [kCGTapID_ScrollWheel] = { .options = kCGEventTapOptionDefault, .mask = CGEventMaskBit(kCGEventScrollWheel), },
        [kCGTapID_Experiment] = { .options = kCGEventTapOptionDefault, .mask = CGEventMaskBit(kCGEventTabletPointer), },

        [kCGTapID_PrimaryMouseButton] = { .options = kCGEventTapOptionDefault, .mask = CGEventMaskBit(kCGEventLeftMouseDown) | CGEventMaskBit(kCGEventLeftMouseUp), },
        [kCGTapID_SecondaryMouseButton] = { .options = kCGEventTapOptionDefault, .mask = CGEventMaskBit(kCGEventRightMouseDown) | CGEventMaskBit(kCGEventRightMouseUp), },
        [kCGTapID_OtherMouseButton] = { .options = kCGEventTapOptionDefault, .mask = CGEventMaskBit(kCGEventOtherMouseDown) | CGEventMaskBit(kCGEventOtherMouseUp), },

    };

    #pragma mark Locks for the State
    /// Background: This makes MFEventTap thread safe.  currently only need this for PointerFreeze.m, which wants to share one underlying `kMFEventType_Sensor` CGEventTap (on `IOThread`) with `TwoFingerSwipe.m`, but wants to do most stuff (and control MFEventTap) from mainThread  (See `Slow WindowServer IPC` > `Erratic momentum speeds` notes) [Oct 2026]
    ///     Could probably restructure `TwoFingerSwipe.m`/`PointerFreeze.m`slightly to avoid need for thread-safe `MFEventTap`, but just making it thread-safe seemed less risky and easier to think about [Oct 2026]

    static os_unfair_lock _listenerLock = OS_UNFAIR_LOCK_INIT; /// Why use `os_unfair_lock`? Idk Opus 5.5 told me. Works, is basically free. @synchronized would probably also work [Oct 2026]
    static os_unfair_lock _cgTapDataLock = OS_UNFAIR_LOCK_INIT;
    void _unlock(void *lock) { os_unfair_lock_unlock(*(void **)lock); }
    #define _lockScope(lockPtr) \
        os_unfair_lock_lock(lockPtr); \
        __attribute__((cleanup(_unlock))) auto _scopedLock = (lockPtr);

    #pragma mark Interface for listening

    + (void) registerListener: (MFEventListenerID *)listenerID forEvents: (MFEventType)events callback: (MFEventTapCallback)callback {
        _lockScope(&_listenerLock);

        if (!_listenerMap) _listenerMap = [NSMutableDictionary new];
        if (!_listenerList) _listenerList = [NSMutableArray new];

        _MFEventTapListener *listener = [_listenerMap objectForKey: listenerID];
        if (!listener) {
            listener = [_MFEventTapListener new];
            [_listenerMap  setObject: listener forKey: listenerID];
            [_listenerList addObject: listener];
        } else {
            /// Having only one function for registering and updates would be simpler [Oct 2026]
            mfrequire(false, @"registerListener: called repeatedly for listener. Use setEvents:forListener: or enable:forListener: instead [Oct 2026]");
        }
        configure(listener, it->_id = listenerID, it->_events = events, it->_callback = callback, it->_enabled = false);

        _DDLogDebug("Registered listener: %{public}@", listener);
        /// No need to call `updateCGTaps()` because listener starts disabled [Oct 2026]
    }
    + (void) setEvents: (MFEventType)events forListener: (MFEventListenerID *)listenerID {
        { _lockScope(&_listenerLock);
            _MFEventTapListener *listener = _listenerMap[listenerID];
            if (!listener) mfassert(false, @"Trying to set events (%@) for unknown listener id %@. Known: %@", MFEventTypeDescription(events), listenerID, [_listenerMap allKeys]);
            else           listener->_events = events;
            _DDLogDebug("Set events for listener %{public}@", listener);
        }
        updateCGTaps();
    }
    + (void) enable: (bool)enable forListener: (NSString *)listenerID {
        { _lockScope(&_listenerLock);
            _MFEventTapListener *listener = [_listenerMap objectForKey: listenerID];
            if (!listener) mfassert(false, @"Trying to enable unknown listener id %@. Known: %@", listenerID, [_listenerMap allKeys]);
            else           listener->_enabled = enable;
            _DDLogDebug("Enabled/disabled listener: %{public}@", listener);
        }
        updateCGTaps();
    }
    + (bool) isEnabledForListener: (NSString *)listenerID {
        _lockScope(&_listenerLock);
        _MFEventTapListener *listener = [_listenerMap objectForKey: listenerID];
        if (!listener) {
            mfassert(false, @"Trying to get isEnabled for unknown listener id %@. Known: %@", listenerID, [_listenerMap allKeys]);
            return false;
        }
        return listener->_enabled;
    }

    #pragma mark Impl for listening

    static void updateCGTaps(void) {

        _lockScope(&_cgTapDataLock);

        /// Record current enabledState
        bool _lastCGTapEnabled[kCGTapID_Max];
        for range(i, kCGTapID_Max) if (i) _lastCGTapEnabled[i] = _cgTapData[i].enabled;

        /// Update enabledState
        {
            /// Collect the combined MFEventTypes from all listeners
            MFEventType allTypes = 0;
            { _lockScope(&_listenerLock)
                for (_MFEventTapListener *listener in _listenerList)
                    if (listener->_enabled) {
                        if (listener->_events & kMFEventType_ButtonBlacklist) {
                            mfassert(false, @"Listener %@ contained blacklisted button (%@). Ignoring.", listener, MFEventTypeDescription(listener->_events & kMFEventType_ButtonBlacklist));
                            continue;
                        }
                        allTypes |= listener->_events;
                    }
            }

            /// Figure out which underlying `CGEventTaps` we need based on combined `MFEventTypes`
            _cgTapData[kCGTapID_KeyboardModifier].enabled     = allTypes & kMFEventType_KeyboardModifier;
            _cgTapData[kCGTapID_KeyPress].enabled             = allTypes & kMFEventType_KeyPress;

            _cgTapData[kCGTapID_Sensor].enabled               = allTypes & kMFEventType_Sensor;
            _cgTapData[kCGTapID_ScrollWheel].enabled          = allTypes & kMFEventType_ScrollWheel;
            _cgTapData[kCGTapID_Experiment].enabled           = allTypes & kMFEventType_Experiment;

            _cgTapData[kCGTapID_PrimaryMouseButton].enabled   = allTypes & kMFEventType_Button(0);
            _cgTapData[kCGTapID_SecondaryMouseButton].enabled = allTypes & kMFEventType_Button(1);
            _cgTapData[kCGTapID_OtherMouseButton].enabled     = (((allTypes & ~kMFEventType_Button(0) & ~kMFEventType_Button(1)) >> _kMFEventType_ButtonShift) & _kMFEventType_ButtonMask);

        }

        /// Toggle the cgTaps whose enabledState changed
        for range(i, kCGTapID_Max) if (i) if (_lastCGTapEnabled[i] != _cgTapData[i].enabled) {

            /// Lazily create the tap (not sure if good)
            ///     This leaks but ok since this only runs a few times [Oct 2026]
            if (!_cgTapData[i].tap) {

                CFMachPortRef eventTap = CGEventTapCreate(kTapLocation_Listening, kCGTailAppendEventTap, _cgTapData[i].options, _cgTapData[i].mask, sharedCGTapCallback, /*userInfo*/(void *)i);
                CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, /*order*/0);
                CFRunLoopAddSource(eventTapRunLoop(), runLoopSource, kCFRunLoopCommonModes);

                _cgTapData[i].tap = eventTap;
            }

            /// Toggle the tap
            CGEventTapEnable(_cgTapData[i].tap, _cgTapData[i].enabled);
        }

        if (runningDebugMode()) {
            _lockScope(&_listenerLock);
            _DDLogDebug("Updated taps to: %{public}@ for listeners %{public}@", CGTapDataDescription(_cgTapData), _listenerList);
        }
    }

    static CGEventRef sharedCGTapCallback(CGEventTapProxy proxy, CGEventType cgEventType, CGEventRef cgEvent, void *userInfo) {
        assertRunLoop(eventTapRunLoop());

        /// Get the cgTap
        CGTapID tapID = (CGTapID)userInfo;

        /// Handle special events
        if (cgEventType == kCGEventTapDisabledByTimeout || cgEventType == kCGEventTapDisabledByUserInput) {
            _DDLogDebug("cgTap '%{public}@' was disabled by %{public}@", CGTapIDDescription(tapID), cgEventType == kCGEventTapDisabledByTimeout ? @"timeout. Re-enabling." : @"user input.");
            if (cgEventType == kCGEventTapDisabledByTimeout) {
                _lockScope(&_cgTapDataLock);
                if (_cgTapData[tapID].enabled) CGEventTapEnable(_cgTapData[tapID].tap, true);
            }
            return cgEvent;
        }


        /// Find `MFEventType` for this cgEvent
        MFEventType mfEventType = 0;
        {
            if      (tapID == kCGTapID_KeyboardModifier)       mfEventType = kMFEventType_KeyboardModifier;
            else if (tapID == kCGTapID_KeyPress)               mfEventType = kMFEventType_KeyPress;

            else if (tapID == kCGTapID_Sensor)                 mfEventType = kMFEventType_Sensor;
            else if (tapID == kCGTapID_ScrollWheel)            mfEventType = kMFEventType_ScrollWheel;
            else if (tapID == kCGTapID_Experiment)             mfEventType = kMFEventType_Experiment;

            else if (tapID == kCGTapID_PrimaryMouseButton)     mfEventType = kMFEventType_Button(0);
            else if (tapID == kCGTapID_SecondaryMouseButton)   mfEventType = kMFEventType_Button(1);
            else if (tapID == kCGTapID_OtherMouseButton)       mfEventType = kMFEventType_Button(CGEventGetIntegerValueField(cgEvent, kCGMouseEventButtonNumber));

            else                                               mfrequire(false, @"Source code wrong");
        }

        /// Notify listeners for this `MFEventType`
        {

            /// Collect callbacks
            #define kListenerMax 16
            MFEventTapCallback callbacks[kListenerMax] = {}; int callbackCount = 0;

            { _lockScope(&_listenerLock);
                for (_MFEventTapListener *listener in _listenerList) {
                    if (listener->_enabled && listener->_events & mfEventType) {
                        mfrequire(callbackCount < kListenerMax);
                        callbacks[callbackCount++] = listener->_callback;
                        if ((0)) _DDLogDebug("Calling out to listener %{public}@ for eventType %{public}@", listener, MFEventTypeDescription(mfEventType)); /// Extremely verbose and not necessary [Oct 2026]
                    }
                }
            }

            /// Call the callbacks
            ///     Why do this in a separate pass? This makes it so the callbacks can
            ///         - Freely interact with MFEventTap without tripping the (non-recursive) `_listenerLock` [Oct 2026] or the objc for..in mutation checks.
            ///         - Opus 5.5 also says not doing this makes PointerFreeze.m receive the delta for the event which activated it (depending on `_listenerList` order), which makes its calculations very slightly wrong. Tested and the error seems to be too small to notice [Oct 2026]
            for range(i, callbackCount)
                callbacks[i](mfEventType, &cgEvent); /// If multiple listeners modify the `&cgEvent`, weird things could happen, MMF doesn't currently do this [Oct 2026]
        }

        /// Return event
        return cgEvent;
    }

    #pragma mark Interface for sending

    + (void) postCGEvent: (CGEventRef)cgEvent {
        if ((0)) _DDLogDebug("Posting event %{public}@", cgEvent); /// Too verbose, and completely unnecessary [Oct 2026]
        CGEventPost(kTapLocation_Posting, cgEvent);
    }

    #pragma mark Interface for debug descriptions

    + (NSString *) descriptionForListener: (MFEventListenerID *)listenerID {
        _lockScope(&_listenerLock);
        return [[_listenerMap objectForKey: listenerID] description];
    }
    + (MFEventType) eventsForListener: (MFEventListenerID *)listenerID {
        _lockScope(&_listenerLock);
        return [_listenerMap objectForKey: listenerID]->_events;
    }
@end
#endif
