//
// --------------------------------------------------------------------------
// Modifiers.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "Constants.h"

#import "Modifiers.h"
#import "ButtonTriggerGenerator.h"
#import "Remap.h"
#import "ModifiedDrag.h"
#import "DeviceManager.h"
#import "SharedUtility.h"
#import "ModificationUtility.h"
#import <os/signpost.h>
#import "Mac_Mouse_Fix_Helper-Swift.h"

@implementation Modifiers

#pragma mark - Notes



#pragma mark - Terminology

/// Explanation:
/// **Trigger driven** modification -> We listen to triggers. Once a trigger to be modified comes in, we check what the active modiifers are and how we want to modify the trigger based on those
/// **Modifier driven** modification -> We listen to modifier changes. When the modifiers should affect a trigger, then we start listening to the trigger. We use this when it's bad to listen to the trigger all the time.

/// More detailed explanation:
/// The default is *trigger driven* modification.
/// That means only once the trigger comes in, we'll check for active modifiers and then apply those to the incoming trigger.
/// But sometimes its not feasible to always listen for triggers (concretely in the case of modified drags, for performance reasons, you don't want to listen to mouseMoved events all the time)
/// In those cases we'll use *modifier driven* modification.
/// Which means we listen for changes to the active modifiers and when they match a modifications' precondition, we'll initialize the modification components which are modifier driven. (which is only the drag modificaitons at this point)

/// Update:
/// (At the time of writing, this change is not yet reflected in the other comments in this class.)`Modifiers` class now has a single `modifiers` instance var which is updated whenever modifiers change. When some module requests the current modifiers that instance var is simply returned. Before, the modifiers were recompiled each time they were requested. The whole idea of "modifier driven" and "trigger driven" modifications is now not used anymore. All modifications are in effect "modifier driven". This does mean we always listen to keyboard modifiers which is bad. But that will allow us to turn off other event interception dynamically. For example when the user has scrolling enhancements turned off we can turn the scrollwheel eventTap off but then when they hold a modifier for scroll-to-zoom we can dynamically turn the tap on again. Ideally we'd only tap into the keyboard mod event stream if there is such a situation where the keyboard mods can toggle another tap and otherwise turn the keyboard mod tap off. I'll look into that.
///
/// Update:
/// Most of this stuff is outdated now. Now, the MasterSwitch toggles between actively listening to modifiers vs passively retrieving them on request. The active listening simply notifies the SwitchMaster that the modifers changed.

#pragma mark - Storage

static NSMutableDictionary *_modifiers;

#pragma mark - Load

+ (void)load_Manual {
    
    /// This used to be initialize but  that didn't execute until the first mouse buttons were pressed
    /// Then it was load, but that led to '"Mac Mouse Fix Helper" would like to receive keystrokes from any application' prompt. (I think)
    
    if (self == [Modifiers class]) {
        
        /// Init `_modifiers`
        _modifiers = [NSMutableDictionary dictionary];
        
        /// Create keyboard modifier event tap
        CGEventMask mask = CGEventMaskBit(kCGEventFlagsChanged);
        _kbModEventTap = CGEventTapCreate(kCGHIDEventTap, kCGHeadInsertEventTap, kCGEventTapOptionListenOnly, mask, kbModsChanged, NULL);
        CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _kbModEventTap, 0);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);
        CFRelease(runLoopSource);
        
//        /// Enable/Disable eventTap based on Remap.remaps
//        CGEventTapEnable(_kbModEventTap, false); /// Disable eventTap first (Might prevent `_keyboardModifierEventTap` from always being called twice - Nope doesn't make a difference)
//        toggleModifierListening(Remap.remaps);
//
//        /// Re-toggle keyboard modifier callbacks whenever Remap.remaps changes
//        /// TODO:! Test if this works
//        [NSNotificationCenter.defaultCenter addObserverForName:kMFNotifCenterNotificationNameRemapsChanged
//                                                        object:nil
//                                                         queue:nil
//                                                    usingBlock:^(NSNotification * _Nonnull note) {
//
//            DDLogDebug(@"Received notification that remaps have changed");
//            toggleModifierListening(Remap.remaps);
//        }];
    }
}

#pragma mark Toggle listening

static MFModifierPriority _kbModPriority;
static MFModifierPriority _btnModPriority;
static CFMachPortRef _kbModEventTap;

