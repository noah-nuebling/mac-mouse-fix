//
// --------------------------------------------------------------------------
// MFEventTap.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2026
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/**
    Abstraction over `CGEventTap` - our entire program doesn't use CGEventTap directly and instead goes through this [Oct 2026]
    Pros/contra for doing this over plain `CGEventTap`:
        - Weak pro: I guess it's nice having all the decisions about CGEventTap params and stuff in one place
        - Weak pro: I guess it reduces some boilerplate
        - Weak pro: I guess it lets us log the CGEventTap state of the entire program in one central place.
            Counter: But I don't think we ever had bugs with that anyways, and SwitchMaster was already kinda a central manager of all the CGEventTaps [Oct 2026]
        - Uncertain pro:`MFEventType` abstraction might make it easier to support remapping secondaryMouseButton
            - I think that's the only real reason we added `MFEventType` abstraction, I plan to test this soon, and maybe simplify if it doesn't hold up §mfEventTapTodo.
            - Update: [Oct 2026] Using `MFEventType` all over the new `SwitchMaster.m`, which simplified it a lot. (Though maybe using `CGEventMask` would've worked just as well.)
        - Uncertain pro: Minimizes WindowServer IPC. Explanation: The `TwoFingerSwipe.m` gesture and the thing it calls, `PointerFreeze.m`, might have some issues due to waiting for WindowServer. (See `Slow WindowServer IPC`)
            `CGEventTapEnable()` can be reduced, because `MFEventTap` makes `TwoFingerSwipe.m` and `PointerFreeze.m` share one CGEventTap under the hood. (See `Slow WindowServer IPC`)
                Caveat: You could've maybe found another/simpler solution to do the same thing.
            `CGEventTapIsEnabled()` can be avoided entirely (we keep the state in a static var) (Not addressed in `Slow WindowServer IPC` notes, but I think I saw ModifiedDrag optimization pull request mention that they saw `CGEventTapIsEnabled` be slow) (Maybe find what the pull request was and link it here)
        - Weak pro: This would let us manage all the `CGEventTapProxy` of the program and send each event at the earliest point that doesn't feed-back into our taps.
            But I don't know if there's any reason for this. See the `kTapLocation` notes below [Oct 2026]
        - Contra: MFEventType abstraction less flexible and could be more cumbersome for some experiments and stuff (See notes at `kMFEventType_Experiment` below [Oct 2026])
        - Contra: All taps locked to delivering on `eventTapRunLoop()`
        - Speculative pro: We currently have ~one tap per `MFEventType`. We could instead have one tap for each combination of currently listened-to `MFEventType`s, and only one tap ever active at a time.
            Possible downside: Every switch in `MFEventType`s costs an enable + a disable of an underlying CGEventTap, which might be more expensive/slow or cause other problems.
            Possible benefit: Events would be ordered exactly as the user produced them
                Why we think this might currently be a problem:
                    IIRC, one of my motivations for 'No more dispatch queues' refactor, was that I sometimes noticed the button being processed too late when ending a gesture, causing mouse-movement after letting gesture button go to still be processed as part of gesture.
                        After 'No more dispatch queues', I haven't noticed this anymore so far.
                        But I remember seeing another piece of evidence that this might be a problem: Having 2 `CGEventTap`s tapping mouseMoved, they didn't receive the
                        same events in lockstep, instead one tap got a burst of like 20 events, then the other tap got a burst of the same 20 events, and so on.
                        I don't remember exactly the circumstances of when I saw this, but it might suggest that there's still some desync when you have multiple `CGEventTap`s.
                        Having one active at a time should solve this. But I'll only look into that if I notice the problem again [Oct 2026]
        - Weak contra: Whenever we add support for HID++ and more device-specific code, we might want an even higher level abstraction that just says `listen to mouse clicks` but doesn't necessarily provide a `CGEvent` to the callback at all.
            I think current `MFEventTap` was kinda designed with this in mind, [Oct 2026] but doesn't really do this, yet and maybe it sits in an awkward middleground where it doesn't really do anything useful now and will
            have to be rewritten anyways once it becomes important... But I guess it works, so I'll keep it for now [Oct 2026]

    Optimization Idea - skip CGEvent serialization to lower CPU usage:
        [Oct 2026, macOS 27, M4 MBA] In `claude --resume 361c7ab2-a2f2-48cb-9d54-7b7bf7fbc804` Claude skipped CGEvent serialization for raw data communication with WindowServer.
        CPU usage of passing through mouse wiggles of 1000 Hz mouse went from 9% -> 4%. Required around 180 lines microlib of .defs and C helpers (Just for the tap, we didn't parse the eventData).
        Dataformat could break in future. Not sure if worth it. (WindowServer at ~45% and AppleUserHIDDrivers at ~15%, so all three together went from ~70% to ~65%.)
        Could maybe send Apple Feedback about this. (Claude in that session can explain what is inefficient)

*/

/// §mfEventTapTodo Try to support capturing Secondary mouse button (ButtonInputReceiver.m) and then decide whether the `kMFEventType_Button` / `MFEventType in general` abstractions actually are useful, or just complication.

#pragma once
#import <Foundation/Foundation.h>
#import <CoreGraphics/CGEvent.h>


#pragma mark - MFEventType stuff

