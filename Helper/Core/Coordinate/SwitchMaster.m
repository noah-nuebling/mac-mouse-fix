//
// --------------------------------------------------------------------------
// SwitchMaster.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2026
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/**
     This class dynamically turns on or off interception of certain events sent by the device, based on the current state.
        This way Mac Mouse Fix doesn't waste CPU cycles in the background when it's not doing anything [Oct 2026]

     The relevant state we base our decisions off is: [Oct 2026]
     - attachedDevices                                          (`_state->_latestDevices`)
     - modifications (remaps & scrollConfig)     (`_state->_latestRemaps`, `_state->_latestScrollConfig`)
     - modifiers                                                        (`_state->_latestModifiers`)

     The intercepted eventTypes are: [Oct 2026]
     - Keyboard modifier changes (`kMFEventType_KeyboardModifier` [Oct 2026])
     - Scroll wheel input                   (`kMFEventType_ScrollWheel` [Oct 2026])
     - Mouse button clicks               (`kMFEventType_Button(...)` [Oct 2026])
     - Mouse movement                   (`kMFEventType_Sensor` [Oct 2026])

     On Optimization
     - [ ] When buttons are not used as trigger and are only used as modifier in combination with kbMod, we could switch off buttonTap until kbMods are pressed.
         - -> Implementation ideas: only toggle buttonTap if button is used as "solo" modifier (without kbMod requirement) or if the kbMod it could "complete" a modification precondition together with the currently active keyboard modifiers.
         - This might be easier impelement / more performant if we encode this kbMods -> btnMods -> modifications hierarchy into the remaps dataStructure, currently it has a form (kbMods, btnMods) -> modifications. Or if we bring back the original "modifiying actions" architecture. But that probably requires large architectural changes and would create other problems.
         Update: [Oct 2026] Still sounds like a good idea
         Update 2 [Oct 2026] Opus 5.5 is concerned about edge-cases when buttons are uncaptured while they are held. This can already happen but would become more frequent. (And current per-`kMFEventType_Button(x)` capturing also already makes it more frequent.)
            Examples of what could go wrong: (By Opus 5.5)
                - holdTimer times out after button is uncaptured before being physically released
                - mouseDown passed through, then captured, then swallow mouseUp
            §afterNoGCDTodo -> Look into this.
     - [x] We should move the remapsAnalysis methods into RemapsAnalyzer and cache the ones that are used when the modifier state changes.
         - -> Moved the performance-critical stuff to RemapsAnalyzer. Tried caching but it didn't speed things up (at least the way I did it - maybe if we cache bigger chunks of data we could get a speedup)
            Update: [Oct 2026] Everything's objc now!
     - [x] Using simple function calls instead of reactiveSwift should improve performance a decent bit. Should consider that,at least for the buttonModifier input
         - Improved performance a good bit. See commit 1a15623bd254d548b553d0073df1bf72887f1ac1.
            Update: [Oct 2026] Everything's objc now!

     Issues:
     - When you detach mouse during modifiedDrag, modifiedDrag will immediately re-enable when you re-attach the mouse. I think this is because the modifier state doesn't reset properly when the mouse is detached.
        [Oct 2026] Not sure if stale after objc rewrite.

     Testing: [ ]
     - [ ] Keyboard Modifiers have 0% CPU usage when not toggling another tap
     - [ ] Scrolling has 0% CPU usage when umodified
     - [ ] Buttons have 0% CPU usage when not (modified or toggling another tap)
     - [ ] Buttons work as modifiers even if no buttons are modified
     - [ ] Pointing has 0% CPU usage when unmodified
     - AddMode works even when all input taps are turned off for (and the assigned action also works)
      - [ ] Click, Hold, Double Click, Button Modifier + Click, Keyboard Modifier + Click
      - [ ] Click and Drag, Double Click and Drag, Keyboard Modifier + Click and Drag
      - [ ] Click and Scroll, Double Click and Scroll, Keyboard Modifier + Click and Scroll
     - Kill switch testing
      - [ ] 0% CPU when using either of the killSwitces
      - [ ] When kbMods toggle scrollTap (and nothing else), scrollKillSwitch also disables kbModTap
      - [ ] addMode still works with the killSwitches are enabled
      - [ ] Test if lockDown works

     Tried but didn't like:
        - Disable (grey-out) killSwitches when the intercept they control is disabled anyways -> Didn't like this
            - Delete code in [Oct 2026]. It had this comment:
            - `/// Disabling this, because I think it's not really clear to users what graying out the items means or when it happens.`

     Discussion on `Reactivity`
        [Summer 2024]
            The logic of the SwitchMaster would naturally lend itself really well to using a Reactive framework like ReactiveSwift. In fact, I believe we initially tried to implement the logic
            with ReactiveSwift but it ended up being too slow, and so we re-implemented the Reactive control flow using simple function calls. Now that we dropped support for older macOS versions, perhaps we could try using Combine for this. I heard it's fast.
        Update: [Oct 2026]
            I hate Swift now. No combine oh god.
            Rewrote in C, made custom tiny dependency resolution system, which made code much more readable. (See `processChangedState` [Oct 2026])
            Then also refactored to use `MFEventType` which simplified dependency graph / number of update functions so much that `processChangedState` might not even be necessary anymore. [Oct 2026]

    History: [Oct 2026]
        - SwitchMaster.swift shipped since MMF 3.0.0, worked fine
        - Tried to add secondaryMouseButton capturing support in [Oct 2026]. Code was kinda spaghetti, hard to understand for me.
        - Rewrote to SwitchMaster.m
            Initially wrote interesting automatic dependency-resolution system. It worked like this:
                Stored state in array indexed by `kStateID_`, functions had a companion array declaring `kStateID` dependencies,
                state-modification went through setState() helper which marked the kStateID dirty, then a `processStateChanges()` function
                would automatically run the functions depending on the dirty/changed state.
            I think it's a really good way to do this kind of dependency resolution thing, since the array indexes can be converted to bitflags, which makes all the other code pretty simple and elegant.
            However, we then found something even better and simpler (see below)
            I don't think I checked this version into git.
        - Then adopted `MFEventType`, which made the code so simple that we didn't need the automatic-dependency resolution anymore.
        - Could then see that just having a single update function doesn't have any practical performance downsides, so simplified to that. That's what we're shipping now. [Oct 2026]

    §mfEventTapTodo: [Oct 2026]
        Support secondary mouse button, and the ordered capturing (In the `On Optimization` todo above)
            See the existing §afterNoGCDTodo and §mfEventTapTodo tags, and `MFEventType_ButtonBlacklist`
*/