+ (void)setKeyboardModifierPriority:(MFModifierPriority)priority {
    
    /// Sep 2024 - I just saw a crash report in console on CGEventTapEnable(). Here's the interesting part of the stack trace:
    ///     ```
    ///     Exception Type:        EXC_BAD_ACCESS (SIGSEGV)
    ///     Exception Codes:       KERN_INVALID_ADDRESS at 0x0000000000000008
    ///     Exception Codes:       0x0000000000000001, 0x0000000000000008
    ///
    ///     [...]
    ///
    ///     CoreFoundation                             0x191048124 __CFCheckCFInfoPACSignature + 4
    ///     CoreFoundation                             0x190f8b898 CFMachPortGetContext + 28
    ///     SkyLight                                   0x196ba2808 SLEventTapEnable + 68
    ///     Mac Mouse Fix Helper.debug.dylib           0x100a3e100 +[Modifiers setKeyboardModifierPriority:] + 64 (Modifiers.m:95)
    ///     Mac Mouse Fix Helper.debug.dylib           0x100a8f07c SwitchMaster.toggleKbModTap() + 1836 (SwitchMaster.swift:450)
    ///     Mac Mouse Fix Helper.debug.dylib           0x100a8c440 SwitchMaster.helperStateChanged() + 248 (SwitchMaster.swift:184)
    ///     Mac Mouse Fix Helper.debug.dylib           0x100accc0c closure #1 in HelperState.init() + 64 (HelperState.swift:23)
    ///     ```
    ///     Discussion:
    ///         - The helper's build-number was 24405, that was probably the feature-strings-catalog branch - the master branch is currently around 22000 (master around the 3.0.3 release right now.) (I'm writing this on the master branch.)
    ///         - This crash actually appeared like 10 times within 1.5 hours, but I didn't notice anything.
    ///         - This might be a quirk in macOS (I've seen a lot of weird crashes lately on macOS 15.0) or there might be a race condition on the initialization process.
    ///         - We plan to create a unified 'input thread' that handles all the input coming from the user synchronously. Maybe that could help here as well if this is a race-condition.
    ///         - Update (2 days later - 27.09.2024) on one of these crashes (not sure if it was exactly the one I discussed above but the stack-track looked the same) I saw the following timestamps:
    ///             "captureTime" : "2024-09-25 11:57:41.3923 +0200",
    ///             "procLaunch" : "2024-09-25 11:49:20.5558 +0200",
    ///             "uptime" : 94000,
    ///              -> So the process had been running for a while which is a bit weird considering that that the crash happened from an init function. (But maybe I just hadn't used a mouse so far so that's why it was just initing? No clue.)
    ///              -> But also, the stack trace below doesn't have any init functions ... and I really can't think of a way that CGEventTapEnable() could crash other than if the eventTap is NULL or not initialized... Idk. I don't get it. Problem for future Noah.
    ///
    ///         A part of those 10 consecutive crashes that occured within 1.5 hours were the same crash triggered by a different stack trace:
    ///
    ///         ```
    ///         CoreFoundation                             0x191048124 __CFCheckCFInfoPACSignature + 4
    ///         CoreFoundation                             0x190f8b898 CFMachPortGetContext + 28
    ///         SkyLight                                   0x196ba2808 SLEventTapEnable + 68
    ///         Mac Mouse Fix Helper.debug.dylib           0x10110fadc +[Modifiers setKeyboardModifierPriority:] + 80 (Modifiers.m:95)
    ///         Mac Mouse Fix Helper.debug.dylib           0x1011678d4 SwitchMaster.toggleKbModTap() + 272 (SwitchMaster.swift:423)
    ///         Mac Mouse Fix Helper.debug.dylib           0x1011660a0 SwitchMaster.remapsChanged(remaps:) + 476 (SwitchMaster.swift:286)
    ///         Mac Mouse Fix Helper.debug.dylib           0x101166208 @objc SwitchMaster.remapsChanged(remaps:) + 52
    ///         Mac Mouse Fix Helper.debug.dylib           0x1010ec060 +[Remap setRemaps:] + 328 (Remap.m:91)
    ///         Mac Mouse Fix Helper.debug.dylib           0x1010ecfb4 +[Remap reload] + 3748 (Remap.m:242)
    ///         Mac Mouse Fix Helper.debug.dylib           0x1010e33d4 +[Config updateDerivedStates] + 100 (Config.m:153)
    ///         Mac Mouse Fix Helper.debug.dylib           0x1010e3364 +[Config loadFileAndUpdateStates] + 88 (Config.m:133)
    ///         Mac Mouse Fix Helper.debug.dylib           0x1010e8138 __didReceiveMessage_block_invoke + 52 (MFMessagePort.m:178)
    ///         Mac Mouse Fix Helper.debug.dylib           0x1010e75d4 didReceiveMessage + 1732 (MFMessagePort.m:231)
    ///         ```
    ///         -> The build number I saw for these was 24400 and 24402
    ///
    /// Solution ideas:
    ///  1. If this crash is due to some race conditions or logic errors causing `_kbModEventTap` to be uninitialized or NULL here - try to fix that stuff.
    ///  2. Otherwise check whether `_kbModEventTap` is valid and non-NULL before calling CGEventTapEnable.
    ///
    /// Update:
    ///     (03.10.2024)
    ///     I just caught what looks exactly like crash of the second stacktrace (the one that starts with `didReceiveMessage` at MFMessagePort.m:231) in the debugger. `didReceiveMessage` handled the message `@"configFileChanged"`,
    ///         (this is not at line 231 though - not sure what's going on there, I feel like the line numbers in the crash report aren't accurate)
    ///         The build number is 22875, we're still on the master branch, where we recently shipped 3.0.3.
    ///         IIRC, when the crash happened, I was on the AccessibilitySheet in the mainApp, and from that I conclude that the helper didn't have accessibility permissions.
    ///     Tthrough examining the program state, I concluded that most likely, the "Post-check init" in AccessibilityCheck.m had not run. yet, meaning that most of the `load_Manual` methods hadn't been called, leading to all these modules being uninitialized and having many NULL values for their state.
    ///         `_kbModEventTap` was one of those pieces of state that was still NULL, due to not being initialized, yet.
    ///         This explains, why `CGEventTapEnable` crashed, since we're passing NULL to it as the event tap.
    ///     Based on this, I think this crash can happen either:
    ///         1. When the helper is started up without accessibility permissions, (causing it to not do the "Post-check init" at all, since the Post-check init would crash without accessibility permissions.)
    ///             and then receives a message that causes interaction with one of the uninitialized modules (in this case the Modifiers.m module).
    ///         2. When the helper is started up normally, but it receives a message interacting with an uninitialized module,  right after it initializes the message port, but right before it can initialize the module.
    ///             This is sort of a race condition.
    /// Solution Ideas:
    ///     1. We could use traditional `+ initializate` methods instead of ` + load_Manual`. Those would trigger as soon as anybody tries to interact with the module, so we would never interact with an uninitialized module.
    ///         This has downsides:
    ///         - We have non-deterministic initialization order, which might introduce further complicated bugs.
    ///         - We'd then still have to check whether we already have accessibilityAccess before interacting with the "Post-check init" modules, otherwise they'd crash when we try to initialize them. (Trying to create a CGEventTaps without AccessibilityAccess permissions crashes IIRC. This is the whole reason for the "Post-check" init stuff.)
    ///             So I feel like we'd have to do the same amount of 'manual work' just in a different way? Haven't really thought this through.
    ///     2. I think the following would be a comprehensive solution:
    ///         We give all of the modules that the MFMessagePort.m interacts with an 'I am initialized' field. (Or at least give that field to all the "Post-check init" modules which are possibly not yet initialized when the MFMessagePort is already running.)
    ///         Then, inside the MFMessagePort, before interacting with the module, we query whether it's initialized, yet.
    ///         1. If the module is initialized: We interact with it normally
    ///         2. If the module is *not* initialized: We don't interact with the module and send a special 'not-yet-initialized' response back to the message-sender.
    ///             This special response lets the message sender respond to the situation (e.g. by trying to send the message again 500ms second later.)
    ///         On second thought:
    ///             If we do this, there could still be race-conditions and bugs: E.g. when the MFMessagePort interacts with a module that is already initialized, but then that module tries to interact with another module that is not yet initialized - that module could still crash and be buggy.
    ///             To solve this, we could perhaps have a global variable that says 'the Helper process is *entirely* initialized', which will be set after the "Post-check init" has completed. Then, inside the MFMessagePort,
    ///                 we create a minimal whitelist of necessary messages that are handled before the entire Helper is initialized, and all other messages are ignored until the helper process is entirely initialized.
    ///                 Then we need to manually ensure that these explicitly whitelisted messages are pre-init-interaction safe (as described in Solution Idea 3.), but for all the other messages we can just assume that everything is initialized when they are handled.
    ///     3. Make all the 'Post-check init' modules 'pre-init-interaction safe', meaning that, if they're interacted with, before they are initialized, they don't crash, and instead just do nothing or return NULL or something.
    ///         However, I think this is worse than idea `2.`, because:
    ///         1. We'd have to make sure that every entry point of every module that MFMessagePort ever interacts with is 'safe' in this way, which feels like hard to keep track of
    ///         2. Not sure how we'd implement notifying the messageSender that their message was ignored because a module wasn't initialized, yet. If we dont' do this, that could lead to other bugs or inconsistent behaviour.
    ///         3. (Forgot what I wanted to write here.)
    ///     4. We could add an 'accessibilityAccessEnabled state to the SwitchMaster, and make it so that, when there's no accessibilityAccess, the SwitchMaster does not try to enable any CGEventTaps. That would also prevent this specific crash. But I'm not sure this would prevent all related bugs and crashes. I think solution idea 2. seems a bit more robust.
    ///
    ///     Side idea:
    ///         Instead of notiying the message sender that the message was ignored, we could do a system that saves the received messages in a queue until the helper is fully initialized - and then we handle the the messages.
    ///             My intuition is though that this complicates things, and has higher likelyhood to lead to weird unexpected behaviour or bugs.
    ///
    /// TODO: @crash Implement Solution Idea 2.
    
    _kbModPriority = priority;
    CGEventTapEnable(_kbModEventTap, _kbModPriority == kMFModifierPriorityActiveListen);
}

