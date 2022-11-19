//
// --------------------------------------------------------------------------
// TransformationManager.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

#import "TransformationManager.h"
#import "TransformationUtility.h"
#import "SharedUtility.h"
#import "ButtonTriggerGenerator.h"
#import "Actions.h"
#import "ModifierManager.h"
#import "ModifiedDrag.h"
#import "NSArray+Additions.h"
#import "NSDictionary+Additions.h"
#import "Constants.h"
#import "Config.h"
#import "MFMessagePort.h"
#import "Mac_Mouse_Fix_Helper-Swift.h"

@implementation TransformationManager

#pragma mark - Remaps dictionary and interface

#define USE_TEST_REMAPS NO
static NSDictionary *_remaps;

+ (void)setRemaps:(NSDictionary *)remapsDict {
    
    /// Always set remaps through this, so that the kMFNotifCenterNotificationNameRemapsChanged notification is posted
    /// The notification is used by ModifierManager to update itself, whenever `_remaps` updates.
    ///  (Idk why we aren't just calling an update function instead of using a notification)
    
    _remaps = remapsDict;
//    _remaps = self.testRemaps; /// TESTING
//    if (!_addModeIsEnabled) {
//        [self enableAddMode]; /// TESTING
//    }
    [NSNotificationCenter.defaultCenter postNotificationName:kMFNotifCenterNotificationNameRemapsChanged object:self];
    DDLogDebug(@"Set remaps to: %@", _remaps);
}