#import "SwitchMaster.h"
#import "Logging.h"
#import "Threads.h"
#import "Config.h"
#import "DeviceManager.h"
#import "Remap.h"
#import "MFDescriptionWithIndent.h"
#import "Mac_Mouse_Fix_Helper-Swift.h"

#pragma mark - State

@interface State : NSObject { /// Wrap the state in a singleton object to take advantage of `class_copyIvarList` for debug logging. Not sure if better than X-macro or just doing it manually [Oct 2026]
    @public
    /// `_latest`
    ///     These are the base inputs for our algorithm - they are reported to us from other parts of the program
    ///     via the functions starting with `SwitchMaster_` [Oct 2026]
    id _latestDevices;
    id _latestRemaps;
    id _latestScrollConfig;
    id _latestModifiers;

    /// `Misc`
    ///     Other facts reported to us through by `SwitchMaster_`  functions, which also go into our decisions about which events to intercept. [Oct 2026]
    bool _isLockedDown;
    bool _userIsActive;
    bool _addModeIsEnabled;

    /// `_events`
    ///     From the `_latest` and `Misc` state, we derive facts about how the program wants to treat different events.
    ///     These variables are caches for some of those facts that we only re-calculate when the respective input changes, not every time `processChangedState()` is called. [Oct 2026].

    MFEventType _eventsKilledBySwitch;
    MFEventType _eventsSupportedBySomeDevice;
    MFEventType _eventsModifiedByDefault;       /// Events which are modified by the default modifications, that is even when no modifiers are held down. [Oct 2026]
    MFEventType _eventToModifyingEventsMap[sizeof(MFEventType) * CHAR_BIT];      /// Square matrix of `MFEventType` bits.
    #define indexForLastEventIn(eventTypes) __builtin_ctzll(eventTypes)          /// Index into `_eventToModifyingEventsMap` [Oct 2026]
    #define eventTypeForIndex(i)            ((MFEventType)1 << i)                /// `MFEventType` for an index into `_eventToModifyingEventsMap` [Oct 2026]


} @end
@implementation State @end

