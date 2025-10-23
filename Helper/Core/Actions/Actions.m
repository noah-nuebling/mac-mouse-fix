//
// --------------------------------------------------------------------------
// Actions.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "Actions.h"
#import "TouchSimulator.h"
#import "SharedUtility.h"
#import "ModificationUtility.h"
#import "HelperUtility.h"
#import "Modifiers.h"
#import "Remap.h"
#import "Constants.h"

#import "Logging.h"
/*
@import Carbon;
#import "CGSHotKeys.h"
*/
#import "SymbolicHotKeys.h"
#import <Carbon/Carbon.h>

@implementation Actions

+ (void)executeActionArray:(NSArray *)actionArray phase:(MFActionPhase)phase {
    
    DDLogDebug(@"Executing action array: %@, phase: %@", actionArray, @(phase));
    
    if (phase == kMFActionPhaseEnd) {
        return; /// TODO: Actually implement actions with different phases
    }
               
    for (NSDictionary *actionDict in actionArray) {
        
        MFStringConstant actionType = actionDict[kMFActionDictKeyType];
    
        if ([actionType isEqualToString:kMFActionDictTypeSymbolicHotkey]) {
            
            MFSymbolicHotkey shk = ((NSNumber *)actionDict[kMFActionDictKeyGenericVariant]).intValue;
            [SymbolicHotKeys post:(CGSSymbolicHotKey)shk];
            
        } else if ([actionType isEqualToString:kMFActionDictTypeNavigationSwipe]) {
            
            /// Universal Back and Forward
            ///     See `Universal Back and Forward.md`
            ///     Implementation Notes:
            ///         - This is similar to the hack in Scroll.m where we zoom more for `org.chromium.Chromium` and other chromium browsers.
            ///         - HACK: [Aug 2025] We consider this a 'hack' since we're getting the bundleID of the app under the mouse pointer in a slow, hacky way without any caching, since we don't have a 'proper' way to doing app-specific stuff, yet. (Began working on that in the`app-specific` branch IIRC)
            ///     TODOs:
            ///         - TODO: Rename the kMF constants to reflect that this is about going Back and Forward, not about navigationSwipes.
            ///             [Aug 2025] Not doing that for the 3.0.6 hotfix, since it would require increasing the config-version, and I'm too lazy for that.
            ///     Bugs:
            ///         - macOS `Mouse Shortcuts` interfere if we simulate MB 4/5.
            ///             See: https://github.com/noah-nuebling/mac-mouse-fix/issues/1521
            ///             Solution Ideas: - Send at different eventTap - User feedback ala Swish - Simulate navigationSwipes where possible - Some other hacks to keep macOS from diverting the events.
            ///
            
            /// Dispatch to mainThread
            ///     [Aug 2025] Run on the mainThread since `MFEmulateNSMenuItemRemapping()` uses TIS API stuff which wants to run on the mainThread. (And this method is called by Buttons.swift which seems to call on the mainThread for some triggers (observed: .release), but calls on `com.nuebling.mac-mouse-fix.buttons` queue for other triggers (observed: .levelExpired))
            ///         Idea: Perhaps we could optimize by only dispatching to mainThread if we really end up calling TIS APIs.
            dispatch_async(dispatch_get_main_queue(), ^{
            
                #define fail() ({ assert(false); goto endof_universalBackForward; })       /** [Aug 2025] We'll catch the failures during development, so simple is fine */
                {
                    NSString *dirString = actionDict[kMFActionDictKeyGenericVariant];
                    BOOL isleft  = [dirString isEqualToString: kMFNavigationSwipeVariantLeft];
                    BOOL isright = [dirString isEqualToString: kMFNavigationSwipeVariantRight];
                
                    if (phase == kMFActionPhaseEnd)     fail(); /// [Aug 2025] We'll have to update this when we support separate handling of button-up and button-down events
                    if (!(isleft || isright))           fail(); /// [Aug 2025] `kMFNavigationSwipeVariantUp` and `kMFNavigationSwipeVariantDown` are no longer supported (and they were never used AFAIK. `kMFActionDictTypeNavigationSwipe` serves as 'Universal Back and Forward' now. (We should rename it.)
                    
                    /// Choose the `bfmethod`
                    ///     Mnemonic: (method) for going (b)ack and (f)orward
                    
                    NSString *bundleID = [HelperUtility appUnderMousePointerWithEvent: NULL].bundleIdentifier; /// [Aug 2025] Should we query frontmost app or app-under-mouse-pointer? I think navigation swipes only work when the app is frontmost *and* the mouse pointer is over the desired view. Meanwhile the keyboard shortcuts dont depend on mouse pointer position.
                    #define isbundle(bundleid)  [bundleID hasPrefix: @bundleid]                             /** [Aug 2025] Using `hasPrefix:` to also catch other release channels like "com.google.Chrome.canary", or maybe forks that didn't bother to change the bundleID. (?) */
                    {
                        /// Fallback if we can't retrieve a bundleID
                        ///     Note: [Aug 2025] Not sure when this occurs. Maybe non-app executables or certain cross-platform apps? `bfmethod_mouseButton` seems most useful.
                        if (bundleID == nil || bundleID.length == 0)    goto bfmethod_mouseButton;
                        
                        /// navigationSwipe overrides from linearmouse
                        ///     Note: linearmouse uses navigationSwipes for Firefox, but Firefox supports MB 4/5 now. (See `https://stackoverflow.com/a/68532003`). [Aug 2025]
                        if (isbundle("com.operasoftware.Opera"))        goto bfmethod_navigationSwipe;
                        if (isbundle("com.binarynights.ForkLift"))      goto bfmethod_navigationSwipe;
                        
                        /// From mac-mouse-fix issues
                        if (isbundle("org.zotero.zotero"))              goto bfmethod_commandBracket;   /// Behaves like `bfmethod_commandBracket` in Preview when viewing PDFs. [Aug 2025]
                        if (isbundle("com.apple.systempreferences"))    goto bfmethod_commandBracket;
                        if (isbundle("com.apple.AppStore"))             goto bfmethod_commandBracket;
                        if (isbundle("com.adobe.Acrobat.Pro"))          goto bfmethod_commandLeftRightArrow; /// In Acrobat, `bfmethod_commandLeftRightArrow` behaves like `bfmethod_commandBracket` in Preview. Seems pretty useful. [Aug 2025]
                        
                        /// Other
                        if (isbundle("dev.warp.Warp"))                  goto bfmethod_commandBracket;
                        
                        /// Other Apple
                        ///     Note: None of the modern Catalyst/SwiftUI Apple apps support navigationSwipes. Perhaps `bfmethod_commandBracket` should be the 'default' for them instead of `bfmethod_navigationSwipe`.
                        if (isbundle("com.apple.Music"))                goto bfmethod_commandBracket;
                        if (isbundle("com.apple.iCal"))                 goto bfmethod_commandLeftRightArrow;
                        if (isbundle("com.apple.AddressBook"))          goto bfmethod_commandBracket;
                        if (isbundle("com.apple.Notes"))                goto bfmethod_optionCommandBracket;
                        if (isbundle("com.apple.freeform"))             goto bfmethod_optionCommandBracket;
                        if (isbundle("com.apple.TV"))                   goto bfmethod_commandBracket;
                        if (isbundle("com.apple.iBooksX"))              goto bfmethod_commandBracket;
                        if (isbundle("com.apple.Preview"))              goto bfmethod_commandBracket;
                    
                        /// Default
                        if (isbundle("com.apple."))                     goto bfmethod_navigationSwipe; /// Default to navigation swipes for Apple apps
                        else                                            goto bfmethod_mouseButton;     /// Default to MB 4/5 simulation for non-apple apps
                    }
                    #undef isbundle
                    
                    /// Define the `bfmethods`
                    
                    #define bfmethod(bfmethod_label) \
                        goto endof_bfmethods; bfmethod_label: {}; DDLogDebug(@"Actions.m: NavigationSwipe: Posting " #bfmethod_label);
                    {
                        bfmethod(bfmethod_mouseButton) {
                            if (isleft)     [ModificationUtility postMouseButtonClicks: 4 nOfClicks: 1];
                            else            [ModificationUtility postMouseButtonClicks: 5 nOfClicks: 1];
                        }
                        bfmethod(bfmethod_navigationSwipe) {
                            if (isleft)     [TouchSimulator postNavigationSwipeEventWithDirection: kIOHIDSwipeLeft];
                            else            [TouchSimulator postNavigationSwipeEventWithDirection: kIOHIDSwipeRight];
                        }
                        bfmethod(bfmethod_commandBracket) {
                            MFVKCAndFlags *shortcut = MFEmulateNSMenuItemRemapping((isleft ? kVK_ANSI_LeftBracket : kVK_ANSI_RightBracket), kCGEventFlagMaskCommand);
                            postKeyboardShortcut(shortcut.vkc,  (CGSModifierFlags)shortcut.modifierMask);
                        }
                        bfmethod(bfmethod_commandLeftRightArrow) {
                            if (isleft)     postKeyboardShortcut(kVK_LeftArrow,  (CGSModifierFlags)kCGEventFlagMaskCommand);
                            else            postKeyboardShortcut(kVK_RightArrow, (CGSModifierFlags)kCGEventFlagMaskCommand);
                        }
                        bfmethod(bfmethod_optionCommandBracket) {
                            MFVKCAndFlags *shortcut  = MFEmulateNSMenuItemRemapping((isleft ? kVK_ANSI_LeftBracket : kVK_ANSI_RightBracket), (kCGEventFlagMaskAlternate|kCGEventFlagMaskCommand));
                            postKeyboardShortcut(shortcut.vkc,  (CGSModifierFlags)shortcut.modifierMask);
                        }
                    }
                    endof_bfmethods: {}
                    #undef bfmethod
                }
                endof_universalBackForward: {}
                #undef fail
            });
            
        } else if ([actionType isEqualToString:kMFActionDictTypeSmartZoom]) {
            
            [TouchSimulator postSmartZoomEvent];
            
        } else if ([actionType isEqualToString:kMFActionDictTypeKeyboardShortcut]) {
            
            NSNumber *keycode = actionDict[kMFActionDictKeyKeyboardShortcutVariantKeycode];
            NSNumber *flags = actionDict[kMFActionDictKeyKeyboardShortcutVariantModifierFlags];
            postKeyboardShortcut(keycode.intValue, flags.intValue);
            
        } else if ([actionType isEqualToString:kMFActionDictTypeSystemDefinedEvent]) {
            
            NSNumber *type = actionDict[kMFActionDictKeySystemDefinedEventVariantType];
            NSNumber *flags = actionDict[kMFActionDictKeySystemDefinedEventVariantModifierFlags];
            
            postSystemDefinedEvent(type.unsignedIntValue, flags.unsignedIntValue);
            
        } else if ([actionType isEqualToString:kMFActionDictTypeMouseButtonClicks]) {
            
            NSNumber *button = actionDict[kMFActionDictKeyMouseButtonClicksVariantButtonNumber];
            NSNumber *nOfClicks = actionDict[kMFActionDictKeyMouseButtonClicksVariantNumberOfClicks];
            [ModificationUtility postMouseButtonClicks:button.intValue nOfClicks:nOfClicks.intValue];
        
        } else if ([actionType isEqualToString:kMFActionDictTypeAddModeFeedback]) {
            NSMutableDictionary *payload = ((NSMutableDictionary *)actionDict.mutableCopy);
            [payload removeObjectForKey:kMFActionDictKeyType];
            /// ^ Payload has the kMFRemapsKeyTrigger and kMFRemapsKeyModificationPrecondition keys.
            /// It is almost a valid remaps table entry.
            /// All that the main app has to do with the payload in order to make it a valid entry of the remap table's
            ///  dataModel is to add the kMFRemapsKeyEffect key and corresponding values
            [Remap sendAddModeFeedback:payload];
            
        }
    }
}

#pragma mark - System defined events

static void postSystemDefinedEvent(MFSystemDefinedEventType type, NSEventModifierFlags modifierFlags) {
    /// The timestamps, and location, and even the keyUp event seem to be unnecessary. Just trying stuff to try and fix weird bug where music is louder for a few seconds after starting it with a systemDefinedEvent.
    ///     Edit: The bug where the music is too loud for a few seconds also happens when using the keyboard, so the issue is not on our end.
    
    CGEventTapLocation tapLoc = kCGSessionEventTap;
    
    NSPoint loc = NSEvent.mouseLocation;
    
    NSInteger data = 0;
    data = data | kMFSystemDefinedEventBase;
    data = data | (type << 16);
    
    NSInteger downData = data;
    NSInteger upData = data | kMFSystemDefinedEventPressedMask;
    
    /// Post key down
    
    NSTimeInterval ts = [ModificationUtility nsTimeStamp];
    NSEvent *e = [NSEvent otherEventWithType:14 location:loc modifierFlags:modifierFlags timestamp:ts windowNumber:-1 context:nil subtype:8 data1:downData data2:-1];
    
    CGEventPost(tapLoc, e.CGEvent); /// `.CGEvent` "Returns an autoreleased CGEvent" -> Make sure there's an autoreleasepool when calling this!
    
    /// Post key up
    ts = [ModificationUtility nsTimeStamp];
    e = [NSEvent otherEventWithType:14 location:loc modifierFlags:modifierFlags timestamp:ts windowNumber:-1 context:nil subtype:8 data1:upData data2:-1];
    
    CGEventPost(tapLoc, e.CGEvent);
}

#pragma mark - Keyboard shortcuts

static void postKeyboardShortcut(CGKeyCode keyCode, CGSModifierFlags modifierFlags) {
    
    DDLogDebug(@"postKeyboardShortcut: Posting shortcut with %@", vardesc(keyCode, modifierFlags));
    
    CGEventTapLocation tapLoc = kCGSessionEventTap;

    /// Create key events
    CGEventRef keyUp = CGEventCreateKeyboardEvent(NULL, keyCode, false);
    CGEventRef keyDown = CGEventCreateKeyboardEvent(NULL, keyCode, true);
    CGEventSetFlags(keyDown, (CGEventFlags)modifierFlags);
    CGEventSetFlags(keyUp, (CGEventFlags)modifierFlags);
    
    /// Fix up keyboard type [Aug 2025]
    ///     Explanation: [Aug 2025] When I attach 2 keyboards to my Mac, one ANSI, one JIS, then `CGEventCreateKeyboardEvent()` seems to not match the keyboard type retrieved any other way we know (MFKeyboardTypeCurrent(), LMGetKbdType(), LMGetKbdLast(), CGEventSourceCreate()).
    ///         Even when you pass a CGEventSource with the desired keyboardType, CGEventCreateKeyboardEvent() just overrides it. It seems like a bug in CoreGraphics.
    ///         In practise this messes up the 'Universal Back and Forward' feature we're building, cause `MFEmulateNSMenuItemRemapping()` assumes `MFKeyboardTypeCurrent()` when calculating the vkc that will trigger the shortcut.
    ///         Observed on: macOS 15.5, 2018 Mac Mini, [Aug 2025]
    ///
    ///     ! Keep this when merging with __EventLoggerForBrad__.
    CGEventSetIntegerValueField(keyDown, kCGKeyboardEventKeyboardType, MFKeyboardTypeCurrent()); /// Keep in sync with `MFEmulateNSMenuItemRemapping()` to make 'Universal Back and Forward' feature work [Aug 2025]
    CGEventSetIntegerValueField(keyUp,   kCGKeyboardEventKeyboardType, MFKeyboardTypeCurrent());
    
    /// Create modifier restore event
    ///  (Restoring original modifier state the way `postKeyboardEventsForSymbolicHotkey()` does leads to issues with triggering Spotlight)
    ///      (Sometimes triggered Siri instead)
//    CGEventFlags originalModifierFlags = CGEventGetFlags(CGEventCreate(NULL));
    CGEventRef modEvent = CGEventCreate(NULL);
//    CGEventSetFlags(modEvent, originalModifierFlags);
    
    /// Send key events
    CGEventPost(tapLoc, keyDown);
    CGEventPost(tapLoc, keyUp);
    CGEventPost(tapLoc, modEvent);
    
    CFRelease(keyDown);
    CFRelease(keyUp);
    CFRelease(modEvent);
}

@end
