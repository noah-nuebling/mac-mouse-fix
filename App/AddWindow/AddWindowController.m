//
// --------------------------------------------------------------------------
// AddWindowController.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "AddWindowController.h"
#import "AppDelegate.h"
#import "MessagePort_App.h"
#import "RemapTableController.h"
#import "Utility_App.h"
#import "SharedUtility.h"
#import "MFNotificationController.h"
#import "NSAttributedString+Additions.h"
#import "UIStrings.h"

@interface AddWindowController ()
@property (weak) IBOutlet NSBox *addField;
@property (weak) IBOutlet NSImageView *plusIconView;
@end

@implementation AddWindowController

static AddWindowController *_instance;
static BOOL _pointerIsInsideAddField;
// Init
+ (void)initialize {
    _instance = [[AddWindowController alloc] initWithWindowNibName:@"AddWindow"];
    _pointerIsInsideAddField = NO;
}
- (void)windowDidLoad {
    [super windowDidLoad];
    // Setup tracking area
    NSTrackingArea *addTrackingArea = [[NSTrackingArea alloc] initWithRect:self.addField.frame options:NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways | NSTrackingEnabledDuringMouseDrag owner:self userInfo:nil];
    // (Well I can't use ad tracking cause I claim to be privacy focused on the website, but at least I can use add tracking! Hmu if you can think of a way to monetize that.)
    [self.window.contentView addTrackingArea:addTrackingArea];
}

// UI callbacks

- (IBAction)cancelButton:(id)sender {
    [AddWindowController end];
}
- (void)mouseEntered:(NSEvent *)event {
    _pointerIsInsideAddField = YES;
    [AddWindowController enableAddFieldHoverEffect:YES];
    [MessagePort_App sendMessageToHelper:@"enableAddMode"];
}
- (void)mouseExited:(NSEvent *)event {
    _pointerIsInsideAddField = NO;
    [AddWindowController enableAddFieldHoverEffect:NO];
    [MessagePort_App sendMessageToHelper:@"disableAddMode"];
}

// Interface

+ (void)begin {
    [AppDelegate.mainWindow beginSheet:_instance.window completionHandler:^(NSModalResponse returnCode) {
        dispatch_async(dispatch_get_main_queue(), ^{
        });
    }];
}
+ (void)end {
    [AppDelegate.mainWindow endSheet:_instance.window];
}
+ (void)handleReceivedAddModeFeedbackFromHelperWithPayload:(NSDictionary *)payload {
    // Tint plus icon to give visual feedback
    NSImageView *plusIconViewCopy;
    if (@available(macOS 10.14, *)) {
        plusIconViewCopy = (NSImageView *)[SharedUtility deepCopyOf:_instance.plusIconView];
        [_instance.plusIconView.superview addSubview:plusIconViewCopy];
        plusIconViewCopy.alphaValue = 0.0;
        plusIconViewCopy.contentTintColor = NSColor.controlAccentColor;
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
            NSAnimationContext.currentContext.duration = 0.2;
            plusIconViewCopy.animator.alphaValue = 0.3;
            [NSThread sleepForTimeInterval:NSAnimationContext.currentContext.duration];
        }];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [self wrapUpAddModeFeedbackHandlingWithPayload:payload andPlusIconViewCopy:plusIconViewCopy];
        });
    } else {
        [self wrapUpAddModeFeedbackHandlingWithPayload:payload andPlusIconViewCopy:plusIconViewCopy];
    }
}
+ (void)wrapUpAddModeFeedbackHandlingWithPayload:(NSDictionary * _Nonnull)payload andPlusIconViewCopy:(NSImageView *)plusIconViewCopy {
    // Dismiss sheet
    [self end];
    // Send payload to RemapTableController
    //      The payload is an almost finished remapsTable (aka RemapTableController.dataModel) entry with the kMFRemapsKeyEffect key missing
    [((RemapTableController *)AppDelegate.instance.remapsTable.delegate) addRowWithHelperPayload:(NSDictionary *)payload];
    // Reset plus image tint
    if (@available(macOS 10.14, *)) {
        plusIconViewCopy.alphaValue = 0.0;
        [plusIconViewCopy removeFromSuperview];
        _instance.plusIconView.alphaValue = 1.0;
    }
}

+ (void)enableAddFieldHoverEffect:(BOOL)enable {
    // None of this works
    NSBox *af = _instance.addField;
    NSView *afSub = _instance.addField.subviews[0];
    if (enable) {
        afSub.wantsLayer = YES;
        af.wantsLayer = YES;
        af.layer.masksToBounds = NO;
        
        // Shadow (doesn't work withough setting background color)
//        NSShadow *shadow = [[NSShadow alloc] init];
//        shadow.shadowColor = NSColor.blackColor;
//        shadow.shadowOffset = NSZeroSize;
//        shadow.shadowBlurRadius = 10;
//        afSub.shadow = shadow;
        
        // Focus ring
        afSub.focusRingType = NSFocusRingTypeDefault;
        [afSub becomeFirstResponder];
        af.focusRingType = NSFocusRingTypeDefault;
        [af becomeFirstResponder];
    } else {
        // Shadow
        afSub.shadow = nil;
        afSub.layer.shadowOpacity = 0.0;
        afSub.layer.backgroundColor = nil;
        // Focus ring
        [afSub resignFirstResponder];
        
    }
}

// TODO: Use format strings and shared functions from UIStrings.m to obtain button names

- (void)mouseUp:(NSEvent *)event {
    if (!_pointerIsInsideAddField) return;
    NSAttributedString *message = [[NSAttributedString alloc] initWithString:@"Mac Mouse Fix can't assign functions to the Primary Mouse Button. Please try another Button."];
//    message = [message attributedStringByAddingLinkWithURL:[NSURL URLWithString:@"https://google.com"] forSubstring:@"Primary Mouse"];
    [MFNotificationController attachNotificationWithMessage:message toWindow:_instance.window];
}
- (void)rightMouseUp:(NSEvent *)event {
    if (!_pointerIsInsideAddField) return;
    NSAttributedString *message = [[NSAttributedString alloc] initWithString:@"Mac Mouse Fix can't assign functions to the Secondary Mouse Button. Please try another Button."];
    [MFNotificationController attachNotificationWithMessage:message toWindow:_instance.window];
}

@end

