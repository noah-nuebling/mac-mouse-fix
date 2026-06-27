//
// --------------------------------------------------------------------------
// ModTapCoordinator.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Smart modifier detection: delays thumb button action to detect modifier intent
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "ModTapCoordinator.h"
#import "ButtonInputReceiver.h"
#import "SharedUtility.h"
#import "Mac_Mouse_Fix_Helper-Swift.h"

@implementation ModTapCoordinator {
    ModTapState _state;
    
    /// Pending modifier button info (held while undecided)
    NSUInteger _pendingButton;
    Device *_pendingDevice;
    CGEventRef _pendingEvent;
    
    /// Timer for tapping term
    NSTimer *_tappingTimer;
}

+ (instancetype)shared {
    static ModTapCoordinator *instance = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ instance = [self new]; });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _state = kModTapStateIdle;
        _tappingTerm = 0.18; /// 180ms default, same as QMK
        _pendingEvent = NULL;
    }
    return self;
}

/// Returns YES if the event was consumed/deferred by the mod-tap system
- (BOOL)handleButtonInput:(NSUInteger)buttonNumber
                   device:(Device *)device
                 mouseDown:(BOOL)mouseDown
                    event:(CGEventRef)event {
    
    /// Only engage if the primary button modifier layer is enabled
    BOOL layerEnabled = [(id)config(@"General.primaryButtonModifierLayer") boolValue];
    if (!layerEnabled) return NO;
    
    BOOL isModifierCapableButton = (buttonNumber >= 4); /// Buttons 4, 5, 6+ are thumb-accessible
    BOOL isPrimaryButton = (buttonNumber == 1 || buttonNumber == 2);
    
    switch (_state) {
            
        case kModTapStateIdle: {
            if (isModifierCapableButton && mouseDown) {
                /// Modifier-capable button pressed → enter undecided state
                _state = kModTapStateUndecided;
                _pendingButton = buttonNumber;
                _pendingDevice = device;
                if (_pendingEvent) CFRelease(_pendingEvent);
                _pendingEvent = CGEventCreateCopy(event);
                
                /// Start tapping term timer
                [_tappingTimer invalidate];
                _tappingTimer = [NSTimer scheduledTimerWithTimeInterval:_tappingTerm
                                                                target:self
                                                              selector:@selector(tappingTermExpired)
                                                              userInfo:nil
                                                               repeats:NO];
                
                /// Enable primary button interception
                [ButtonInputReceiver setPrimaryButtonModifierLayerActive:YES];
                
                DDLogDebug(@"ModTap: UNDECIDED — button %lu pressed, waiting %.0fms", (unsigned long)buttonNumber, _tappingTerm * 1000);
                return YES; /// Consume — don't forward yet
            }
            return NO; /// Not our business
        }
            
        case kModTapStateUndecided: {
            if (isPrimaryButton && mouseDown) {
                /// Primary button pressed while modifier is held → COMMIT AS MODIFIER
                _state = kModTapStateModifier;
                [_tappingTimer invalidate];
                _tappingTimer = nil;
                
                DDLogDebug(@"ModTap: MODIFIER — primary button %lu pressed, committing modifier %lu", (unsigned long)buttonNumber, (unsigned long)_pendingButton);
                
                /// Forward the pending modifier button press through normal Buttons path
                /// (This will register it as a button modifier via the normal flow)
                [Buttons handleInputWithDevice:_pendingDevice
                                       button:@(_pendingButton)
                                    downNotUp:YES
                                        event:_pendingEvent];
                
                /// Now let the primary button event pass through normally
                /// (It will be processed by Buttons with the modifier now active)
                return NO;
            }
            
            if (buttonNumber == _pendingButton && !mouseDown) {
                /// Modifier button released quickly → TAP (fire its own action)
                _state = kModTapStateTap;
                [_tappingTimer invalidate];
                _tappingTimer = nil;
                
                DDLogDebug(@"ModTap: TAP — button %lu released quickly, firing tap action", (unsigned long)_pendingButton);
                
                /// Disable primary button interception
                [ButtonInputReceiver setPrimaryButtonModifierLayerActive:NO];
                
                /// Forward both press and release through normal Buttons path
                [Buttons handleInputWithDevice:_pendingDevice
                                       button:@(_pendingButton)
                                    downNotUp:YES
                                        event:_pendingEvent];
                [Buttons handleInputWithDevice:device
                                       button:@(buttonNumber)
                                    downNotUp:NO
                                        event:event];
                
                /// Reset state
                [self resetState];
                return YES; /// Consumed — we forwarded manually
            }
            
            /// Another non-primary button pressed while undecided — treat as modifier too
            if (!isPrimaryButton && mouseDown && buttonNumber != _pendingButton) {
                /// Some other button pressed — commit as modifier
                _state = kModTapStateModifier;
                [_tappingTimer invalidate];
                _tappingTimer = nil;
                
                /// Forward pending modifier press
                [Buttons handleInputWithDevice:_pendingDevice
                                       button:@(_pendingButton)
                                    downNotUp:YES
                                        event:_pendingEvent];
                
                /// Let the new button event pass through normally
                return NO;
            }
            
            return NO;
        }
            
        case kModTapStateModifier: {
            if (buttonNumber == _pendingButton && !mouseDown) {
                /// Modifier button released → end modifier mode
                DDLogDebug(@"ModTap: MODIFIER RELEASED — button %lu", (unsigned long)_pendingButton);
                
                /// Disable primary button interception
                [ButtonInputReceiver setPrimaryButtonModifierLayerActive:NO];
                
                /// Let the release pass through normally (Buttons will handle modifier cleanup)
                [self resetState];
                return NO;
            }
            /// All other events pass through normally while in modifier state
            return NO;
        }
            
        case kModTapStateTap: {
            /// Shouldn't normally be in this state during event processing
            /// (resetState is called immediately after tap)
            [self resetState];
            return NO;
        }
    }
    
    return NO;
}

- (void)tappingTermExpired {
    if (_state != kModTapStateUndecided) return;
    
    /// Timer expired while undecided → commit as modifier (hold behavior)
    _state = kModTapStateModifier;
    
    DDLogDebug(@"ModTap: TAPPING TERM EXPIRED — committing button %lu as modifier", (unsigned long)_pendingButton);
    
    /// Forward the pending modifier button press
    [Buttons handleInputWithDevice:_pendingDevice
                            button:@(_pendingButton)
                         downNotUp:YES
                             event:_pendingEvent];
}

- (void)resetState {
    _state = kModTapStateIdle;
    if (_pendingEvent) {
        CFRelease(_pendingEvent);
        _pendingEvent = NULL;
    }
    _pendingDevice = nil;
    _pendingButton = 0;
}

- (void)dealloc {
    if (_pendingEvent) CFRelease(_pendingEvent);
    [_tappingTimer invalidate];
}

@end
