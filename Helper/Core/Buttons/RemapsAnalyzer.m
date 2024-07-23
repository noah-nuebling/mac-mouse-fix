//
// --------------------------------------------------------------------------
// RemapsAnalyzer.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "RemapsAnalyzer.h"
#import "Remap.h"
#import "SharedUtility.h"
#import "Modifiers.h"
#import "Mac_Mouse_Fix_Helper-Swift.h"

@implementation RemapsAnalyzer

#pragma mark - Notes

/// - This used to be called ButtonLandscapeAssessor
///
/// - At the time of writing, this is the only part of the live input processing code (aka scroll handling and button handling) which is not optimized. Optimizing this could shave off another 10-20%  off the CPU usage when clicking a button.
/// - We could optimize this by caching the results in a dictionary and deleting the cache when the remaps are reloaded.

#pragma mark - Caches

+ (void)reload {
    /// Reset caches
    /// NOTES:
    /// - `_minButtonInModificationsCache` doesn't depend on remaps and doesn't really have to ever be reset I think. But I guess it doesn't hurt to reset it once in a while.
    [_minButtonInModificationsCache removeAllObjects];
}

static NSMutableDictionary *_minButtonInModificationsCache;

#pragma mark - For SwitchMaster
/// Most of the remapsAnalysis methods used for SwitchMaster are still in SwitchMaster.swift. Should migrate them here and cache the slow ones at some point.

+ (BOOL)modificationsModifyButtons:(NSDictionary *)modifications maxButton:(MFMouseButtonNumber)maxButton {
    
    assert(modifications != nil);
    
    /// 1. v Old caching method
//    NSInteger minInModifications = minButtonInModifications(modifications);
//    return minInModifications <= maxButton;
    
    /// 2. v New direct method
    ///     We tried caching here but it doesn't seem to speed things up
    for (NSObject *key in modifications) {
        if ([key isKindOfClass:NSNumber.class]) {
            
            NSNumber *btn = (NSNumber *)key;
            NSInteger button = btn.integerValue;
            
            if (button <= maxButton) {
                return YES;
            }
        }
    }
    
    return NO;
}

static NSInteger minButtonInModifications(NSDictionary *modifications) {
    
    assert(false);
    return 0;
    
    if (_minButtonInModificationsCache == nil) {
        _minButtonInModificationsCache = [NSMutableDictionary dictionary];
    }
    
    NSNumber *fromCache = _minButtonInModificationsCache[modifications];
    
    if (fromCache != nil) {
        return fromCache.integerValue;
    } else {
        
        NSInteger min = NSIntegerMax;
        
        for (NSObject *key in modifications) {
            if ([key isKindOfClass:NSNumber.class]) {
                
                NSNumber *btn = (NSNumber *)key;
                NSInteger button = btn.integerValue;
                
                if (button < min) {
                    min = button;
                }
            }
        }
        
        _minButtonInModificationsCache[modifications] = @(min);
        
        return min;
    }
}

//func modificationModifiesButtons(modification: NSDictionary?, maxButton: Int32) -> Bool {
//
//    /// Return true if the modification modifies any button `<=` maxButton
//
//    if let modification = modification {
//
//        for element in modification {
//
//            guard let btn = element.key as? NSNumber else { continue }
//
//            let doesModify = btn.int32Value <= maxButton
//            if doesModify { return true }
//        }
//    }
//
//    return false
//}

+ (BOOL)modificationsModifyScroll:(NSDictionary *)modifications {
    
    /// NOTES:
    /// - This code was originally written in Swift in SwitchMaster. Using the `kMFTriggerScroll` brought a big a big performance penalty for bridging the string to Swift.
    /// - Using `CFDictionaryContainsKey(dict, key)` instead of `dict[key] != nil` because I'm pretty sure it's faster.
    
    assert(modifications != nil);
    return CFDictionaryContainsKey((__bridge CFDictionaryRef)modifications, (__bridge CFStringRef)kMFTriggerScroll);
}