#if IS_HELPER | IS_MAIN_APP
/// Why is `MFEventTap.m/.h` part of mainApp target? We use `kMFEventType_ButtonBlacklist` in mainApp. (That's also the reason for `#if __swift__`) Maybe should split the `MFEventType` stuff into separate file. [Oct 2026]

    typedef uint64_t MFEventType;
        //#define kMFEventType_UnregisterListener              ((MFEventType)0) /// We currently don't ever need to unregister listeners [Oct 2026]

        #define kMFEventType_KeyboardModifier           ((MFEventType)1 << 1)
        #define kMFEventType_KeyPress                   ((MFEventType)1 << 2)

        #define kMFEventType_Sensor                     ((MFEventType)1 << 3) /// [Oct 2026] TODO: Rename this to `_Pointer` (Match SwitchMaster terminology)
        #define kMFEventType_ScrollWheel                ((MFEventType)1 << 4)

        #define kMFEventType_Experiment                 ((MFEventType)1 << 5) /// [Oct 2026] Experimenting with other CGEventTypes is a little more difficult due to the MFEventType abstraction, but can still be done through something like this.

        #if __swift__
            #define _kMFEventType_ButtonShift 32
            static inline MFEventType MFEventType_Button(CGMouseButton buttonIndex) { mfrequire(buttonIndex >= 0 && buttonIndex < 32, @"MFEventType_Button arg out of range");
                                                                                      return ((MFEventType)1 << ((buttonIndex) + _kMFEventType_ButtonShift)); }
            #undef _kMFEventType_ButtonShift
        #else
            #define kMFEventType_Button(buttonIndex)        ({ mfrequire((buttonIndex) >= 0 && (buttonIndex) < 32, @"kMFEventType_Button arg out of range"); \
                                                               ((MFEventType)1 << ((buttonIndex) + _kMFEventType_ButtonShift)); })
        #endif

        #define _kMFEventType_ButtonShift 32
        #define _kMFEventType_ButtonMask  0xFFFFFFFF

        #define kMFEventType_AllButtons ((MFEventType)_kMFEventType_ButtonMask << _kMFEventType_ButtonShift)
        #define kMFEventType_AllEvents  ((MFEventType)-1)

        #if __swift__
            static inline MFEventType MFEventType_ButtonBlacklist(void) { return (MFEventType_Button(0) | MFEventType_Button(1)); }
        #else
            #define kMFEventType_ButtonBlacklist            (kMFEventType_Button(0) | kMFEventType_Button(1)) /** §afterNoGCDTodo: Allow capturing secondaryButton, and update the UI (SwitchMaster also has note/TODO about this I think) [Oct 2026] */
        #endif
        NSString *MFEventTypeDescription(MFEventType type);

#endif

#pragma mark - MFEventTap

#if IS_HELPER
@interface MFEventTap : NSObject

    /// Threading: All `MFEventTap` methods are thread-safe. Callbacks are invoked on `eventTapRunLoop()` [Oct 2026]
    #define eventTapRunLoop() [IOThread runLoop]

    /**
     Define `kTapLocation`s
         Constraints:
             `kTapLocation_Posting`: Swish installs at `kCGSessionEventTap`/`kCGHeadInsertEventTap` [Oct 2026] -> We need to post at `kCGSessionEventTap` or earlier to be compatible with it (Sending through a proxy of a `kCGSessionEventTap` tap is too late)
             `kTapLocation_Listening`: We need to listen earlier than `kTapLocation_Posting` to prevent feedback loops -> If we post at `kCGSessionEventTap` The only choice for listening is  `kCGHIDEventTap`.
             Other:
                 - Is there any reason to do `kTapLocation_Listening` later than `kCGHIDEventTap`?
                     - I used to think so, but I think that was only based on the `fast user switching` problems which we already resolved through `SessionDidResignActiveNotification` [Oct 2026]
                         If we ever wanted to listen later than `kCGHIDEventTap` after all,
                             - we could try to only post the events that swish needs early, but that would involve `e22`, (scroll events) I think, which MMF produces a lot of (so that would feed-back and increase CPU usage, probably). [Oct 2026]
                             - We could ask Swish developer to listen a little later at `kCGSessionEventTap`/`kCGTailAppendEventTap` [Oct 2026]
                 - If there's any reason to do posting and listening close together, MFEventTap could use our taps' `CGEventTapProxy` to post right after `kTapLocation_Listening` - but I don't see a reason to do that [Oct 2026]
    */
    #define kTapLocation_Listening ((CGEventTapLocation)kCGHIDEventTap)
    #define kTapLocation_Posting   ((CGEventTapLocation)kCGSessionEventTap)

    typedef NSString MFEventListenerID;

    typedef void (*MFEventTapCallback)(MFEventType eventType, CGEventRef *eventPtr);

    + (void) registerListener: (MFEventListenerID *)listenerID forEvents: (MFEventType)events callback: (MFEventTapCallback)callback;

    + (void) setEvents: (MFEventType)events forListener: (MFEventListenerID *)listenerID;
    + (void) enable: (bool)enable forListener: (MFEventListenerID *)listenerID;

    + (bool) isEnabledForListener: (MFEventListenerID *)listenerID;

    + (void) postCGEvent: (CGEventRef)cgEvent;

    + (NSString *) descriptionForListener: (MFEventListenerID *)listenerID;
    + (MFEventType) eventsForListener: (MFEventListenerID *)listenerID;

@end
#endif