/// The main app uses an array of dicts (aka a table) to represent the remaps in a way that is easy to present in a table view.
/// The remaps are also stored to file in this format and therefore what `ConfigFileInterface_App.config` contains.
/// The helper was made to handle a dictionary format which should be more effictient among other perks.
/// This function takes the remaps in table format from config, then converts it to dict format and makes that available to all the other Input Transformation classes to base their behaviour off of through self.remaps.
+ (void)reload {
    
    DDLogDebug(@"TRM set remaps to config");
    
    ///
    /// Disable addMode
    ///
    /// We used to do this *after* loading the remaps from config into `_remaps`. Now we're doing it before. Not sure if that could break things.
    
    if (_addModeIsEnabled) {
        _addModeIsEnabled = NO;
        [MFMessagePort sendMessage:@"addModeDisabled" withPayload:nil expectingReply:NO];
    }
    
    ///
    /// Load test remaps
    ///
    
    if (USE_TEST_REMAPS) {
        [self setRemaps:self.testRemaps]; return;
    }
    
    ///
    /// Load remaps from config 
    ///
    
    NSMutableDictionary *remapsDict = [NSMutableDictionary dictionary];
    
    ///
    /// Get keyboard mods from scroll screen
    ///
    
    if ([(id)config(@"Other.scrollKillSwitch") boolValue]) { /// Disable keyboard mods when scrollKillSwitch is on
        
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
    
    BOOL killSwitch = [(id)config(@"Other.buttonKillSwitch") boolValue] || HelperState.isLockedDown;
    
    if (killSwitch) {
        /// TODO: Turn off button interception completely (generally when the remaps dict is empty)
    } else {
        
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
    }
    
    [self setRemaps:remapsDict];
}
+ (NSDictionary *)remaps {
    return _remaps;
}

#pragma mark - AddMode

BOOL _addModeIsEnabled = NO;
+ (BOOL)addModeIsEnabled {
    return _addModeIsEnabled;
}

+ (void)enableAddMode {
    
    /// \discussion  Add mode configures the helper such that it remaps to "add mode feedback effects" instead of normal effects.
    /// When "add mode feedback effects" are triggered, the helper will send information about how exactly the effect was triggered to the main app.
    /// This allows us to capture triggers that the user performs and use them in the main app to add new rows to the remaps table view
    /// The dataModel for the remaps table view is an array of dicts, where each dict is called a tableEntry.
    /// Each table entry has 3 keys:
    ///     - kMFRemapsKeyTrigger
    ///     - kMFRemapsKeyModificationPrecondition
    ///     - kMFRemapsKeyEffect
    /// Our feedback dicts we send to the main app during addMode use 3 - overlapping, but different - keys:
    ///     - kMFRemapsKeyTrigger
    ///     - kMFRemapsKeyModificationPrecondition
    ///     - kMFActionDictKeyType / kMFModifiedDragDictKeyType (Edit: or kMFModifiedScrollDictKeyType)
    /// kMFActionDictKeyType / kMFModifiedDragDictKeyType is added in this funciton and used so the helper knows how to process the dictionary, but it's removed before we send stuff off to the mainApp
    /// kMFRemapsKeyTrigger is added in this function, and eventually sent off to the main app
    /// kMFRemapsKeyModificationPrecondition is addedDynamically in **RemapSwizzler**.
    /// So the final feedback dict we send to the main app contains values for the keys
    ///     - kMFRemapsKeyTrigger
    ///     - kMFRemapsKeyModificationPrecondition
    /// So it's _almost_ a tableEntry which can be used by the mainApp's remap tableview's dataModel, it's just lacking the kMFRemapsKeyEffect key and values.
    /// This makes sense, because The effect is then to be chosen by the user in the main app's GUI
    ///
    /// We implemented a policy of "modifiers need to be present to capture drags and scrolls" using the `addModePayloadIsValid:` method.
    ///     Edit: The remapSwizzler is actually responsible for this now.
    ///     TODO: Remove addModePayloadIsValid.
    
    DDLogDebug(@"TRM set remaps to addMode");
    
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
    
    /// Set `_remaps` to generated
    ///    Why weren't we using setRemaps here? Changed it to setRemaps now. Hopefully nothing breaks.
    
//    _remaps = @{
//        @{}: triggerToEffectDict
//    };
    [self setRemaps:@{
        @{}: triggerToEffectDict
    }];
    
    /// Update state and notifiy
    _addModeIsEnabled = YES;
    [MFMessagePort sendMessage:@"addModeEnabled" withPayload:nil expectingReply:NO];
}

+ (void)disableAddMode {
        
    [self reload];
//    _addModeIsEnabled = NO;
//    [MFMessagePort sendMessage:@"addModeDisabled" withPayload:nil expectingReply:NO];
}

//+ (void)disableAddModeWithPayload:(NSDictionary *)payload {
//    /// Wrapper for disableAddMode. Not sure if this is useful
//
//    if (![self addModePayloadIsValid:payload]) return;
//
//    [self disableAddMode];
//}

//+ (void)sendAddModeFeedbackWithPayload:(NSDictionary *)payload {
//
//    if (![self addModePayloadIsValid:payload]) return;
//
//    [MFMessagePort sendMessage:@"addModeFeedback" withPayload:payload expectingReply:NO];
//    ///    [TransformationManager performSelector:@selector(disableAddMode) withObject:nil afterDelay:0.5];
//    /// ^ We did this to keep the remapping disabled for a little while after adding a new row, but it leads to adding several entries at once when trying to input button modification precondition, if you're not fast enough.
//}

+ (void)concludeAddModeWithPayload:(NSDictionary *)payload {
    
    DDLogDebug(@"Concluding addMode with payload: %@", payload);
    
    if (![self addModePayloadIsValid:payload]) return;
    
    [self reload];
    _addModeIsEnabled = NO;
//    [MFMessagePort sendMessage:@"addModeDisabled" withPayload:nil expectingReply:NO];
    [MFMessagePort sendMessage:@"addModeFeedback" withPayload:payload expectingReply:NO];
    ///    [TransformationManager performSelector:@selector(disableAddMode) withObject:nil afterDelay:0.5];
    /// ^ We did this to keep the remapping disabled for a little while after adding a new row, but it leads to adding several entries at once when trying to input button modification precondition, if you're not fast enough.

}


/// Using this to prevent payloads containing a modifiedDrag / modifiedScroll with a keyboard-modifier-only precondition, or an empty precondition from being sent to the main app
/// Empty preconditions only happen when weird bugs occur so this is just an extra safety net for that
///     Edit: We simplified things now and this is the only safety net against sending payloads without necessary modificationPreconditions.
/// Keyboard-modifier-only modifiedDrags and modifiedScrolls work in principle but they cause some smaller bugs and issues in the mainApp UI. We don't wan't to polish that up so we're just disabling the ability to add them.
///     Also the remap table is completely structured around buttons now, so it wouldn't fit into the UI to have keyboard-modifier-only modifiedDrags and modifiedScrolls
+ (BOOL)addModePayloadIsValid:(NSDictionary *)payload {
    if ([payload[kMFRemapsKeyTrigger] isEqual:kMFTriggerDrag]
        || [payload[kMFRemapsKeyTrigger] isEqual:kMFTriggerScroll]) {
        NSArray *buttonPreconds = payload[kMFRemapsKeyModificationPrecondition][kMFModificationPreconditionKeyButtons];
        if (buttonPreconds == nil || buttonPreconds.count == 0) {
            return NO;
        }
    }
    return YES;
}

#pragma mark - keyCaptureMode

CFMachPortRef _keyCaptureEventTap;

+ (void)enableKeyCaptureMode {
    
    DDLogInfo(@"Enabling keyCaptureMode");
    
    if (_keyCaptureEventTap == nil) {
        _keyCaptureEventTap = [TransformationUtility createEventTapWithLocation:kCGHIDEventTap mask:CGEventMaskBit(kCGEventKeyDown) | CGEventMaskBit(NSEventTypeSystemDefined) option:kCGEventTapOptionDefault placement:kCGHeadInsertEventTap callback:keyCaptureModeCallback];
    }
    CGEventTapEnable(_keyCaptureEventTap, true);
}

+ (void)disableKeyCaptureMode {
    CGEventTapEnable(_keyCaptureEventTap, false);
}

CGEventRef  _Nullable keyCaptureModeCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {
    
    CGEventFlags flags  = CGEventGetFlags(event);
    
    NSDictionary *payload;
    
    if (type == kCGEventKeyDown) {
    
        CGKeyCode keyCode = CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
    
        if (keyCaptureModePayloadIsValidWithKeyCode(keyCode, flags)) {
        
            payload = @{
        @"keyCode": @(keyCode),
        @"flags": @(flags),
    };
    
    [MFMessagePort sendMessage:@"keyCaptureModeFeedback" withPayload:payload expectingReply:NO];
            [TransformationManager disableKeyCaptureMode];
        }
    
    } else if (type == NSEventTypeSystemDefined) {
        
        NSEvent *e = [NSEvent eventWithCGEvent:event];
        
        MFSystemDefinedEventType type = (MFSystemDefinedEventType)(e.data1 >> 16);
        
        if (keyCaptureModePayloadIsValidWithEvent(e, flags, type)) {
            
            DDLogDebug(@"Capturing system event with data1: %ld, data2: %ld", e.data1, e.data2);
            
            payload = @{
                @"systemEventType": @(type),
                @"flags": @(flags),
            };
            
            [MFMessagePort sendMessage:@"keyCaptureModeFeedbackWithSystemEvent" withPayload:payload expectingReply:NO];
    [TransformationManager disableKeyCaptureMode];
        }
        
    }
    
    
    return nil;
}
bool keyCaptureModePayloadIsValidWithKeyCode(CGKeyCode keyCode, CGEventFlags flags) {
    return true; /// keyCode 0 is 'A'
}
    
bool keyCaptureModePayloadIsValidWithEvent(NSEvent *e, CGEventFlags flags, MFSystemDefinedEventType type) {
    
    BOOL isSub8 = (e.subtype == 8); /// 8 -> NSEventSubtypeScreenChanged
    BOOL isKeyDown = (e.data1 & kMFSystemDefinedEventPressedMask) == 0;
    BOOL secondDataIsNil = e.data2 == -1; /// The power key up event has both data fields be 0
    BOOL typeIsBlackListed = type == kMFSystemEventTypeCapsLock;
    
    
    return isSub8 && isKeyDown && secondDataIsNil && !typeIsBlackListed;
}

#pragma mark - Dummy Data

+ (NSDictionary *)testRemaps {
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