+ (BOOL)modificationsModifyPointing:(NSDictionary *)modifications {
    assert(modifications != nil);
    return CFDictionaryContainsKey((__bridge CFDictionaryRef)modifications, (__bridge CFStringRef)kMFTriggerDrag);
}

//fileprivate func modificationModifiesScroll(_ modification: NSDictionary?) -> Bool {
//    return modification?.object(forKey: kMFTriggerScroll) != nil
//}
//
//fileprivate func modificationModifiesPointing(_ modification: NSDictionary?) -> Bool {
//    return modification?.object(forKey: kMFTriggerDrag) != nil
//}

#pragma mark - For Buttons.swift
///
///
///
#pragma mark Main assess func
/// Primarily used for `[ButtonTriggerHandler + handleButtonTriggerWithButton:...]` to help figure out when to fire clickEffects
/// `activeModifiers` are the active modifiers including `button` (We've since removed this argument since we didn't use it)
/// `activeModifiersActingOnThisButton` are the active modifiers with `button` filtered out
/// `swizzler` is a block taking `remaps` and `activeModifiersActingOnThisButton` and returning what the effective remaps acting on the button are.
///     Should normally pass `[Utility Transform + swizzler]` I think other stuff will break if we use sth else.
+ (void)assessMappingLandscapeWithButton:(NSNumber *)button
                                   level:(NSNumber *)level
         modificationsActingOnThisButton:(NSDictionary *)modificationsActingOnThisButton
                                  remaps:(NSDictionary *)remaps
                           thisClickDoBe:(BOOL *)clickActionOfThisLevelExists
                            thisDownDoBe:(BOOL *)effectForMouseDownStateOfThisLevelExists
                             greaterDoBe:(BOOL *)effectOfGreaterLevelExists {
    
    *clickActionOfThisLevelExists = modificationsActingOnThisButton[button][level][kMFButtonTriggerDurationClick] != nil;
    *effectForMouseDownStateOfThisLevelExists = effectExistsForMouseDownState(button, level, remaps, modificationsActingOnThisButton);
    *effectOfGreaterLevelExists = effectOfGreaterLevelExistsFor(button, level, remaps, modificationsActingOnThisButton);
}

#pragma mark Helper for assess

static BOOL effectExistsForMouseDownState(NSNumber *button, NSNumber *level, NSDictionary *remaps, NSDictionary *modificationsActingOnThisButton) {
    BOOL holdActionExists = modificationsActingOnThisButton[button][level][kMFButtonTriggerDurationHold] != nil;
    BOOL usedAsModifier = isModifier(button, level, remaps);
    
    return holdActionExists || usedAsModifier;
}
static BOOL isModifier(NSNumber *button, NSNumber *level, NSDictionary *remaps) {
    /// TODO: Check if this still works after modification precondition refactor
        /// Debugged this, now it seems to work fine
    
    /// ^ I feel like, now that the button preconditions are ordered, we might wanna check if the sequence of buttons in the activeModifiers are the start (or the whole) of a sequence of buttons in some modification precondition. So if there is button Sequence in some button precondition that can still be reached based on the current state. (Right now we're just checking if the `button` is any part of any modification precondition's button sequence) But I guess if you consider that the user can let go of buttons, then any buttonSequence can "still be reached". And if we don't consider letting go of buttons (which probably doesn't make sense?) then it would be much more involved to determine this stuff.... So I think the current solution is probably the most practical.
    
    NSDictionary *buttonPrecondition = @{
        kMFButtonModificationPreconditionKeyButtonNumber: button,
        kMFButtonModificationPreconditionKeyClickLevel: level
    };
    for (NSDictionary *modificationPrecondition in remaps.allKeys) {
        if ([((NSArray *)modificationPrecondition[kMFModificationPreconditionKeyButtons]) containsObject:buttonPrecondition]) {
            return YES;
        }
    }
    
    return NO;
}

