//
// --------------------------------------------------------------------------
// ButtonModifiers.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "ButtonModifiers.h"
#import "SharedUtility.h"
#import "Modifiers.h"
#import "Logging.h"

@implementation ButtonModifiers {
    
    ButtonModifierState _state;
}

/// Replacement for `ButtonModifiers.swift` because Swift made things very slow
/// Module for Buttons.swift

/// Threading:
///     This should only be used by Buttons.swift. Use buttons.swfits dispatchQueue to protect resources.
/// Optimization:
///     Switft does some weird bridging when when we call `state.add(NSDictionary(dictionaryLiteral:)`, that should be much faster in ObjC

- (instancetype)init {
    
    self = [super init];
    if (self) {
        _state = [NSMutableArray array];
    }
    return self;
}

- (void)updateWithButton:(MFMouseButtonNumber)button clickLevel:(NSInteger)clickLevel downNotUp:(BOOL)mouseDown {
    
    BOOL didChange = NO;
    
    if (mouseDown) {
        
        [_state addObject:@{
            kMFButtonModificationPreconditionKeyButtonNumber: @(button),
            kMFButtonModificationPreconditionKeyClickLevel: @(clickLevel),
        }];
        didChange = YES;
        
    } else {
        didChange = removeStateForButton(_state, button);
    }
    
    if (didChange) {
        
        /// Debug
        if (runningPreRelease()) {
            NSString *description = stateDescription(_state);
            DDLogDebug(@"buttonModifiers - update - toState: %@", description);
        }
        
        /// Notify
        ///     Do we need to check if the buttonMods actually changed?
        [Modifiers buttonModsChangedTo:_state];
    }
}

- (void)killButton:(MFMouseButtonNumber)button {
    
    /// I don't really understand what this does anymore. Should compare this with before the refactor where we simplified ButtonModifers (commit 98470f5ec938454c986e34daf753f827c63b04a5)
    /// Edit:
    /// I think this is primarily so the drag modification is deactivated after hold has been triggered. Not sure if this is desirable behaviour, generally. It's desirable in addMode, but we should probably implement another mechanism where ModifiedScroll is reloaded when addMode is deactivated that would make this obsolete.
    // -> TODO: Try to do this when we implement SwitchMaster. Then turn this off if successful.
    /// Edit: I do think that killing a button as a modifier after it has directly triggered an action is desirable, now.
    
    /// Copy old state
    
    /// Update state
    BOOL didRemove = removeStateForButton(_state, button);
    
    if (didRemove) {
        
        /// Debug
        if (runningPreRelease()) {
            NSString *description = stateDescription(_state);
            DDLogDebug(@"buttonModifiers - update - toState: %@", description);
        }
        
        /// Notify
        [Modifiers buttonModsChangedTo:_state];
    }
}

/// Helper

static BOOL removeStateForButton(ButtonModifierState state, MFMouseButtonNumber button) {
    
    /// Returns YES if it did remove an entry from the state
    
    for (int i = 0; i < state.count; i++) {
        
        NSDictionary *buttonState = state[i];
        NSNumber *buttonNumber = buttonState[kMFButtonModificationPreconditionKeyButtonNumber];
        
        if (buttonNumber.intValue == button) {
            
            [state removeObjectAtIndex:i];
            return YES;
        }
    }
    
    return NO;
}

/// Debug

static NSString *stateDescription(ButtonModifierState state) {
    
    NSMutableString *result = [NSMutableString string];
    BOOL isFirstIteration = YES;
    
    for (NSDictionary *buttonState in state) {
        
        if (!isFirstIteration) [result appendString:@" "];
        isFirstIteration = NO;
        
        NSString *elementString = stringf(@"(%@, %@)", buttonState[kMFButtonModificationPreconditionKeyButtonNumber], buttonState[kMFButtonModificationPreconditionKeyClickLevel]);
        [result appendString:elementString];
    }
    
    return result;
}


@end