+ (void)setButtonModifierPriority:(MFModifierPriority)priority {
    /// NOTE:
    /// We can't passively retrieve the button mods, so we always need to actively listen to the buttons, even if the modifierPriority is `passive`.
    /// Also we don't only listen to buttons to use them as modifiers but also to use them as triggers.
    /// As a consequence of this, we only toggle off some of the button modifier processing here if the button mods are completely unused and we don't toggle off the button input receiving entirely here at all. That is done by MasterSwitch when there are no effects for the buttons either as modifiers or as triggers.
    _btnModPriority = priority;
    Buttons.useButtonModifiers = _btnModPriority != kMFModifierPriorityUnused;
}

#pragma mark Inspect State
/// At the time of writing we just need this for debugging

+ (MFModifierPriority)kbModPriority {
    return _kbModPriority;
}

+ (MFModifierPriority)btnModPriority {
    return _btnModPriority;
}

#pragma mark Handle modifier change

CGEventRef _Nullable kbModsChanged(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {
    
    
    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
        
        if (type == kCGEventTapDisabledByTimeout) {
            CGEventTapEnable(_kbModEventTap, true);
        }
        
        return event;
    }
    
    /// Get mouse
    
    //    Device *activeDevice = HelperState.shared.activeDevice;
    
    /// Get activeModifiers
    /// Notes:
    /// - We can't use CGEventCreate() here for the source of the keyboard modifers, because the kbMods won't be up-to-date.
    /// -> Idea: This might be because we're using a passive listener eventTap?
    ///     ... Update: No I think CGEventCreate(NULL) uses the `CombinedSessionState` which only updates after the event has passed through the window server, not when we intercept it (I think.) ... Update 2: This comment doesn't make sense – getting flags from CGEventCreate(NULL) is up-to-date, but getting flags from the intercepted `event` doesn't work.
    
    NSUInteger newFlags = flagsFromEvent(event);
    
    /// Check Change
    NSNumber *newFlagsNS = @(newFlags);
    NSNumber *oldFlags = _modifiers[kMFModificationPreconditionKeyKeyboard];
    BOOL didChange = ![oldFlags isEqualToNumber:newFlagsNS];
    
    if (didChange) {
        
        /// Store result
        if (newFlags == 0) {
            [_modifiers removeObjectForKey:kMFModificationPreconditionKeyKeyboard];
        } else {
            _modifiers[kMFModificationPreconditionKeyKeyboard] = newFlagsNS;
        }
        
        /// Notify
//        [ReactiveModifiers.shared handleModifiersDidChangeTo:_modifiers];
        [SwitchMaster.shared modifiersChangedWithModifiers:_modifiers];
    }
    
    /// Return
    return event;
}