static BOOL effectOfGreaterLevelExistsFor(NSNumber *button, NSNumber *level, NSDictionary *remaps, NSDictionary *modificationsActingOnThisButton) {
    
    return maxLevelForButton(button, remaps, modificationsActingOnThisButton) > level.intValue;
}

static NSInteger maxLevelForButton(NSNumber *button, NSDictionary *remaps, NSDictionary *modificationsActingOnThisButton) {
    NSInteger a = maxLevelForButtonInModifications(button, modificationsActingOnThisButton);
    NSInteger b = maxLevelForButtonInModificationPreconditions(button, remaps);
    return MAX(a, b);
}

static NSInteger maxLevelForButtonInModifications(NSNumber *button, NSDictionary *modificationsActingOnThisButton) {
     
    /// Find greates level of any effect for `button` in modifications
    /// Returns 0 if no effect is found for   `button` in modifications
    
    NSInteger maxLvl = 0;
    
    for (NSNumber *thisLevelNS in ((NSDictionary *)modificationsActingOnThisButton[button]).allKeys) {
        NSInteger thisLevel = thisLevelNS.integerValue;
        if (thisLevel > maxLvl) {
            maxLvl = thisLevel;
        }
    }
    
    return maxLvl;
}

static NSInteger maxLevelForButtonInModificationPreconditions(NSNumber *button, NSDictionary *remaps) {
    
    /// Find greatest level of any buttonElement in any buttonSequence of any modificationPrecondition where the buttonNumber of the buttonElement is equal `button`
    /// Returns 0 if no modificationPrecondition is found. (Otherwise the lowest level is 1)
    
    /// \discussion We (were) passing in `activeModifiers` even though we don't need it. Why is that? Hints towards us messing sth up in some refactor.
    
    NSInteger maxLvl = 0;
    
    for (NSDictionary *modificationPrecondition in remaps.allKeys) {
        
        /// Since button preconditions are ordered now, we maybe should check if there exists a modificationPreconditions' buttonSequence that can still be reached by adding `button` to the button sequence in the `activeModifiers`? Not sure though. I guess any sequence can be reached, by taking away some buttons first?
        ///     Edit: I think we're taking that into account. We're checking all elements of the buttonSequence, no matter how they can be reached.
        ///         TODO: remove this comment
        
        NSUInteger buttonIndex = NSNotFound;
        
        NSArray *buttonMods = modificationPrecondition[kMFModificationPreconditionKeyButtons];
        for (int i = 0; i < buttonMods.count; i++) {
            BOOL found = [buttonMods[i][kMFButtonModificationPreconditionKeyButtonNumber] isEqualToNumber: button];
            if (found) buttonIndex = i;
        }
        
        /// v Old method using `indexesOfObjectsPassingTest:` was pretty slow
//        [(NSArray *)modificationPrecondition[kMFModificationPreconditionKeyButtons] indexesOfObjectsPassingTest:^BOOL(NSDictionary *_Nonnull dict, NSUInteger idx, BOOL * _Nonnull stop) {
//            return [dict[kMFButtonModificationPreconditionKeyButtonNumber] isEqualToNumber:button];
//        }];
        
        if (buttonIndex == NSNotFound) continue;
        
        NSNumber *precondLvlNS = modificationPrecondition[kMFModificationPreconditionKeyButtons][buttonIndex][kMFButtonModificationPreconditionKeyClickLevel];
        NSUInteger precondLvl = precondLvlNS.unsignedIntegerValue;
        if (precondLvl > maxLvl) {
            maxLvl = precondLvl;
        }
    }
    return maxLvl;
}

#pragma mark Other analysis

/// Used by `ButtonTriggerGenerator` to reset the click cycle, if we know the button can't be used this click cycle anyways.
///     Later in the control chain - in ButtonTriggerHandler - the assessMappingLandscapeWithButton:... method is called again. This is probably redundant, as we could just store the result of the first call somehow. But if it's fast enough, who cares
///
///     Edit: Currently refactoring ButtonInput processing. As far as I can tell, this is only used once (even before the refactor)

