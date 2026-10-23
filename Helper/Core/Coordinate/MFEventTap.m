//
// --------------------------------------------------------------------------
// MFEventTap.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2026
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// @mfEventTapTodo Update stale comments throughout codebase
/// @mfEventTapTodo Probably tap at kCGHIDEventTap again, for feedback-free Swish interop.
/// @mfEventTapTodo Look into supporting universalControl (Not totally sure this is related to MFEventTap, seems like the failure point are the `iohidDevice != NULL` assertions, but I'd like to figure it out first in case it imposes any constraints on MFEventTap design)
/// @mfEventTapTodo Document why we're doing this

#import "MFEventTap.h"
#import "Threads.h"

#pragma mark - General helpers

#define auto __auto_type
#define configure(it_, configuration...) ({ \
    auto it = (it_); \
    configuration; \
    it; \
})
#define range(i, n) (int i = 0; i < (n); i++)
#define reverse_range(i, n) (int i = (int)(n)-1; i >= 0; i--)

#pragma mark - Private helper class

@interface _MFEventTapListener : NSObject
    { @public
        MFEventType           _events;
        MFEventTapCallback    _callback;
        void                  *_context;
        bool                  _enabled;
    }
@end
@implementation _MFEventTapListener @end

#pragma mark - Main impl

