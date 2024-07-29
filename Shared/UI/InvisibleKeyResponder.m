//
// --------------------------------------------------------------------------
// InvisibleKeyResponder.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "InvisibleKeyResponder.h"
#import "NSString+Steganography.h"
#import "Carbon/Carbon.h"
#import "IBUtility.h"

///
/// This lets us perform actions when the user hits a key, without having to create a visible UI Element in interface builder.
///
/// How to use:
/// - Add a customView in IB as a subview of the view that you want to react to the keyboard.
/// - Set the customView's class to InvisibleKeyResponder
/// - Set it's keyEquivalent to a character like 'A" or to a literal string defined in IBUtility such as "return" or "escape".
///     - Optionally set the modifiers to a literal string specified in IBUtility such as "option" or "command, shift".
/// - Set its action outlet to the function you want to be performed, when the user hits the key.
///
/// See Apple's article  EventOverview/EventArchitecture for more on keyEquivalents and how they interact with the responder chain.
///
/// TODO:
///     (Update: Everything done)
///
/// 1. Go through all the .xib files and programatically created sheets, windows, etc, and use this to make them dismissable with `escape` (That's what we built this for.) (At least make sheets and alerts dismissable, not sure about toasts and stuff.)
///     - I can think of the following that we should update:
///         - x Buttons options sheet -> Done by adding an InvisibleKeyResponder subview with esc key-equivalent)
///         - x mail popup -> Done by setting esc key-equivalent on back button in code
///         - x License sheet -> Done by setting esc key-equivalent on back-button
///         - x Authorizeaccessibility sheet -> Already had esc key-equivalent on back-button
///         - x restore-buttons-alert (Was seemingly already esc-dismissable due to AppKit magic when labling a button 'Cancel', but we set the key-equivalents in code to make sure..)
///
///     > Should perhaps also update (but not sure)
///         - x Restore Defaults Popover  -> Not doing this (Reason: You wouldn't expect it to have keyboard focus)
///         - x general toasts -> Not doing this (Reason: You wouldn't expect it to have keyboard focus)
///         - x trial notifications (displayed by helper) -> Not doing this (Reason: Wouldn't expect this to have keyboard focus)
///         - x buy-mouse-alert -> Not doing this (Reason: This isn't even implemented but we added a not in case we do implement it.)
///         - x is-strange-helper-alert -> Not doing this. (Reason: The showPersistenNotificationWithTitle: is supposed to be hard to dismiss.)

/// 2. Test if ClickableImageView still works after the refactor
///     - x on accesssibility sheet
///     - x on about tab
/// 3. Other
///     - x Use our newfound knowledge of responder chains and stuff to stop the app from OUF ing when htting escape while there's nothing to dismiss.
///         (Couldn't figure out how to do this. Even if we override [NSResponder noResponderFor:] to prevent it from from beeping, [NSWindow doCommandBySelector:] will still beep, and we can't just override that bc it's doing important things.

IB_DESIGNABLE
@interface InvisibleKeyResponder ()

@property (strong, nonatomic) IBInspectable NSString *keyEquivalent;
@property (assign, nonatomic) IBInspectable NSString *modifiers;

@end

@implementation InvisibleKeyResponder {
    UTF32Char _keyEquivalentChar;
    NSEventModifierFlags _keyEquivalentModifierMask;
}

///
/// Lifecycle
///

- (void)awakeFromNib {
    
    /// Preprocess keyEquivalent string
    NSString *m = [IBUtility keyCharForLiteral:_keyEquivalent];
    if (m != nil) {
        _keyEquivalent = m;
    }
    assert(_keyEquivalent.length == 1);
    _keyEquivalentChar = [[[_keyEquivalent UTF32Characters] firstObject] intValue];
    
    /// Preprocess modifiers
    _keyEquivalentModifierMask = [IBUtility modifierMaskForLiteral:_modifiers];
    
    /// Check action stuff
    assert(self.action != NULL && self.target != nil);
}

///
/// Key intercept
///

- (BOOL)performKeyEquivalent:(NSEvent *)event {
    
    if (_keyEquivalentChar == 0) {
        return NO;
    }
    
    UTF32Char eventChar = event.charactersIgnoringModifiers.UTF32Characters.firstObject.intValue; /// Getting all UTF32 chars here is pretty unnecessary and little inefficient I think. Why not use `[NSString -characterAtIndex:]`?
    NSEventModifierFlags eventMods = event.modifierFlags;

    BOOL charMatches = eventChar == _keyEquivalentChar;
    BOOL flagsMatch = (eventMods & _keyEquivalentModifierMask) == _keyEquivalentModifierMask;
    
    if (charMatches && flagsMatch) {
        
        [self sendAction:self.action to:self.target];
        
        return YES;
        
    }
    
    return NO;
}

@end
