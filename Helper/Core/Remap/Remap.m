//
// --------------------------------------------------------------------------
// Remap.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "Remap.h"
#import "ModificationUtility.h"
#import "SharedUtility.h"
#import "ButtonTriggerGenerator.h"
#import "Actions.h"
#import "Modifiers.h"
#import "ModifiedDrag.h"
#import "NSArray+Additions.h"
#import "NSDictionary+Additions.h"
#import "Constants.h"
#import "Config.h"
#import "MFMessagePort.h"
#import "Mac_Mouse_Fix_Helper-Swift.h"
#import "RemapSwizzler.h"

@implementation Remap

#pragma mark - Notes

/// On Terminology
/// This used to be called `TransformationManager`. Renamed to `Remap` to unify terminology.
/// Desired Terminology: The `remaps` are a map from `modifiers` -> `modifications`, where a `modification` is itself a map from `trigger ` -> `effect`. More on this in RemapSwizzler.swift
///

#pragma mark - Swizzled

static NSMutableDictionary *_swizzleCache = nil;

+ (NSDictionary * _Nullable)modificationsWithModifiers:(NSDictionary *)modifiers {
    assertRunLoop(configRunLoop());

    /// Cache is reset whenever remaps change
    
    if (_swizzleCache == nil) _swizzleCache = [NSMutableDictionary dictionary];

    //modifiers = modifiers ?: @{};

    NSDictionary *cached = _swizzleCache[modifiers];

    if (cached) {
        return cached;
    } else {
        
        DDLogDebug("Recalculating modifications for modifiers: %@", modifiers);
        
        NSDictionary *new = [RemapSwizzler swizzleRemaps:_remaps activeModifiers:modifiers];
        _swizzleCache[modifiers] = new;
        return new;
    }
}

#pragma mark - Storage

#define USE_TEST_REMAPS NO
static NSDictionary *_remaps;

+ (NSDictionary *)remaps {
    assertRunLoop(configRunLoop());
    return _remaps;
}

static void setRemaps(NSDictionary *remapsDict) {

    /// Compare
    BOOL isEqual = [_remaps isEqualToDictionary:remapsDict];
    
    if (isEqual) {
        
        /// Log
        DDLogDebug("Remaps were set to the same value");
        
    } else {
        
        /// Set
        _remaps = remapsDict;
        
        /// Reset cache
        [_swizzleCache removeAllObjects];
        
        /// Notify
        //[ReactiveRemaps.shared handleRemapsDidChange];
        SwitchMaster_RemapsChanged(_remaps);
        [RemapsAnalyzer reload];
        //[NSNotificationCenter.defaultCenter postNotificationName:kMFNotifCenterNotificationNameRemapsChanged object:self];
        
        /// Log
        DDLogDebug("Set remaps to: %@", _remaps);
    }
}

#pragma mark - Reload