@implementation MFEventTap

    #pragma mark State
    static NSMutableDictionary<NSString *, _MFEventTapListener *> *_listeners = nil; /// @mfEventTapTodo Make iteration over these consistently ordered

    #pragma mark Interface for listening
    + (void) registerListener: (MFEventListenerID *)listenerID forEvents: (MFEventType)events callback: (MFEventTapCallback)callback context: (void *)context {
        assertRunLoop(IOThread.runLoop);
        if (!_listeners) _listeners = [NSMutableDictionary new];
        _listeners[listenerID] = !events ? nil : configure([_MFEventTapListener new], it->_events = events; it->_callback = callback; it->_context = context, it->_enabled = false);
        updateCGTaps(); /// Do need to call `updateCGTaps()` in case the user is disabling the tap which is currently running
    }
    + (bool) isEnabledForListener: (NSString *)listenerID {
        assertRunLoop(IOThread.runLoop);
        return _listeners[listenerID]->_enabled;
    }
    + (void) enable: (bool)enable forListener: (NSString *)listenerID {
        assertRunLoop(IOThread.runLoop);
        mfassert(_listeners[listenerID], @"Trying to enable unknown listener id %@. Known: %@", listenerID, [_listeners allKeys]);
        _listeners[listenerID]->_enabled = enable;
        updateCGTaps();
    }

    #pragma mark Impl for listening

    typedef enum {
        kCGTapID_Null = 0,

        kCGTapID_Modifier = 1,
        kCGTapID_Keystroke,

        kCGTapID_TrackingSensor,
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
            case kCGTapID_Modifier:                 return @"Modifier";
            case kCGTapID_Keystroke:                return @"Keystroke";
            case kCGTapID_TrackingSensor:           return @"TrackingSensor";
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
        CGEventTapProxy proxy;

        /// State
        bool enabled;
    } CGTapData;

    static CGTapID _orderedEventTaps[kCGTapID_Max] = {};
    static int _orderedEventTaps_Count = 0;

    static CGTapData _cgTapData[] = {
        [kCGTapID_Null] = {}, /// This entry allows for null-coalescing [Oct 2026]

        [kCGTapID_Modifier] = { .options = kCGEventTapOptionListenOnly, .mask = CGEventMaskBit(kCGEventFlagsChanged), },
        [kCGTapID_Keystroke] = { .options = kCGEventTapOptionDefault, .mask = CGEventMaskBit(kCGEventKeyDown) | CGEventMaskBit(NX_SYSDEFINED), },

        [kCGTapID_TrackingSensor] = {
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

    static void updateCGTaps(void) {

        /// Record current enabledState
        bool _lastCGTapEnabled[kCGTapID_Max];
        for range(i, kCGTapID_Max) if (i) _lastCGTapEnabled[i] = _cgTapData[i].enabled;

        /// Update enabledState
        {
            /// Collect the combined MFEventTypes from all listeners
            MFEventType allTypes = 0;
            for (_MFEventTapListener *listener in [_listeners allValues])
                if (listener->_enabled)
                    allTypes |= listener->_events;

            /// Figure out which underlying `CGEventTaps` we need based on combined `MFEventTypes`
            _cgTapData[kCGTapID_Modifier].enabled             = allTypes & kMFEventType_Modifier;
            _cgTapData[kCGTapID_Keystroke].enabled            = allTypes & kMFEventType_Keystroke;

            _cgTapData[kCGTapID_TrackingSensor].enabled       = allTypes & kMFEventType_TrackingSensor;
            _cgTapData[kCGTapID_ScrollWheel].enabled          = allTypes & kMFEventType_ScrollWheel;
            _cgTapData[kCGTapID_Experiment].enabled           = allTypes & kMFEventType_Experiment;

            _cgTapData[kCGTapID_PrimaryMouseButton].enabled   = allTypes & kMFEventType_Button(0);
            _cgTapData[kCGTapID_SecondaryMouseButton].enabled = allTypes & kMFEventType_Button(1);
            _cgTapData[kCGTapID_OtherMouseButton].enabled     = (((allTypes & ~kMFEventType_Button(0) & ~kMFEventType_Button(1)) >> _kMFEventType_ButtonShift) & _kMFEventType_ButtonMask);

        }

        /// Toggle the cgTaps whose enabledState changed
        for range(i, kCGTapID_Max) if (i)
            if (_lastCGTapEnabled[i] != _cgTapData[i].enabled) {

                /// Lazily create the tap (not sure if good)
                ///     This leaks but ok since this only runs a few times [Oct 2026]
                if (!_cgTapData[i].tap) {

                    CFMachPortRef eventTap = CGEventTapCreate(kMFEventTapLocation, kCGTailAppendEventTap, _cgTapData[i].options, _cgTapData[i].mask, sharedCGTapCallback, /*userInfo*/(void *)i);
                    CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, /*order*/0);
                    CFRunLoopAddSource([IOThread runLoop], runLoopSource, /*mode*/kCFRunLoopCommonModes);
                    _cgTapData[i].tap = eventTap;
                    _orderedEventTaps[_orderedEventTaps_Count++] = i; /// Works because we use `kCGTailAppendEventTap`
                }

                /// Toggle the tap
                CGEventTapEnable(_cgTapData[i].tap, _cgTapData[i].enabled);
            }
    }

    static CGEventRef sharedCGTapCallback(CGEventTapProxy proxy, CGEventType cgEventType, CGEventRef cgEvent, void *userInfo) {

        /// Get the cgTap
        CGTapID tapID = (CGTapID)userInfo;

        /// Store the cgProxy
        _cgTapData[tapID].proxy = proxy;

        /// Handle special events
        if (cgEventType == kCGEventTapDisabledByTimeout || cgEventType == kCGEventTapDisabledByUserInput) {
            DDLogDebug("MFEventTap: cgTap %@ was disabled by %@", CGTapIDDescription(tapID), cgEventType == kCGEventTapDisabledByTimeout ? @"timeout. Re-enabling." : @"user input.");
            if (cgEventType == kCGEventTapDisabledByTimeout) CGEventTapEnable(_cgTapData[tapID].tap, true);
            return cgEvent;
        }


        /// Find `MFEventType` for this cgEvent
        MFEventType mfEventType = 0;
        {
            if      (tapID == kCGTapID_Modifier)               mfEventType = kMFEventType_Modifier;
            else if (tapID == kCGTapID_Keystroke)              mfEventType = kMFEventType_Keystroke;

            else if (tapID == kCGTapID_TrackingSensor)         mfEventType = kMFEventType_TrackingSensor;
            else if (tapID == kCGTapID_ScrollWheel)            mfEventType = kMFEventType_ScrollWheel;
            else if (tapID == kCGTapID_Experiment)             mfEventType = kMFEventType_Experiment;

            else if (tapID == kCGTapID_PrimaryMouseButton)     mfEventType = kMFEventType_Button(0);
            else if (tapID == kCGTapID_SecondaryMouseButton)   mfEventType = kMFEventType_Button(1);
            else if (tapID == kCGTapID_OtherMouseButton)       mfEventType = kMFEventType_Button(CGEventGetIntegerValueField(cgEvent, kCGMouseEventButtonNumber));

            else                                               mfrequire(false, @"Source code wrong");
        }

        /// Notify listeners for this `MFEventType`
        for (_MFEventTapListener *listener in [_listeners allValues])
            if (listener->_enabled && listener->_events & mfEventType)
                listener->_callback(listener->_context, mfEventType, &cgEvent); /// If multiple listeners modify the `&cgEvent`, weird things could happen, MMF doesn't currently do this [Oct 2026]

        /// Return event
        return cgEvent;
    }

    #pragma mark Interface for sending

    + (void) postCGEvent: (CGEventRef)cgEvent {
        assertRunLoop(IOThread.runLoop);

        CGEventTapProxy lastProxy = NULL;
        for reverse_range(i, _orderedEventTaps_Count)
            if (_cgTapData[_orderedEventTaps[i]].proxy)
                { lastProxy = _cgTapData[_orderedEventTaps[i]].proxy; break; }

        if (lastProxy) CGEventTapPostEvent(lastProxy, cgEvent);  /// Post after the last of our taps, prevents any feedback loops [Oct 2026]
        else           [self postCGEventBeforeAllSessionTaps: cgEvent]; /// This can't feed back into our taps either, because we always have a proxy for all our taps (I hope) [Oct 2026]. @mfEventTapTodo: Look into private API for getting the proxy immediately
    }

    + (void) postCGEventBeforeAllSessionTaps: (CGEventRef)cgEvent { /// Posting gesture events here or before is necessary for interop with Swish which taps at `kCGSessionEventTap`/`kCGHeadInsertEventTap` says Opus 5.5 [Oct 2026] There's no harm (feedback loop chance) in posting before our taps if it's an eventType we're not listening to (We're not listening to touch events) [Oct 2026] @mfEventTapTodo: Actually, we do listen to e22 - so there is feedback, costing CPU.
        assertRunLoop(IOThread.runLoop);
        CGEventPost(kCGSessionEventTap, cgEvent);
    }

    #pragma mark Debug descriptions
    + (NSString *) descriptionForListener: (MFEventListenerID *)listenerID {
        assertRunLoop(IOThread.runLoop);
        return [_listeners[listenerID] description];
    }
@end