static State *_state = nil;

@implementation NSObject (SwitchMasterHoisting) /// Standard pattern where objc category hoists C functions (automatically forward declares) [Oct 2026]

#pragma mark - Local helpers

#define auto __auto_type
#define range(i, n) (int i = 0; i < (n); i++)
#define countof(x...) (sizeof(x) / sizeof(*(x)))

#pragma mark - Descriptions / Debug Logging

static NSArray<NSString *> *_stateIvarNames(void) {
    static NSMutableArray *result = nil;
    static dispatch_once_t onceToken; dispatch_once(&onceToken, ^{
        result = [NSMutableArray new];
        Ivar *ivars = class_copyIvarList([State class], NULL);
        for (int i = 0; ivars[i]; i++)
            [result addObject: @(ivar_getName(ivars[i]) ?: "")];
        free(ivars);
    });
    return result;
}

static NSMutableString *_stateDescription(void) { /// Description of ivars inside `_state` singleton [Oct 2026]
    NSMutableString *result = [NSMutableString new];
    [result appendString: @"{\n"];
    for (id stateName in _stateIvarNames()) {
        NSMutableString *valueDescription = nil;
        if ([stateName hasPrefix: @"_latest"])
            continue;
        else if ([stateName hasPrefix: @"_events"])
            valueDescription = stringf(@"(%@)", MFEventTypeDescription([[_state valueForKey: stateName] longLongValue]));
        else if ([stateName hasPrefix: @"_eventToModifyingEventsMap"]) {
            valueDescription = [NSMutableString new];
            [valueDescription appendString: @"{\n"];
            for range(i, countof(_state->_eventToModifyingEventsMap))
                if (_state->_eventToModifyingEventsMap[i])
                    [valueDescription appendFormat: @"        [%@] = (%@);\n", MFEventTypeDescription(eventTypeForIndex(i)), MFEventTypeDescription(_state->_eventToModifyingEventsMap[i])];
            [valueDescription appendString: @"    }"];
        }
        else
            valueDescription = stringf(@"%@", [_state valueForKey: stateName]);
        [result appendFormat: @"    %@: %@\n", stateName, valueDescription];
    }
    [result appendString: @"}"];
    return result;
}

static NSMutableString *_latestStateDescription(void) { /// Description of the `_latest` ivars in the `_state` singleton [Oct 2026]
    NSMutableString *result = [NSMutableString new];
    [result appendString: @"{\n"];
    for (id stateName in _stateIvarNames())
        if ([stateName hasPrefix: @"_latest"])
            [result appendFormat: @"    %@: %@\n", stateName, [[_state valueForKey: stateName] mf_descriptionWithIndent: 4]];
    [result appendString: @"}"];
    return result;
}

static NSString *debugStateDescription(void) { /// We append this to our debug log messages [Oct 2026]. (Don't prepend because these can be long and `os_log` will truncate [Oct 2026])
    assertRunLoop([IOThread runLoop]);

    return stringf(@""
        "EventTap state - kbMod: %d, btnMod: %d, button: (%@), scroll: %d, pointing: %d\n"
        "MenuItem state - buttonMenu: %d, scrollMenu: %d\n"
        "Internal `_latest` state - %@\n"
        "Internal state - %@",
        [Modifiers kbModPriority], [Modifiers btnModPriority], [ButtonInputReceiver listenedToEventsDescription], [Scroll isReceiving], [ModifiedDrag debug_activationState],
        [(id)config(@"General.buttonKillSwitch") boolValue], [(id)config(@"General.scrollKillSwitch") boolValue], /// [Oct 2026] Used to go directly through `MenuBarItem.scrollItemIsEnabled` instead of `config()` but that's owned by mainThread. Not sure this makes sense.
        (1) ? @"(too verbose)" : _latestStateDescription(), /// This is too verbose and prevents me from seeing the boolean flags [Oct 2026]
        _stateDescription());
}

#define logWithState(message...) ({ if (runningDebugMode()) { _logWithState(stringf(message)); } })
static inline void _logWithState(NSString *message) {
    DDLogDebug("SwitchMaster: %{public}@\n%{public}@", message, debugStateDescription());
}

#pragma mark - Other debug

static MFReadWriteTracker _readWriteTracker = {};

#pragma mark - Interface

#define returnIfNotInitialized() if (!_state) return /// See the notes above `_state = [State new];` [Oct 2026]

