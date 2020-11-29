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
#import "Constants.h"

@implementation TransformationManager

#pragma mark - Remaps dictionary

// Always set _remaps through `setRemaps:` so the kMFNotificationNameRemapsChanged notification is sent
NSDictionary *_remaps;
+ (void)setRemaps:(NSDictionary *)r {
    _remaps = r;
    [NSNotificationCenter.defaultCenter postNotificationName:kMFNotificationNameRemapsChanged object:self];
}
+ (NSDictionary *)remaps {
    return _remaps;
}

#pragma mark - Dummy Data

NSArray *_remapsUI;
+ (void)load {
    _remaps = @{
        @{}: @{                                                     // Key: modifier dict (empty -> no modifiers)
                @(3): @{                                                // Key: button
                        @(1): @{                                            // Key: level
                                kMFButtonTriggerDurationClick: @[                                   // Key: click/hold, value: array of actions
                                        @{
                                            kMFActionDictKeyType: kMFActionDictTypeMouseButtonClicks,
                                            kMFActionDictKeyMouseButtonClicksVariantButtonNumber: @(1),
                                            kMFActionDictKeyMouseButtonClicksVariantNumberOfClicks: @(2),
                                        },
                                ],
                                kMFButtonTriggerDurationHold: @[                                  // Key: click/hold, value: array of actions
                                        @{
                                            kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                                            kMFActionDictKeyVariant: @(32),
                                        },
                                ],
                                
                        },
                },
                @(4): @{                                                // Key: button
                        @(1): @{                                            // Key: level
                                kMFButtonTriggerDurationClick: @[
                                        @{
                                            kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                                            kMFActionDictKeyVariant: @(32),
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
                                            kMFActionDictKeyVariant: @(36),
                                        }
                                ],
                        },
                },
                @(7)  : @{                                                // Key: button
                        @(1): @{                                            // Key: level
                                kMFButtonTriggerDurationClick: @[                                  // Key: click/hold, value: array of actions
                                        @{
                                            kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                                            kMFActionDictKeyVariant: @(kMFSHLaunchpad),
                                        },
                                ],
                        },
                },
                
        },
        
        @{                                                          // Key: modifier dict
            kMFModificationPreconditionKeyButtons: @{
                    @(4): @(1),                                      // btn, lvl
            },
        }: @{
                kMFRemapsKeyModifiedDrag: kMFModifiedDragTypeThreeFingerSwipe,
        },
        
        @{
            kMFModificationPreconditionKeyButtons: @{
                    @(5): @(1),
            },
        }: @{
                kMFRemapsKeyModifiedDrag: kMFModifiedDragTypeTwoFingerSwipe,
        }
    };
    //    _testRemapsUI = @[
    //        @{
    //            @"button": @(3),
    //            @"level": @(1),
    //            kMFActionDictKeyType: kMFButtonTriggerDurationClick,
    //            @"modifiers": @[],
    //            @"actions": @[
    //                @{
    //                    kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
    //                    kMFActionDictTypeSymbolicHotkey: @(32),
    //                },
    //            ],
    //        },
    //        @{
    //            @"button": @(3),
    //            @"level": @(1),
    //            kMFActionDictKeyType: kMFButtonTriggerDurationHold,
    //            @"modifiers": @[],
    //            @"actions": @[
    //                @{
    //                    kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
    //                    kMFActionDictTypeSymbolicHotkey: @(33),
    //                },
    //            ],
    //        },
    //    ];
}

@end
