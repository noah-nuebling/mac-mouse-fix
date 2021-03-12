//
// --------------------------------------------------------------------------
// TransformationManager.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "TransformationManager.h"
#import "Utility_Transformation.h"
#import "SharedUtility.h"
#import "ButtonTriggerGenerator.h"
#import "Actions.h"
#import "ModifierManager.h"
#import "ModifiedDrag.h"
#import "NSArray+Additions.h"
#import "NSMutableDictionary+Additions.h"
#import "Constants.h"

@implementation TransformationManager

+ (void)load {
//    loadTestRemaps();
}

#pragma mark - Interface and remaps dictionary

// Always set _remaps through `setRemaps:` so the kMFNotificationNameRemapsChanged notification is sent
//      The kMFNotificationNameRemapsChanged notification is used by modifier manager to update itself, whenever this updates.
//      Idk why we aren't just calling an update function instead of using notifications.
NSDictionary *_remaps;
+ (void)setRemaps:(NSDictionary *)r {
    _remaps = r;
    [NSNotificationCenter.defaultCenter postNotificationName:kMFNotificationNameRemapsChanged object:self];
}
/// The main app uses an array of dicts (aka a table) to represent the remaps in a way that is easy to present in a table view.
/// The remaps are also stored to file in this format.
/// The helper was made to handle a dictionary format which should be more effictient among other perks.
/// This function takes the remaps in table format, then converts it to dict format and makes that available to all the other Input Transformation classes to base their behaviour off of.
+ (void)updateWithRemapsTable:(NSArray *)remapsTable {
    // Convert remaps table to remaps dict
    NSMutableDictionary *remapsDict = [NSMutableDictionary dictionary];
    for (NSDictionary *tableEntry in remapsTable) {
        // Get modification precondition section of keypath
        NSDictionary *modificationPrecondition = tableEntry[kMFRemapsKeyModificationPrecondition];
        // Get trigger section of keypath
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
        // Get effect
        NSDictionary *effect = tableEntry[kMFRemapsKeyEffect];
        // Put it all together
        NSArray *keyArray = [@[modificationPrecondition] arrayByAddingObjectsFromArray:triggerKeyArray];
        [remapsDict setObject:@[effect] forCoolKeyArray:keyArray];
            // ^ For some reason we built the helper around arrays of effects. That doesn't make sense. We should clean that up at some point.
    }
    _remaps = remapsDict;
}

+ (NSDictionary *)remaps {
    return _remaps;
}

#pragma mark - Dummy Data

static void loadTestRemaps() {
    /// This fanned out dictionary representation of our remappings is what we based our helper code on.
    /// It's not super human readable, but it should be very fast, and makes some of the operations like overrides and on the fly 'assessment of the mapping landscape' pretty handy.
    /// Using this in Helper is definitely faster than the tableView oriented (-> array based) structure which the MainApp uses. That's because we can do a lot of O(1) dict accesses where we'd have to use O(n) array searches using the other structure. I suspect that performance gains are negligible though.
    /// Having these 2 data structures might very well not be worth the cost of having to think about both and write a conversion function between them. But we've already built helper around this, and mainApp needs the table based structure, so we're sticking with this double-structure approach.
    _remaps = @{
        @{}: @{                                                     // Key: modifier dict (empty -> no modifiers)
                @(3): @{                                                // Key: button
                        @(1): @{                                            // Key: level
                                kMFButtonTriggerDurationClick: @[                                   // Key: click/hold, value: array of actions
                                        @{
                                            kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                                            kMFActionDictKeyGenericVariant:@(kMFSHMissionControl)
                                        },
                                ],
                                kMFButtonTriggerDurationHold: @[                                  // Key: click/hold, value: array of actions
                                        @{
                                            kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                                            kMFActionDictKeyGenericVariant: @(kMFSHShowDesktop),
                                        },
                                ],
                                
                        },
                        @(2): @{                                            // Key: level
                                kMFButtonTriggerDurationClick: @[                                   // Key: click/hold, value: array of actions
                                        @{
                                            kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                                            kMFActionDictKeyGenericVariant:@(kMFSHLookUp)
                                        },
                                ],
                        }
                },
                @(4): @{                                                // Key: button
                        @(1): @{                                            // Key: level
                                kMFButtonTriggerDurationClick: @[
                                        @{
                                            kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                                            kMFActionDictKeyGenericVariant: @(32),
                                        }
                                ],
                                kMFButtonTriggerDurationHold: @[
                                        @{
                                            kMFActionDictKeyType: kMFActionDictTypeSmartZoom,
                                        }
                                ],
                        },
                        @(2): @{                                            // Key: level
                                kMFButtonTriggerDurationClick: @[
                                        @{
                                            kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                                            kMFActionDictKeyGenericVariant: @(36),
                                        }
                                ],
                        },
                },
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
        
        @{                                                          // Key: modifier dict
            kMFModificationPreconditionKeyButtons: @[
                    @{
                        kMFButtonModificationPreconditionKeyButtonNumber: @(3),
                        kMFButtonModificationPreconditionKeyClickLevel: @(2),
                    }
            ],
        }: @{
                kMFTriggerDrag: @{
                        kMFModifiedDragDictKeyType: kMFModifiedDragDictTypeFakeDrag,
                        kMFModifiedDragDictKeyFakeDragVariantButtonNumber: @3,
                }
        },
        
        @{
            kMFModificationPreconditionKeyButtons: @[
                    @{
                        kMFButtonModificationPreconditionKeyButtonNumber: @(3),
                        kMFButtonModificationPreconditionKeyClickLevel: @(1),
                    },
            ],
            
        }: @{
                kMFTriggerDrag: @{
                        kMFModifiedDragDictKeyType: kMFModifiedDragDictTypeThreeFingerSwipe,
                }
        },
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
            kMFModificationPreconditionKeyKeyboard: @(NSShiftKeyMask | NSControlKeyMask)
        }: @{
                kMFTriggerDrag: @{
                        kMFModifiedDragDictKeyType: kMFModifiedDragDictTypeThreeFingerSwipe,
                }
        }
    };
}


@end