+ (void)buttonModsChangedTo:(ButtonModifierState)newModifiers {
    
    /// Debug
    DDLogDebug(@"buttonMods changed to: %@", newModifiers);
    
    /// Assert change
    if (runningPreRelease()) {
        NSArray *oldModifiers = _modifiers[kMFModificationPreconditionKeyButtons];
        assert(![newModifiers isEqualToArray:oldModifiers]);
    }
    
    /// Store
    if (newModifiers.count == 0) {
        [_modifiers removeObjectForKey:kMFModificationPreconditionKeyButtons];
    } else {
        _modifiers[kMFModificationPreconditionKeyButtons] = [newModifiers copy]; /// I think we only copy here so the newModifers != oldModifiers assert works
    }
    
    if (_btnModPriority == kMFModifierPriorityActiveListen) {
        
        /// Also update kbMods before notifying
        if (_kbModPriority == kMFModifierPriorityPassiveUse) {
            updateKBMods(nil);
        }
        
        /// Notify
//        [ReactiveModifiers.shared handleModifiersDidChangeTo:_modifiers];
        [SwitchMaster.shared modifiersChangedWithModifiers:_modifiers];
    }
}

+ (void)__SWIFT_UNBRIDGED_buttonModsChangedTo:(id)newModifiers {
    [self buttonModsChangedTo:newModifiers];
}

