//
// --------------------------------------------------------------------------
// Modifiers.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import "Device.h"
#import "DisableSwiftBridging.h"

NS_ASSUME_NONNULL_BEGIN

@interface Modifiers : NSObject

/// On `modifierPriority`
///
///  Naming of this enum and it's cases is pretty bad.
///
///  modifierPriority has 3 cases
///  - 1. `activeListen` -> We want to proactively listen to modifier changes and cache the result and also trigger some side effects
///  - 2. `passiveUse` -> Determine the modifierState on the fly as requests for the modifier state come in
///  - 3. `unused` -> We don't want to use this __type__ of modifier at all
///
///  There are currently 2 __types__ of modifiers: buttonModifers and keyboardModifiers
///  The buttonModifiers can't be determined on the fly so they can't be used with `passiveUse`. We always actively listen to them or don't listen to them at all.
///
///  Motivation:
///  - For kbMods we usually want to use them passively so we don't have to use CPU everytime the user presses a modifierKey. But in certain situations, listening actively to kbMods gives us the opportunity to turn off another eventTap dynamically. Example is if the user turns off scrolling enhancements but still wants to use Command-Scroll to zoom. In that case we could then turn on the scrollEventTap only while the Command key is held.
///  - If the modifier type is `unused` we can also optimize things further

typedef NSMutableArray<NSDictionary<NSString *, NSNumber *> *> * ButtonModifierState;

typedef enum {
    kMFModifierPriorityUnused,
    kMFModifierPriorityPassiveUse,
    kMFModifierPriorityActiveListen,
} MFModifierPriority;

+ (void)load_Manual;

//+ (NSDictionary *)getActiveModifiersForDevice:(Device *)device event:(CGEventRef _Nullable) event;

+ (void)setKeyboardModifierPriority:(MFModifierPriority)priority;
+ (void)setButtonModifierPriority:(MFModifierPriority)priority;

+ (MF_SWIFT_UNBRIDGED(NSDictionary *))modifiersWithEvent:(CGEventRef _Nullable)event NS_REFINED_FOR_SWIFT;

+ (void)buttonModsChangedTo:(MF_SWIFT_UNBRIDGED(ButtonModifierState))newModifiers NS_REFINED_FOR_SWIFT;

+ (void)handleModificationHasBeenUsed;

+ (MFModifierPriority)kbModPriority;
+ (MFModifierPriority)btnModPriority;

//+ (void)handleModificationHasBeenUsedWithDevice:(Device *_Nullable)device;
//+ (void)handleModificationHasBeenUsedWithDevice:(Device *_Nullable)device activeModifiers:(NSDictionary *)activeModifiers;


@end

NS_ASSUME_NONNULL_END