void SwitchMaster_Load_Manual(void) {

    /// Notes:
    /// - [Mar 2025] During app startup SwitchMaster seems to called a bazillion times before being initialized. That's inefficent (and might even lead to corrupted state?)
    ///     - Solution idea 1: Make `.shared` optional and create the singleton instance inside `load_Manual`
    ///         ... However that might cause SwitchMaster to miss important state-updates during startup. We'd have to manually fill in all the initial state inside `load_Manual`. A proper reactive system would be able to do this automatically, but with our system it'd be difficult to maintain. (Sidenote: IIRC, we initially implemented this in ReactiveSwift but moved to manual function calls because it was too slow.)
    ///     - Solution idea 2: Alternatively we could simply remove `load_Manual` and have the place that previously called it init HelperState instead.
    ///         -> This should ensure correct behavior more easily than if we only start recording any state after `load_Manual`. While SwitchMaster might be called a few times during startup before it starts turning on any taps, it's pretty optimized and made to be called all the time, so actually shouldn't be a problem.
    ///     - Update [Oct 2026]: We now use `_state->` everywhere which would crash if it's nil. We did have to change the init order in `AccessibilityCheck.m` after making this change. Opus 5.5 says SwitchMaster can still be called into unititialized when we don't have AX permissions. Hence `returnIfNotInitialized` [Oct 2026]

    /// Create `_state` singleton
    _state = [State new];

    /// Force HelperState to init so that it updates `userIsActive`
    ///     Might be better to just directly assign `userIsActive` here instead of this indirect stuff.
    ///     Update: [Oct 2026] Not sure this is stale.
    (void)[HelperState shared];

    /// Not sure this is necessary or useful
    ///     Update [Mar 2025] Still not totally sure. But I don't think it's necessary. The managers of all the state we're setting here should give SwitchMaster a callback when the state is initialized or when it changes. If the managers do that, then this shouldn't be necessary.
    _state->_latestDevices        = [DeviceManager attachedDevices];
    _state->_latestRemaps         = [Remap remaps];
    _state->_latestScrollConfig   = [ScrollConfig defaultInstance]; /// Not sure if this is a good initialization value
    _state->_latestModifiers      = [Modifiers modifiersWithEvent: NULL];

    /// Debug
    logWithState(@"Initialized.");
}

void SwitchMaster_LockDown(void) {
    assertRunLoop([IOThread runLoop]); readsAndWritesState(&_readWriteTracker); returnIfNotInitialized();

    _state->_isLockedDown = 1;

    if (processChangedState()) logWithState(@"Toggled due to lockdown.");
}
void SwitchMaster_HelperStateChanged(void) { /// For fast user switching [Oct 2026]
    assertRunLoop([IOThread runLoop]); readsAndWritesState(&_readWriteTracker); returnIfNotInitialized();

    /// NOTES:
    /// - On listening to `[[HelperState shared] activeDevice]`
    ///     - This would let us turn off buttonTap / scrollTap for mice that don't support buttons / don't support scrolling. However then we couldn't update the active device when another mouse sends scroll or button input because we wouldn't be listening to that input. So it's better to just listen to all `[DeviceManager attachedDevices]`.
    ///     - [Oct 2026] Still makes sense

    _state->_userIsActive = [[HelperState shared] userIsActive];

    if (processChangedState()) logWithState(@"Toggled due to helperState change.\n"
                                             "New state - userIsActive: %d",
                                             _state->_userIsActive);
}
void SwitchMaster_GeneralConfigChanged(NSDictionary *generalConfig) { /// For kill switches [Oct 2026]
    assertRunLoop([IOThread runLoop]); readsAndWritesState(&_readWriteTracker); returnIfNotInitialized();

    _state->_eventsKilledBySwitch = 0;
    if ([[generalConfig objectForKey: @"buttonKillSwitch"] boolValue]) _state->_eventsKilledBySwitch |= kMFEventType_AllButtons;
    if ([[generalConfig objectForKey: @"scrollKillSwitch"] boolValue]) _state->_eventsKilledBySwitch |= kMFEventType_ScrollWheel;

    if (processChangedState()) logWithState(@"Toggled due to killSwitch change.\n"
                                            "New state - btn: %d, scrl: %d",
                                            !!(_state->_eventsKilledBySwitch & kMFEventType_AllButtons), !!(_state->_eventsKilledBySwitch & kMFEventType_ScrollWheel));
}

