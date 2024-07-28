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
/// See Apples article "Event Architecture" for more on keyEquivalents and how they interact with the responder chain.
///
/// TODO:
/// 1. Go through all the .xib files and programatically created sheets, windows, etc, and use this to make them dismissable with `escape` (That's what we built this for.) (At least make sheets and alerts dismissable, not sure about toasts and stuff.)
///     - At the time of writing (summer 2024) we know that the following are already escape-dismissible: mail popup (bc we just added custom code), Buttons options sheet (because we added an InvisibleKeyResponder), restore defaults alert (already was dismissible, I think due to AppKit magic bc the back button is labled 'Cancel').
///     - I can think of the following that we should update:
///         - License sheet,
///         - Authorizeaccessibility sheet
///         - Restore defaults alert (make it dismissible with custom code instead of relying on AppKit magic)
///         > Should perhaps also update (but probably not sure)
///             - trial notifications (displayed by helper),
///             - buy-mouse-alert,
///             - Restore Defaults Popover ,
///             - is-strange-helper-alert
///             - general toasts,
/// 2. Use our newfound knowledge of responder chains and stuff to stop the app from OUF ing when htting escape while there's nothing to dismiss.
/// 3. Test if ClickableImageView still works after the refactor
///     - on accesssibility sheet
///     - on about tab
///

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