+ (void)reload {
    assertRunLoop(configRunLoop());

    /// The main app uses an array of dicts (aka a table) to represent the remaps in a way that is easy to present in a table view.
    /// The remaps are also stored to file in this format and therefore what `Config.config` contains.
    /// The helper was made to handle a dictionary format which should be more effictient among other perks.
    /// This function takes the remaps in table format from config, then converts it to dict format and makes that available to all the other Input modification classes to base their behaviour off of through self.remaps.
    
    DDLogDebug("TRM set remaps to config");
    
    ///
    /// Disable addMode
    ///
    /// We used to do this *after* loading the remaps from config into `_remaps`. Now we're doing it before. Not sure if that could break things.
    
    if (_addModeIsEnabled) {
        _addModeIsEnabled = NO;
        //[MFMessagePort sendMessage:@"addModeDisabled" withPayload:nil expectingReply:NO];
    }
    
    ///
    /// Load test remaps
    ///
    
    if (USE_TEST_REMAPS) {
        
        setRemaps(testRemaps());

    } else {
        
        ///
        /// Load remaps from config
        ///
        
        NSMutableDictionary *remapsDict = [NSMutableDictionary dictionary];
        
        ///
        /// Get keyboard mods from scroll screen
        ///
        
        if ([(id)config(@"General.scrollKillSwitch") boolValue]) { /// Disable keyboard mods when scrollKillSwitch is on
            
        } else {
            
            NSEventModifierFlags horizontal = [(id)config(@"Scroll.modifiers.horizontal") unsignedIntegerValue];
            NSEventModifierFlags zoom = [(id)config(@"Scroll.modifiers.zoom") unsignedIntegerValue];
            NSEventModifierFlags swift = [(id)config(@"Scroll.modifiers.swift") unsignedIntegerValue];
            NSEventModifierFlags precise = [(id)config(@"Scroll.modifiers.precise") unsignedIntegerValue];
            /// ^ Might be faster to only get Scroll.modifiers once and then query that? Probably not significant
            
            if (horizontal) {
                NSDictionary *precondition = @{
                    kMFModificationPreconditionKeyKeyboard: @(horizontal)
                };
                NSDictionary *effect = @{
                    kMFTriggerScroll: @{
                        kMFModifiedScrollDictKeyEffectModificationType: kMFModifiedScrollEffectModificationTypeHorizontalScroll
                    }
                };
                [remapsDict setObject:effect forKey:precondition];
            }
            if (zoom) {
                NSDictionary *precondition = @{
                    kMFModificationPreconditionKeyKeyboard: @(zoom)
                };
                NSDictionary *effect = @{
                    kMFTriggerScroll: @{
                        kMFModifiedScrollDictKeyEffectModificationType: kMFModifiedScrollEffectModificationTypeZoom
                    }
                };
                [remapsDict setObject:effect forKey:precondition];
            }
            if (swift) {
                NSDictionary *precondition = @{
                    kMFModificationPreconditionKeyKeyboard: @(swift)
                };
                NSDictionary *effect = @{
                    kMFTriggerScroll: @{
                        kMFModifiedScrollDictKeyInputModificationType: kMFModifiedScrollInputModificationTypeQuickScroll
                    }
                };
                [remapsDict setObject:effect forKey:precondition];
            }
            if (precise) {
                NSDictionary *precondition = @{
                    kMFModificationPreconditionKeyKeyboard: @(precise)
                };
                NSDictionary *effect = @{
                    kMFTriggerScroll: @{
                        kMFModifiedScrollDictKeyInputModificationType: kMFModifiedScrollInputModificationTypePrecisionScroll
                    }
                };
                [remapsDict setObject:effect forKey:precondition];
            }
        }
        
        ///
        /// Get values from action table (button remaps)
        ///

        #if 0
        BOOL killSwitch = [(id)config(@"General.buttonKillSwitch") boolValue] /*|| HelperState.shared.isLockedDown*/;

        if (killSwitch) {
            /// TODO: Turn off button interception completely (generally when the remaps dict is empty)
        } else {
        #endif

        /// Convert remaps table to remaps dict
        
        NSArray *remapsTable = [Config.shared.config objectForKey:kMFConfigKeyRemaps];
        
        for (NSDictionary *tableEntry in remapsTable) {
            /// Get modification precondition section of keypath
            NSDictionary *modificationPrecondition = tableEntry[kMFRemapsKeyModificationPrecondition];
            /// Get trigger section of keypath
            NSArray *triggerKeyArray;
            id trigger = tableEntry[kMFRemapsKeyTrigger];
            if ([trigger isKindOfClass:NSString.class]) {
                NSString *triggerStr = (NSString *)trigger;
                triggerKeyArray = @[triggerStr];
                NSAssert([triggerStr isEqualToString:kMFTriggerScroll] || [triggerStr isEqualToString:kMFTriggerDrag] , @"");
            } else if ([trigger isKindOfClass:NSDictionary.class]) {
                NSDictionary *triggerDict = (NSDictionary *)trigger;
                NSString *duration = triggerDict[kMFButtonTriggerKeyDuration];
                NSNumber *level = triggerDict[kMFButtonTriggerKeyClickLevel];
                NSNumber *buttonNum = triggerDict[kMFButtonTriggerKeyButtonNumber];
                triggerKeyArray = @[buttonNum, level, duration];
            } else NSAssert(NO, @"");
            /// Get effect
            id effect = tableEntry[kMFRemapsKeyEffect]; /// This is always dict
            if ([trigger isKindOfClass:NSDictionary.class]) {
                effect = @[effect];
                /// ^ For some reason we built one shot effect handling code around _arrays_ of effects. So we need to wrap our effect in an array.
                ///  This doesn't make sense. We should clean this up at some point and remove the array.
            }
            /// Put it all together
            NSArray *keyArray = [@[modificationPrecondition] arrayByAddingObjectsFromArray:triggerKeyArray];
            [remapsDict setObject:effect forCoolKeyArray:keyArray];
        }

        #if 0
        }
        #endif

        setRemaps(remapsDict);
    }
}

#pragma mark - AddMode

BOOL _addModeIsEnabled = NO;
+ (BOOL)addModeIsEnabled {
    assertRunLoop(configRunLoop());
    return _addModeIsEnabled;
}