void SwitchMaster_AttachedDevicesChanged(NSArray *devices) {
    assertRunLoop([IOThread runLoop]); readsAndWritesState(&_readWriteTracker); returnIfNotInitialized();

    _state->_latestDevices = devices;
    _state->_eventsSupportedBySomeDevice = [DeviceManager eventTypesSupportedBySomeDevice];

    if (processChangedState()) logWithState(@"Toggled due to attachedDevices change.\n"
                                             "New devices: %@",
                                             [devices debugDescription] /** Old comment from the Swift version: `debugDescription` prevents escaping linebreaks somehow [Oct 2026] */);
}
void SwitchMaster_RemapsChanged(NSDictionary *remaps) {
    assertRunLoop([IOThread runLoop]); readsAndWritesState(&_readWriteTracker); returnIfNotInitialized();

    _state->_latestRemaps = remaps;

    _state->_addModeIsEnabled = [Remap addModeIsEnabled];

    {
        /// Build map from `event -> eventsModifying(event)` (aka `_state->_eventToModifyingEventsMap` [Oct 2026])
        memset(_state->_eventToModifyingEventsMap, 0, sizeof(_state->_eventToModifyingEventsMap)); /// memset 500 bytes. Opus 5.5 says it's still much cheaper than the NSDictionary stuff below. [Oct 2026]
        [remaps enumerateKeysAndObjectsUsingBlock: ^(id modifiers, id modifications, BOOL *stop) { /// Use `enumerateKeysAndObjectsUsingBlock:` over `for...in` for optimization I guess (Untested) [Oct 2026]
            MFEventType modifyingEvents = [RemapsAnalyzer eventsInModifiers: modifiers];
            if (modifyingEvents) {
                MFEventType modifiedEvents  = [RemapsAnalyzer eventsModifiedByModifications: modifications];
                for (MFEventType m = modifiedEvents; m; m &= m-1) {
                    int modifiedEventIndex = indexForLastEventIn(m);
                    _state->_eventToModifyingEventsMap[modifiedEventIndex] |= modifyingEvents;
                }
            }
        }];

        /// Update `_state->_eventsModifiedByDefault`
        MFEventType eventsModifiedByDefault = [RemapsAnalyzer eventsModifiedByModifications: [Remap modificationsWithModifiers: @{}]];
        mfrequire(!(eventsModifiedByDefault & kMFEventType_Sensor)); /// MMF never wants to intercept Pointer events without a modifier held [Oct 2026]
        _state->_eventsModifiedByDefault = (_state->_eventsModifiedByDefault & kMFEventType_ScrollWheel) | eventsModifiedByDefault; /// Override everything except `kMFEventType_ScrollWheel`, which is controlled by another function [Oct 2026]
    }

    if (processChangedState()) logWithState(@"Toggled due to remaps change.\n"
                                             "New remaps: %@",
                                             [Remap addModeIsEnabled] ? @"<AddMode-TooVerbose>" : [remaps mf_descriptionWithIndent: 0]);
}
void SwitchMaster_ScrollConfigChanged(ScrollConfig *scrollConfig) {
    assertRunLoop([IOThread runLoop]); readsAndWritesState(&_readWriteTracker); returnIfNotInitialized();

    _state->_latestScrollConfig = scrollConfig;

    bool scrollModifiedByDefault = (scrollConfig.smoothEnabled ||
                                   scrollConfig.u_speed != kMFScrollSpeedSystem ||
                                   scrollConfig.u_invertDirection == kMFScrollInversionInverted);

    if (!scrollModifiedByDefault) _state->_eventsModifiedByDefault &= ~kMFEventType_ScrollWheel;
    else                          _state->_eventsModifiedByDefault |= kMFEventType_ScrollWheel;

    if (processChangedState()) logWithState(@"Toggled due to scrollConfig change.\n"
                                             "New scrollConfig: %@",
                                             scrollConfig);
}
void SwitchMaster_ModifiersChanged(NSDictionary *modifiers) { /// This is the only one of the `SwitchMaster_` functions that runs frequently (~ every user interaction) [Oct 2026]
    assertRunLoop([IOThread runLoop]); readsAndWritesState(&_readWriteTracker); returnIfNotInitialized();

    _state->_latestModifiers = modifiers;

    if (processChangedState()) logWithState(@"Toggled due to modifier change.\n"
                                             "New modifiers: %@",
                                             [modifiers mf_descriptionWithIndent: 0]);
}