/// Helper for modifier change handling

static void updateKBMods(CGEventRef  _Nullable event) {
    
    assert(_kbModPriority == kMFModifierPriorityPassiveUse);
    
    NSUInteger flags = flagsFromEvent(event);
    if (flags == 0) {
        [_modifiers removeObjectForKey:kMFModificationPreconditionKeyKeyboard];
    } else {
        _modifiers[kMFModificationPreconditionKeyKeyboard] = @(flags);
    }
}

static NSUInteger flagsFromEvent(CGEventRef _Nullable event) {
    
    /// When you don't pass in an event sometimes the flags won't be up to date (e.g. from the kbModsChanged eventTap). Also it will be somewhat slower
    
    /// Create event
    BOOL eventWasNULL = NO;
    if (event == NULL) {
        eventWasNULL = YES;
        event = CGEventCreate(NULL);
    }
    
    /// Mask
    /// - Only lets bits 16-23 through
    /// - NSEventModifierFlagDeviceIndependentFlagsMask == 0xFFFF0000 -> it allows bits 16 - 31. But bits 24 - 31 contained weird stuff which messed up the return value and modifiers are only on bits 16-23, so we defined our own mask.
    uint64_t mask = 0xFF0000;
    
    /// We ignore caps lock.
    /// - Otherwise modfifications won't work normally when caps lock is enabled.
    /// - Maybe we need to ignore caps lock in other places, too make this work properly but I don't think so
    /// - We should probably remove this once we update RemapsOverrider to work with subset matches and stuff
    /// -> TODO: Remove capslock ignoring now.
    mask &= ~kCGEventFlagMaskAlphaShift;
    
    /// Get new flags
    NSUInteger flags = CGEventGetFlags(event) & mask;
    
    /// Release
    if (eventWasNULL) CFRelease(event);
    
    /// Return
    return flags;
}

#pragma mark Main Interface

+ (NSDictionary *)modifiersWithEvent:(CGEventRef _Nullable)event {
    
    if (_kbModPriority == kMFModifierPriorityPassiveUse) {
        
        /// If we don't actively listen to kbMods, get the kbMods on the fly
        updateKBMods(event);
    }
    
    return _modifiers;
}
+ (id)__SWIFT_UNBRIDGED_modifiersWithEvent:(CGEventRef _Nullable)event {
    
    return [self modifiersWithEvent:event];
}

#pragma mark Handle mod usage

+ (void)handleModificationHasBeenUsed {
    
    /// Notify active *modifiers* that they have had an effect
    for (NSDictionary *buttonMods in _modifiers[kMFModificationPreconditionKeyButtons]) {
        NSNumber *buttonNumber = buttonMods[kMFButtonModificationPreconditionKeyButtonNumber];
        [Buttons handleButtonHasHadEffectAsModifierWithButton:buttonNumber];
        /// ^ I think we might only have to notify the last button in the sequence (instead of all of them), because all previous buttons should already have been zombified or sth due to consecutive button presses
    }
}