+ (BOOL)enableAddMode {

    /**
     Discussion:
         Add mode configures the helper such that it remaps to "add mode feedback effects" instead of normal effects.
         "add mode feedback effects" are effect dicts containing keys such as `kMFModifiedDragTypeAddModeFeedback` (See below) [Oct 2026]
         When "add mode feedback effects" are triggered, the helper will send information about how exactly the effect was triggered to the main app.
         This allows us to capture triggers that the user performs and use them in the main app to add new rows to the remaps table view
         The dataModel for the remaps table view is an array of dicts, where each dict is called a tableEntry.
         Each tableEntry has 3 keys:
             - `kMFRemapsKeyTrigger`
             - `kMFRemapsKeyModificationPrecondition`
             - `kMFRemapsKeyEffect`
         Our feedback dicts we send to the main app during addMode use 3 - overlapping, but different - keys:
             - `kMFRemapsKeyTrigger`
                This is added in this function, and eventually sent off to the main app
             - `kMFRemapsKeyModificationPrecondition`
                This is added dynamically in `addModeSwizzler` and eventually sent off to the main app [Oct 2026]
             - `kMFActionDictKeyType` / `kMFModifiedDragDictKeyType` / `kMFModifiedScrollDictKeyType`
                These are added in this function and used so the helper knows how to process the dictionary, but it's removed before
                we send stuff off to the mainApp
         So the final feedback dict we send to the main app contains the keys:
             - `kMFRemapsKeyTrigger`
             - `kMFRemapsKeyModificationPrecondition`
         So it's *almost* a tableEntry which can be used by the mainApp's remap tableview's dataModel, it's just lacking the `kMFRemapsKeyEffect` key and values.
         This makes sense, because The effect is then to be chosen by the user in the main app's GUI


     Other core parts of this mechanism are implemented here: [Oct 2026]
         - `RemapSwizzler.m > addModeSwizzler()`
            - Top of file contains core/good explanations of how/why addMode is split up in this way [Oct 2026]
         - `SwitchMaster.m > [Remap addModeIsEnabled]`
     */

    assertRunLoop(configRunLoop());
    DDLogDebug("TRM set remaps to addMode");
    
    NSMutableDictionary *triggerToEffectDict = [NSMutableDictionary dictionary];
    
    /// Drag trigger
    triggerToEffectDict[kMFTriggerDrag] = @{
        kMFModifiedDragDictKeyType: kMFModifiedDragTypeAddModeFeedback,
        kMFRemapsKeyTrigger: kMFTriggerDrag,
    }.mutableCopy;
    /// Scroll trigger
    triggerToEffectDict[kMFTriggerScroll] = @{
        kMFModifiedScrollDictKeyEffectModificationType: kMFModifiedScrollEffectModificationTypeAddModeFeedback,
        kMFRemapsKeyTrigger: kMFTriggerScroll,
    }.mutableCopy;
    
    /// Button triggers (dict based)
    for (int btn = 1; btn <= kMFMaxButtonNumber; btn++) {
        for (int lvl = 1; lvl <= 3; lvl++) {
            for (NSString *dur in @[kMFButtonTriggerDurationClick, kMFButtonTriggerDurationHold]) {
                
                NSMutableDictionary *addModeFeedbackDict = @{
                    kMFActionDictKeyType: kMFActionDictTypeAddModeFeedback,
                    kMFRemapsKeyTrigger: @{
                        kMFButtonTriggerKeyButtonNumber: @(btn),
                        kMFButtonTriggerKeyClickLevel: @(lvl),
                        kMFButtonTriggerKeyDuration: dur,
                    }
                }.mutableCopy;
                [triggerToEffectDict setObject:@[addModeFeedbackDict] forCoolKeyArray:@[@(btn),@(lvl),dur]];
                ///  ^ We're wrapping `addModeFeedbackDict` in an array here because we started building helper with dicts of several effects in mind.
                ///      This doesn't make sense though and we should remove it.
            }
        }
    }
    
    /// Update state and notifiy
    ///     Need to set `_addModeIsEnabled` true before calling `setRemaps:` so that the keyboard mods event tap in `Modifiers` is toggled properly
    _addModeIsEnabled = YES;
    
    /// Send feedback
    //[MFMessagePort sendMessage:@"addModeEnabled" withPayload:nil expectingReply:NO];

    /// Set `_remaps` to generated
    ///    Why weren't we using setRemaps here? Changed it to setRemaps now. Hopefully nothing breaks.

    setRemaps(@{
        @{}: triggerToEffectDict
    });

    /// Return success
    return YES;
}