static bool processChangedState(void) {

    bool toggled = 0;

    /// Get state derived from `SwitchMaster_RemapsChanged` + `SwitchMaster_ModifiersChanged` [Oct 2026]
    ///     Optimization: `Remap` and `RemapsAnalyzer` stuff might be a little expensive, but it's still ok to run on every `stateChange`, since the only
    ///         frequently invoked `SwitchMaster_` function is  `SwitchMaster_ModifiersChanged`, which needs to trigger this update anyways. [Oct 2026]
    NSDictionary *modifications;
    MFEventType eventsModifiedCurrently;
    {
        modifications = [Remap modificationsWithModifiers: _state->_latestModifiers]; /// Un-greppably depends on `_state->_latestRemaps`/`SwitchMaster_RemapsChanged` [Oct 2026]
        eventsModifiedCurrently = [RemapsAnalyzer eventsModifiedByModifications: modifications] |
                                  (_state->_eventsModifiedByDefault & kMFEventType_ScrollWheel);
    }

    /// Get reusable filter thing for the next two steps [Oct 2026]
    MFEventType baseModifiableEvents = _state->_eventsSupportedBySomeDevice &
                                      ~_state->_eventsKilledBySwitch &
                                      ~kMFEventType_ButtonBlacklist;    /// This is how we apply `kMFEventType_ButtonBlacklist` to the *modifiable* events [Oct 2026]. (Not sure if convoluted)

    /// Toggle the modifier processing [Oct 2026]
    ///     Optimization: This is ok to run on every `stateChange` since it's incredibly cheap (Just a few raw C integer manipulations if it doesn't end up toggling anything) [Oct 2026]

    MFEventType eventsActivelyModifyingCurrently = 0, eventsPassivelyModifyingCurrently = 0;
    {
        static MFEventType lastActiveEvents = 0, lastPassiveEvents = 0;
        {
            if (_state->_isLockedDown || !_state->_userIsActive) {
                eventsActivelyModifyingCurrently = 0; eventsPassivelyModifyingCurrently = 0;
                goto endof_findModifyingEvents;
            }

            /// Handle `addMode`
            ///     We simply listen to all modifiers. `addModeSwizzler` then creates new remaps containing those modifiers on the fly as we press the modifiers. [Oct 2026]
            ///     `addModeSwizzler` also filters out invalid combinations (`kMFEventType_ScrollWheel` / `kMFEventType_Sensor` without a button modifier) [Oct 2026]
            ///     Also see: [Oct 2026]
            ///          - `addModeSwizzler()`
            ///          - `+[Remap enableAddMode]`
            ///          - `+[Remap sendAddModeFeedback]`
            if (_state->_addModeIsEnabled) {
                eventsActivelyModifyingCurrently = (kMFEventType_AllButtons | kMFEventType_KeyboardModifier);
                eventsPassivelyModifyingCurrently = 0;
                goto endof_findModifyingEvents;
            }

            auto eventsModifyingEvents = ^MFEventType (MFEventType modifiedEvents)
            {
                MFEventType modifyingEvents = 0;
                for (MFEventType m = modifiedEvents; m; m &= m-1)
                    modifyingEvents |= _state->_eventToModifyingEventsMap[indexForLastEventIn(m)];
                return modifyingEvents;
            };

            MFEventType modifyingEvents         = eventsModifyingEvents(baseModifiableEvents);
            /// Events which aren't modified by default (= when no modifiers are held), might need their tap toggled based on whether the modifiers are held.
            ///     For that, we need to tap the modifiers, that's what 'activeListen' means. See `Modifiers.h/.m` > `activeListen` notes. [Oct 2026]
            eventsActivelyModifyingCurrently    = eventsModifyingEvents(baseModifiableEvents & ~_state->_eventsModifiedByDefault);
            eventsPassivelyModifyingCurrently   = modifyingEvents & ~eventsActivelyModifyingCurrently;

        } endof_findModifyingEvents:

        eventsActivelyModifyingCurrently  &= ~kMFEventType_ButtonBlacklist; /// This is how we apply `kMFEventType_ButtonBlacklist` to the *modifying* events. (Not sure if convoluted) [Oct 2026]
        eventsPassivelyModifyingCurrently &= ~kMFEventType_ButtonBlacklist;

        if (lastActiveEvents != eventsActivelyModifyingCurrently || lastPassiveEvents != eventsPassivelyModifyingCurrently) {
            [Modifiers setModifierPriorityWithActiveListenEvents: eventsActivelyModifyingCurrently passiveUseEvents: eventsPassivelyModifyingCurrently];
            lastActiveEvents = eventsActivelyModifyingCurrently; lastPassiveEvents = eventsPassivelyModifyingCurrently;
            toggled = 1;
        }
    }

    /// Toggle eventTaps
    ///     Optimization: This is ok to run on every `stateChange` since it's incredibly cheap (just a few raw C int manipulations if it doesn't toggle anything) [Oct 2026]
    {
        /// Get events we want to tap
        MFEventType eventsToListenTo = 0;
        {
            if (_state->_isLockedDown || !_state->_userIsActive)
                goto endof_thing;

            /// Gather `Currently` active events
            {
                eventsToListenTo = eventsModifiedCurrently;
                /// Add button modifiers - `Modifiers.m` doesn't have it's own tap for button modifiers (like it does for keyboard modifiers) - instead we use the main `ButtonInputReceiver` processing chain to supply `Modifiers.m`. Also see `setModifierPriorityWithActiveListenEvents:` [Oct 2026]
                eventsToListenTo |= (eventsActivelyModifyingCurrently |
                                     eventsPassivelyModifyingCurrently) & kMFEventType_AllButtons;
            }

            /// Apply filters
            eventsToListenTo &= baseModifiableEvents;

        } endof_thing:;

        /// Split the events
        MFEventType tapScrollEvents    = !!(eventsToListenTo & kMFEventType_ScrollWheel);
        MFEventType tappedButtonEvents = eventsToListenTo & kMFEventType_AllButtons;
        MFEventType tapPointerEvents   = !!(eventsToListenTo & kMFEventType_Sensor);

        /// Declare `latest` cache
        static MFEventType lastTapScrollEvents = 0, lastTappedButtonEvents = 0, lastTapPointerEvents = 0;

        /// Toggle taps
        ///     (The methods called here pretty much just call `[MFEventTap enable:forListener:]`. Should we call it directly? [Oct 2026])
        {
            if (lastTapScrollEvents != tapScrollEvents) {
                if (tapScrollEvents) [Scroll startReceiving];
                else                 [Scroll stopReceiving];
                toggled = 1;
            }
            if (lastTappedButtonEvents != tappedButtonEvents) {
                [ButtonInputReceiver listenToButtons: tappedButtonEvents];
                toggled = 1;
            }

            {
                if (!tapPointerEvents && lastTapPointerEvents != tapPointerEvents)
                    [ModifiedDrag deactivateWithCancel: NO];
                else if (tapPointerEvents) { /// We don't check `lastTapPointerEvents != tapPointerEvents` here, because need to call `initializeDragWithDict:` with the new `dragEffect`, whenever the modifications change, even if we don't toggle the tap on/off. For example if you held Button 4 causing dragModification A, and then you you added Button 5, causing dragModification B, this is necessary to not get stuck in A. Once the drag goes from `kMFModifiedInputActivationStateInitialized` to `kMFModifiedInputActivationStateInUse`, then `initializeDragWithDict:` locks in on a `dragEffect` and ignores any further `dragEffect`s that this code sends it. This is kinda confusing and the separation of concerns might be wrong. Credits to Opus 5.5 for finding this and preventing bug [Oct 2026]
                    NSDictionary *dragEffect = [modifications objectForKey: kMFTriggerDrag];
                    mfassert(dragEffect, @"Trying to start modifiedDrag but dragEffect is nil. !modifications: %d\n%@", !modifications, debugStateDescription()); /// There was an old comment here saying we see this sometimes, it said perhaps because of some races, because we got `modifications` in a separate function (Which we no longer do) [Oct 2026].
                    if (dragEffect) [ModifiedDrag initializeDragWithDict: dragEffect];
                }
                if (lastTapPointerEvents != tapPointerEvents) toggled = 1;
            }

        }

        /// Update `last` cache
        lastTapScrollEvents = tapScrollEvents; lastTappedButtonEvents = tappedButtonEvents; lastTapPointerEvents = tapPointerEvents;
    }

    return toggled;
}

@end