//+ (void)handleModificationHasBeenUsedWithDevice:(Device *)device {
//    /// Convenience wrapper for `handleModifiersHaveHadEffect:activeModifiers:` if you don't have access to `activeModifiers`
//
//    NSDictionary *activeModifiers = [self getActiveModifiersForDevice:device event:nil];
//    [Modifiers handleModificationHasBeenUsedWithDevice:device activeModifiers:activeModifiers];
//}
//+ (void)handleModificationHasBeenUsedWithDevice:(Device *)device activeModifiers:(NSDictionary *)activeModifiers {
//    /// Make sure to pass in device, otherwise this method (in its current form) won't do anything
//
//    if (device != nil) {
//        /// Notify active *modifiers* that they have had an effect
//        for (NSDictionary *buttonPrecondDict in activeModifiers[kMFModificationPreconditionKeyButtons]) {
//            NSNumber *precondButtonNumber = buttonPrecondDict[kMFButtonModificationPreconditionKeyButtonNumber];
//            [Buttons handleButtonHasHadEffectAsModifierWithDevice:device button:precondButtonNumber];
//            /// ^ I think we might only have to notify the last button in the sequence (instead of all of them), because all previous buttons should already have been zombified or sth due to consecutive button presses
//        }
//    }
//}

#pragma mark React

//static void reactToModifierChange(void) {
//    
//    /// Get active modifications and initialize any which are modifier driven
//    
//    /// Debug
//    
//    DDLogDebug(@"MODIFIERS HAVE CHANGED TO - %@", _modifiers);
////    DDLogDebug(@"...ON DEVICE - %@", device);
////    DDLogDebug(@"...CALLED BY %@", [SharedUtility getInfoOnCaller]);
//    
//    /// Get activeModifications
//    NSDictionary *activeModifications = [Remap modificationsWithModifiers:_modifiers];
//    
//    /// Notify ScrollModifiers of modifierChange
//    ///     It needs that to commit to an app in the app switcher when the user releases a button
//    ///     TODO: Make sure this always works, and not only when a ModifieDrag makes the Modifiers class listen to modifierChanged events
//    
////    [ScrollModifiers reactToModiferChangeWithActiveModifications:activeModifications];
//    
//    /// Kill old modifications
//    
//    /// Kill the currently active modifiedDrag if the modifiers have changed since it started.
//    ///     (If there were other modifier driven effects than modifiedDrag in the future, we would also kill them here)
//
//    BOOL modifiedDragIsStillUpToDate = NO;
//    
//    if ([_modifiers isEqual:ModifiedDrag.initialModifiers]) {
//        modifiedDragIsStillUpToDate = YES;
//    } else {
//        [ModifiedDrag deactivate];
//    }
//    
//    /// Init new modifications
//    
//    if (activeModifications) {
//        
//        /// Init modifiedDrag
//        ///    (If there were other modifier driven effects than modifiedDrag in the future, we would also init them here)
//        
//        if (!modifiedDragIsStillUpToDate) {
//        
//            NSMutableDictionary *modifiedDragEffectDict = activeModifications[kMFTriggerDrag]; /// Declared as NSMutableDictionary but probably not actually mutable at this point
//            if (modifiedDragEffectDict) {
//                
//                /// If addMode is active, add activeModifiers to modifiedDragDict
//                ///     See Remap.m -> AddMode for context.
////                if ([modifiedDragEffect[kMFModifiedDragDictKeyType] isEqualToString:kMFModifiedDragTypeAddModeFeedback]) {
////                    modifiedDragEffect = modifiedDragEffect.mutableCopy; /// Make actually mutable
////                    modifiedDragEffect[kMFRemapsKeyModificationPrecondition] = activeModifiers;
////                }
//                
//                /// Determine usage threshold based on other active modifications
//                ///     It's easy to accidentally drag the mouse while trying to scroll so in that case we want a larger usageThreshold to avoid accidental drag activation
//                BOOL largeUsageThreshold = NO;
//                if (activeModifications[kMFTriggerScroll] != nil) {
//                    largeUsageThreshold = YES;
//                }
//                
//                /// Copy modifiers before passing into Modified drag
//                ///     Can't just be reference because we later compare to `_modifiers`
//                /// `deepCopyOf:error:` is actually super slow for some reason. I think `deepMutableCopyOf:` is a little faster? Not sure. Should remove this copying entirely.
////                NSDictionary *copiedModifiers = (NSDictionary *)[SharedUtility deepCopyOf:_modifiers error:nil];
//                NSDictionary *copiedModifiers = (NSDictionary *)[SharedUtility deepMutableCopyOf:_modifiers];
//                
//                /// Init modifiedDrag
//                [ModifiedDrag initializeDragWithDict:modifiedDragEffectDict initialModifiers:copiedModifiers];
//            }
//        }
//    }
//}

@end