+ (BOOL)disableAddMode {
    assertRunLoop(configRunLoop());

    /// Reload
    if (_addModeIsEnabled) [self reload];
    
    /// Return success
    return YES;
}

+ (void)sendAddModeFeedback:(NSDictionary *)payload {
    assertRunLoop(configRunLoop());

    DDLogDebug("Concluding addMode with payload: %@", payload);

    if (runningDebugMode()) {
        NSString *trigger = [payload objectForKey: kMFRemapsKeyTrigger];
        if ([trigger isEqual: kMFTriggerDrag] ||
            [trigger isEqual: kMFTriggerScroll]
        ) {
            NSArray *buttonPreconditions = [[payload objectForKey: kMFRemapsKeyModificationPrecondition] objectForKey: kMFModificationPreconditionKeyButtons];
            if (!buttonPreconditions) {
                mfassert(false, @"!addModePayloadIsValid: the payload doesn't contain\n" /// Formerly this check was in a separate `addModePayloadIsValid` function, which might still be referenced elsewhere [Oct 2026]
                                 "a button at all (it's a drag or scroll trigger without a button modifier)\n"
                                 "addModeSwizzler() should make this impossible [Oct 2026]"); /// This is just validating that what we're doing in `addModeSwizzler()` is working correctly.
                return;
            }
        }
    }

    if ((0)) {
        [self reload];
        [MFMessagePort sendMessage: @"addModeDisabled" withPayload: nil waitForReply: NO];
    }

    [MFMessagePort sendMessage:@"addModeFeedback" withPayload: payload waitForReply: NO];

    if ((0)) [Remap performSelector:@selector(disableAddMode) withObject:nil afterDelay:0.5];
                /// ^ We did this to keep the remapping disabled for a little while after adding a new row, but it leads to adding several entries at once when trying to input button modification precondition, if you're not fast enough.

}

#pragma mark - Dummy Data

