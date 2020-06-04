//
// --------------------------------------------------------------------------
// ModifyingActions.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "ModifyingActions.h"
#import "ScrollModifiers.h"

@implementation ModifyingActions

static NSDictionary *modifyingState;

+ (void)load {
//    modifyingState = @{
//        @(4): @{
//                @"modyfyingDrag": @(kMFModifierStateInitialized),
//                @"modifyingScroll": @(kMFModifierStateInUse),
//        }
//    };
}

+ (void)initializeModifiersForButton:(int)button withActionArray:(NSArray *)actionArray {
    
    for (NSDictionary *actionDict in actionArray) {
        if ([actionDict[@"type"] isEqualToString:@"modifyingScroll"]) {
            ScrollModifiers.horizontalScrolling = YES;
        } else if ([actionDict[@"type"] isEqualToString:@"modifyingDrag"]) {
            
        }
//        modifyingState[@(button)][type] = kMFModifierStateInitialized;
    }
}
+ (void)killModifiersForButton:(int)button {
    
}

@end