//+ (BOOL)buttonCouldStillBeUsedThisClickCycle:(Device *)device button:(NSNumber *)button level:(NSNumber *)level {
//
//    NSDictionary *remaps = Remap.remaps;
//    NSDictionary *modifiersActingOnThisButton = [Modifiers getActiveModifiersForDevice:&device filterButton:button event:nil];
//    NSDictionary *remapsActingOnThisButton = RemapsOverrider.swizzler(remaps, modifiersActingOnThisButton);
//
//    BOOL clickActionOfThisLevelExists;
//    BOOL effectForMouseDownStateOfThisLevelExists;
//    BOOL effectOfGreaterLevelExists;
//    [self assessMappingLandscapeWithButton:button
//                                     level:level
//           modificationsActingOnThisButton:remapsActingOnThisButton
//                                    remaps:remaps
//                             thisClickDoBe:&clickActionOfThisLevelExists
//                              thisDownDoBe:&effectForMouseDownStateOfThisLevelExists
//                               greaterDoBe:&effectOfGreaterLevelExists];
////    NSDictionary *info = @{
////        @"devID": devID,
////        @"button": button,
////        @"level": level,
////        @"clickActionOfThisLevelExists": @(clickActionOfThisLevelExists),
////        @"effectForMouseDownStateOfThisLevelExists": @(effectForMouseDownStateOfThisLevelExists),
////        @"effectOfGreaterLevelExists": @(effectOfGreaterLevelExists),
////        @"remaps": remaps,
////    };
////    DDLogDebug(@"CHECK IF EFFECT OF EQUAL OR GREATER LEVEL EXISTS - Info: %@", info);
//
//    return clickActionOfThisLevelExists || effectForMouseDownStateOfThisLevelExists || effectOfGreaterLevelExists;
//}

+ (NSInteger)maxLevelForButton:(NSNumber *)button remaps:(NSDictionary *)remaps modificationsActingOnThisButton:(NSDictionary *)modificationsActingOnThisButton {
    
    return maxLevelForButton(button, remaps, modificationsActingOnThisButton);
}

/// Used by `ButtonTriggerHandler` to determine `MFEventPassThroughEvaluation`
///     Noah from future: Why aren't we reusing `assessMappingLandscapeWithButton:` here?
///         -> I guess it's because we don't care about most of the arguments which have to be provided to `assessMappingLandscapeWithButton:`
///             For example we don't care about clickLevel and to use `assessMappingLandscapeWithButton:` we'd have to call it for each clickLevel and stuff.
///     Noah from even more in future: Maybe we should refactor the code for  `MFEventPassThroughEvaluation` and call this function from ButtonTriggerGenerator directly? As it is we're passing the `MFEventPassThroughEvaluation` through like 3 classes which is a little ugly.
+ (BOOL)effectExistsForButton:(NSNumber *)button remaps:(NSDictionary *)remaps modificationsActingOnButton:(NSDictionary *)modificationsActingOnButton {
    
    /// Check if there is a direct effect for button
    BOOL hasDirectEffect = modificationsActingOnButton[button] != nil;
    if (hasDirectEffect) {
        return YES;
    }
    /// Check if button has effect as modifier
    ///      Noah from future: Maybe we should only check for button preconds with a higher clickLevel than current?
    ///          -> But maybe that wouldn't make a diff because clickLevel is reset when `buttonCouldStillBeUsedThisClickCycle:` returns true? (I think)
    ///          (I feel like we probs thought this through when we wrote it I just don't understand it anymore)
    for (NSDictionary *modificationPrecondition in remaps.allKeys) {
        if ([SharedUtility button:button isPartOfModificationPrecondition:modificationPrecondition]) {
            return YES;
        }
    }
    
    return NO;
}

@end