static NSDictionary *testRemaps(void) {
    /// This fanned out dictionary representation of our remappings is what we based our helper code on.
    /// It's not super human readable, but it should be very fast, and makes some of the operations like overrides and on the fly 'assessment of the mapping landscape' pretty handy.
    /// Using this in Helper is definitely faster than the tableView oriented (-> array based) structure which the MainApp uses. That's because we can do a lot of O(1) dict accesses where we'd have to use O(n) array searches using the other structure. I suspect that performance gains are negligible though.
    /// Having these 2 data structures might very well not be worth the cost of having to think about both and write a conversion function between them. But we've already built helper around this, and mainApp needs the table based structure, so we're sticking with this double-structure approach.
    return @{
        
        /// Empty precond
        
        @{}: @{                                                     // Key: modifier dict (empty -> no modifiers)
            //                @(3): @{                                                // Key: button
            //                        @(1): @{                                            // Key: level
            //                                kMFButtonTriggerDurationClick: @[                                   // Key: click/hold, value: array of actions
            //                                        @{
            //                                            kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
            //                                            kMFActionDictKeyGenericVariant:@(kMFSHMissionControl)
            //                                        },
            //                                ],
            //                                kMFButtonTriggerDurationHold: @[                                  // Key: click/hold, value: array of actions
            //                                        @{
            //                                            kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
            //                                            kMFActionDictKeyGenericVariant: @(kMFSHShowDesktop),
            //                                        },
            //                                ],
            //
            //                        },
            ////                        @(2): @{                                            // Key: level
            ////                                kMFButtonTriggerDurationClick: @[                                   // Key: click/hold, value: array of actions
            ////                                        @{
            ////                                            kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
            ////                                            kMFActionDictKeyGenericVariant:@(kMFSHLookUp)
            ////                                        },
            ////                                ],
            ////                        }
            //                },
            @(4): @{                                                // Key: button
                @(1): @{                                            // Key: level
                    kMFButtonTriggerDurationClick: @[
                        @{
                            kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                            kMFActionDictKeyGenericVariant: @(kMFSHMissionControl),
                        }
                    ],
                    //                                kMFButtonTriggerDurationHold: @[
                    //                                        @{
                    //                                            kMFActionDictKeyType: kMFActionDictTypeSmartZoom,
                    //                                        }
                    //                                ],
                },
            },
            ////                        @(2): @{                                            // Key: level
            ////                                kMFButtonTriggerDurationClick: @[
            ////                                        @{
            ////                                            kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
            ////                                            kMFActionDictKeyGenericVariant: @(36),
            ////                                        }
            ////                                ],
            ////                        },
            //                },
            @(7)  : @{                                                // Key: button
                @(1): @{                                            // Key: level
                    kMFButtonTriggerDurationClick: @[                                  // Key: click/hold, value: array of actions
                        @{
                            kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                            kMFActionDictKeyGenericVariant: @(kMFSHLaunchpad),
                        },
                    ],
                },
            },
            
        },
        
        //        @{                                                          // Key: modifier dict
        //            kMFModificationPreconditionKeyButtons: @[
        //                    @{
        //                        kMFButtonModificationPreconditionKeyButtonNumber: @(3),
        //                        kMFButtonModificationPreconditionKeyClickLevel: @(2),
        //                    }
        //            ],
        //        }: @{
        //                kMFTriggerDrag: @{
        //                        kMFModifiedDragDictKeyType: kMFModifiedDragTypeFakeDrag,
        //                        kMFModifiedDragDictKeyFakeDragVariantButtonNumber: @3,
        //                }
        //        },
        
        /// Button 4 precond
        
        @{
            kMFModificationPreconditionKeyButtons: @[
                @{
                    kMFButtonModificationPreconditionKeyButtonNumber: @(4),
                    kMFButtonModificationPreconditionKeyClickLevel: @(1),
                },
            ],
            
        }: @{
            kMFTriggerScroll: @{
                kMFModifiedScrollDictKeyEffectModificationType: kMFModifiedScrollEffectModificationTypeZoom
            },
            kMFTriggerDrag: @{
                kMFModifiedDragDictKeyType: kMFModifiedDragTypeThreeFingerSwipe,
            },
            @(3): @{                                                // Key: button
                @(1): @{                                            // Key: level
                    kMFButtonTriggerDurationClick: @[
                        @{
                            kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                            kMFActionDictKeyGenericVariant: @(kMFSHSpotlight),
                        }
                    ],
                },
                @(2): @{                                            // Key: level
                    kMFButtonTriggerDurationClick: @[
                        @{
                            kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                            kMFActionDictKeyGenericVariant: @(kMFSHLaunchpad),
                        }
                    ],
                },
            },
        },
        
        /// Button 5 precond
        
        @{
            kMFModificationPreconditionKeyButtons: @[
                @{
                    kMFButtonModificationPreconditionKeyButtonNumber: @(5),
                    kMFButtonModificationPreconditionKeyClickLevel: @(1),
                },
            ],
            
        }: @{
            kMFTriggerScroll: @{
                kMFModifiedScrollDictKeyEffectModificationType: kMFModifiedScrollEffectModificationTypeRotate,
            },
            kMFTriggerDrag: @{
                kMFModifiedDragDictKeyType: kMFModifiedDragTypeTwoFingerSwipe,
            },
        
        },
            
        /// Option precond
        
        @{
            kMFModificationPreconditionKeyKeyboard: @(NSEventModifierFlagOption)
        }: @{
            kMFTriggerScroll: @{
                kMFModifiedScrollDictKeyInputModificationType: kMFModifiedScrollInputModificationTypeQuickScroll
            }
        },
        
        /// Shift precond
            
        @{
            kMFModificationPreconditionKeyKeyboard: @(NSEventModifierFlagShift)
        }: @{
            kMFTriggerScroll: @{
                kMFModifiedScrollDictKeyEffectModificationType: kMFModifiedScrollEffectModificationTypeHorizontalScroll,
            }
        },

        
        /// Option & Shift precond
        
        @{
            kMFModificationPreconditionKeyKeyboard: @(NSEventModifierFlagOption | NSEventModifierFlagShift)
        }: @{
            kMFTriggerScroll: @{
                kMFModifiedScrollDictKeyEffectModificationType: kMFModifiedScrollEffectModificationTypeZoom
            }
        },
        
        /// Weird precond
        
        @{
            //            kMFModificationPreconditionKeyButtons: @[
            //                    @{
            //                        kMFButtonModificationPreconditionKeyButtonNumber: @(4),
            //                        kMFButtonModificationPreconditionKeyClickLevel: @(2),
            //                    },
            //                    @{
            //                        kMFButtonModificationPreconditionKeyButtonNumber: @(3),
            //                        kMFButtonModificationPreconditionKeyClickLevel: @(1),
            //                    },
            //            ],
            kMFModificationPreconditionKeyKeyboard: @(NSEventModifierFlagShift | NSEventModifierFlagControl)
        }: @{
            kMFTriggerDrag: @{
                kMFModifiedDragDictKeyType: kMFModifiedDragTypeThreeFingerSwipe,
            }
        },
    };
}


@end
