//
// --------------------------------------------------------------------------
// ToastController.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// Medium article on views with rounded corners and shadows:
///      https://medium.com/swifty-tim/views-with-rounded-corners-and-shadows-c3adc0085182
///      -> Using overlay window instead

/// Also see `TrialNotificationController.swift`

#import "ToastController.h"
#import "AppDelegate.h"
#import "Utility_App.h"
#import "Toast.h"
//#import "NSTextField+Additions.h"
#import "NotificationLabel.h"
#import "NSAttributedString+Additions.h"
#import "LocalizationUtility.h"
#import "Mac_Mouse_Fix-Swift.h"

@interface ToastController ()

@property (unsafe_unretained) IBOutlet NotificationLabel *label;

@end

@implementation ToastController {
}

static ToastController *_instance;
static NSDictionary *_labelAttributesFromIB;
static id _localClickMonitor;
static id _localEscapeKeyMonitor;

+ (void)initialize {
    
    if (self == [ToastController class]) {
        
        /// Setup window closing notification
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(windowResignKey:) name:NSWindowDidResignKeyNotification object:nil];
        
        /// Setup notfication window
        _instance = [[ToastController alloc] initWithWindowNibName:@"Toast"];
        
        NSPanel *w = (NSPanel *)_instance.window;
        
        w.styleMask =  NSWindowStyleMaskTitled | NSWindowStyleMaskFullSizeContentView;
        w.titlebarAppearsTransparent  =   YES;
        w.titleVisibility             =   NSWindowTitleHidden;
        w.movable = NO;
        
        /// Remove scrollView edge insets, because those are nothing but trouble (cause links to be not clickable and stuff)
        NSScrollView *scrollView = (NSScrollView *)_instance.label.superview.superview;
        scrollView.automaticallyAdjustsContentInsets = NO; // Doesn't remove insets // Probably calling this too late
        scrollView.contentInsets = NSEdgeInsetsMake(0, 0, 0, 0);
        /// Disable scrollView elasticity while we're at it to make it seem like it's not even there
        scrollView.verticalScrollElasticity = NSScrollElasticityNone;
        scrollView.horizontalScrollElasticity = NSScrollElasticityNone;
        
        /// Get default label text attributes
        _labelAttributesFromIB = [_instance.label.attributedString attributesAtIndex:0 effectiveRange:nil];
    }
}

static double _animationDurationFadeIn = 0.3;
static double _animationDurationFadeOut = 0.2;
static double _toastAnimationOffset = 20;

typedef enum {
    kToastNotificationAlignmentTopMiddle, /// Only kToastNotificationAlignmentTopMiddle is used.
    kToastNotificationAlignmentBottomRight,
    kToastNotificationAlignmentBottomMiddle,
} ToastNotificationAlignment;

/// Convenience function
+ (void)attachNotificationWithMessage:(NSAttributedString *)message toWindow:(NSWindow *)window forDuration:(NSTimeInterval)showDuration {
    
    [self attachNotificationWithMessage:message toWindow:window forDuration:showDuration alignment:kToastNotificationAlignmentTopMiddle];
}

+ (void)attachNotificationWithMessage:(NSAttributedString *)message toWindow:(NSWindow *)attachWindow forDuration:(NSTimeInterval)showDuration alignment:(ToastNotificationAlignment)alignment {

    /// Arguments:
    /// - Pass `kMFToastDurationAutomatic` to `showDuration` to get the default duration
    
    /// Override default font size from interface builder. This also overrides font size we set to `message` before passing it to this function which might be bad.
//    message = [message attributedStringBySettingFontSize:NSFont.smallSystemFontSize];
    
    /// Process showDuration
    if (showDuration < 0) {
        assert(showDuration == kMFToastDurationAutomatic);
        showDuration = message.length * 0.08 * [LocalizationUtility informationDensityOfCurrentLanguage];
    } else {
        showDuration *= [LocalizationUtility informationDensityOfCurrentLanguage]; /// Why would we multiply with information density if the duration is specified by the caller? Note: this Is called with 10.0 at k-enable-timeout-toast, in all other cases it's called with automatic duration (Summer 2024)
    }
    
    /// Constants
    double mainWindowTitleBarHeight = 0.0;
    double topEdgeMargin = 0.0;
    double sideMargin = 0.0;
    double bottomMargin = 0.0;
    
    if (alignment == kToastNotificationAlignmentTopMiddle) {
        mainWindowTitleBarHeight = 17;
        topEdgeMargin = 5.0; /// 0.0 // -25.0
        sideMargin = 2; /// In MMF 3 the views are so narrow that the notifications maybe should be allowed to spill out.
        _toastAnimationOffset = 20;
    } else if (alignment == kToastNotificationAlignmentBottomRight){
        bottomMargin = 10;
        sideMargin = 5;
        _toastAnimationOffset = -20;
    } else if (alignment == kToastNotificationAlignmentBottomMiddle) {
        bottomMargin = 10;
        sideMargin = 5;
        _toastAnimationOffset = -20;
    } else assert(false);
    
    /// Close existing notification
    ///     This is a TEST to maybe prevent seeming raceconditions seen during our LocalizationScreenshot tests where the escapeKey monitor seemingly never got removed after screenshotting toasts on the licensesheet window.
    [self closeNotificationWithFadeOut];
    
    /// Execution
    
    /// Get existing notif instance and close
    NSPanel *w = (NSPanel *)_instance.window;
    NSWindow *mainW = NSApp.mainWindow;
    [w close];
    
    /// Set message text and text attributes to label
    message = [message copy];
    NSDictionary *baseAttributes = _labelAttributesFromIB;
    message = [message attributedStringByAddingStringAttributesAsBase:baseAttributes];
    message = [message attributedStringByFillingOutBase];
    
    [_instance.label.textStorage setAttributedString:message];

    DDLogDebug(@"Attaching notification with attributed string: %@", message);
    
    /// Set notification frame
    
    /// Calc size to fit content
    NSRect newWindowFrame = w.frame;
    
    /// Get insets around label
    ///     We used to implement the insets by just having an actual margin between the scrollView and the windowFrame. But this cut off emojis a little bit, so we are now setting the insets via textContainerInsets instead. We changed a few things for this.
    ///     Last commit before the change: 47d97be6482df3c37898c3c6cd5c21c6be02ab4a
    
//    NSRect notifFrame = w.frame;
    
//    NSRect scrollViewFrame = label.superview.superview.frame; /// Label is embedded in clipView and ScrollView
    
    /// Old method
//    CGFloat bottomInset = scrollViewFrame.origin.y;
//    CGFloat topInset = notifFrame.size.height - (scrollViewFrame.size.height + bottomInset);
//    CGFloat leftInset = scrollViewFrame.origin.x;
//    CGFloat rightInset = notifFrame.size.width - (scrollViewFrame.size.width + leftInset);
//    assert(leftInset == rightInset);
    
    /// New method
    CGFloat bottomInset = _instance.label.textContainerInset.height;
    CGFloat topInset = _instance.label.textContainerInset.height;
    CGFloat leftInset = _instance.label.textContainerInset.width;
    CGFloat rightInset = _instance.label.textContainerInset.width;
    
    /// Calculate new text size
    CGFloat maxTextWidth = mainW.frame.size.width - 2*sideMargin - leftInset - rightInset;
    NSSize newTextSize = [_instance.label.attributedString sizeAtMaxWidth:maxTextWidth];
    
    /// Adjust newTextSize for lineFragmentPadding.
    ///     See https://stackoverflow.com/questions/13621084/boundingrectwithsize-for-nsattributedstring-returning-wrong-size
    ///     ... Actually this breaks short "Primary Mouse Button can't be used" notifications.
    ///     Update: Seems necessary after updating sizeAtMaxWidth to new TextKit 2 methods. ... Update2: And it works perfectly with the TextKit 1 methods as well after we fixed them.
    CGFloat padding = _instance.label.textContainer.lineFragmentPadding; /// TESTING
    newTextSize.width += padding * 2;
    
    /// Calculate new window frame
    NSSize newWindowSize = NSMakeSize(newTextSize.width + leftInset + rightInset, newTextSize.height + topInset + bottomInset);
    newWindowFrame.size = newWindowSize;
    
    /// Calc Position
    
    if (alignment == kToastNotificationAlignmentTopMiddle) {
        /// Top middle alignment
        newWindowFrame.origin.x = NSMidX(mainW.frame) - (newWindowSize.width / 2);
        newWindowFrame.origin.y = (mainW.frame.origin.y + mainW.frame.size.height - (mainWindowTitleBarHeight + topEdgeMargin)) - newWindowSize.height;
    } else if (alignment == kToastNotificationAlignmentBottomRight) {
        /// Bottom right alignment
        newWindowFrame.origin.x = mainW.frame.origin.x + mainW.frame.size.width - newWindowFrame.size.width - sideMargin;
        newWindowFrame.origin.y = mainW.frame.origin.y + bottomMargin;
    } else if (alignment == kToastNotificationAlignmentBottomMiddle) {
        newWindowFrame.origin.x = NSMidX(mainW.frame) - (newWindowSize.width / 2);
        newWindowFrame.origin.y = mainW.frame.origin.y + bottomMargin;
    } else assert(false);
    
    /// Set new notification frame
    [w setFrame:newWindowFrame display:YES];
    
    /// Set label frame (Don't actually need this if we set autoresizing for the label in IB, which we do)
//    NSRect newLabelFrame = label.superview.superview.frame;
//    newLabelFrame.size = newTextSize;
//    newLabelFrame.origin.x = NSMidX(label.superview.bounds) - (newTextSize.width / 2);
//    newLabelFrame.origin.y = NSMidY(label.superview.bounds) - (newTextSize.height / 2);
//    [label setFrame:newLabelFrame];
    
    /// Attach notif as child window to attachWindow
    [attachWindow addChildWindow:w ordered:NSWindowAbove];
    [attachWindow makeKeyWindow];
    
    /// Fade and animate the notification window in
    /// Set pre animation alpha
    w.alphaValue = 0.0;
    
    /// Set pre animation position
    NSRect targetFrame = w.frame;
    NSRect preAnimFrame = w.frame;
    preAnimFrame.origin.y += _toastAnimationOffset;
    [w setFrame:preAnimFrame display:NO];
    
    /// Animate
    [NSAnimationContext beginGrouping];
    NSAnimationContext.currentContext.duration = _animationDurationFadeIn;
    w.animator.alphaValue = 1.0;
    [w.animator setFrame:targetFrame display:YES];
    [NSAnimationContext endGrouping];
    
    /// Close if user clicks elsewhere
    _localClickMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:(NSEventMaskLeftMouseDown) handler:^NSEvent * _Nullable(NSEvent * _Nonnull event) {
        
        NSPoint loc = NSEvent.mouseLocation;
        
        /// Check where mouse is located relative to other stuff
        ///     Since we track mouseHover now, we might be able to reuse that here, instead of this hit-test stuff obsolete? Edit: I don't think so, since here, we don't *only* check if the cursor is over the toast.
        
        /// Get mouse location in the main content views' coordinate system. Need this to do a hit-test later.
        NSView *mainContentView = MainAppState.shared.window.contentView;
        NSPoint locWindow = [MainAppState.shared.window convertRectFromScreen:(NSRect){.origin=loc}].origin; /// convertPointFromScreen: only available in 10.12+
        NSPoint locContentView = [mainContentView convertPoint:locWindow fromView:nil];
        
        /// Analyze where the user clicked
        BOOL locIsOverNotification = [NSWindow windowNumberAtPoint:NSEvent.mouseLocation belowWindowWithWindowNumber:0] == _instance.window.windowNumber; /// So notification isn't dismissed when we click on it. Not sure if necessary when we're using `locIsOverMainWindowContentView`.
        BOOL locIsOverMainWindowContentView = [mainContentView hitTest:locContentView] != nil; /// So that we can drag the window by its titlebar without dismissing the notification.
        
        /// Close the notification
        if (!locIsOverNotification && locIsOverMainWindowContentView) {
            [_showDurationTimer invalidate];
            [self closeNotificationWithFadeOut];
        }
        
        /// Pass through event
        return event;
    }];
    
    /// Close if user hits escape
    ///     Adding this to more easily automate the UI for our localizationScreenshots, but I think it's also nice UX.
    _localEscapeKeyMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:(NSEventMaskKeyDown) handler:^NSEvent * _Nullable(NSEvent * _Nonnull event) {
        
        /// Guard: is escape key
        BOOL isEscape = event.keyCode == kVK_Escape;
        if (!isEscape) return event;
        
        /// Close the notification
        [_showDurationTimer invalidate];
        [self closeNotificationWithFadeOut];
        
        /// Don't pass through event
        ///     Otherwise we get NSBeep'ed
        return nil;
    }];
    
    /// Track mouse hover
    ///     This is to keep the notification from timing out, if the cursor hovers over it
    
    _toastTrackingArea = [[NSTrackingArea alloc] initWithRect:w.contentView.bounds
                                                                options:NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways
                                                                  owner:self userInfo:nil];
    
    [w.contentView addTrackingArea:_toastTrackingArea];
    
    /// Track showDuration
    [_showDurationTimer invalidate];
    _showDurationTimer = [NSTimer scheduledTimerWithTimeInterval:showDuration target:self selector:@selector(onShowDurationExpired:) userInfo:nil repeats:NO];
}

#pragma mark Track toastHover

static NSTrackingArea *_toastTrackingArea;
static BOOL _mouseIsOverToast = NO;

+ (void)mouseEntered:(NSEvent *)event {
    /// The mouse has entered the notifications content view
    
    _mouseIsOverToast = YES;
    [self decideOverNotificationClose];
}
+ (void)mouseExited:(NSEvent *)event {
    /// The mouse has left the notifications content view
    
    _mouseIsOverToast = NO;
    [self decideOverNotificationClose];
}
 
#pragma mark Track showDuration

static NSTimer *_showDurationTimer;
+ (void)onShowDurationExpired:(NSTimer *)timer {
    
    /// Validate
    assert([timer isEqual:_showDurationTimer]);
    
    /// Invalidate the timer
    ///     Note: After the timer fires, I thought it invalidates itself, but `timer.isValid` seems to be true in here (if I didn't test wrong)
    [_showDurationTimer invalidate];
    _showDurationTimer = nil;
    
    /// Signal the decide method
    [self decideOverNotificationClose];
}

//+ (void)closeNotification:(NSTimer *)timer {
//    
//    dispatch_async(dispatch_get_main_queue(), ^{ /// Necessary under Ventura Beta for animations to work (this function used to be called by the showDuration timer)
//        [self closeNotificationWithFadeOut];
//    });
//}

#pragma mark Close the Toast

+ (void)decideOverNotificationClose {
    
    BOOL showDurationIsOver = _showDurationTimer == nil;
    
    DDLogDebug(@"ToastController - showDurationIsOver: %d, !mouseIsOverToast: %d", showDurationIsOver, !_mouseIsOverToast);
    
    if (showDurationIsOver && !_mouseIsOverToast) {
        
        dispatch_async(dispatch_get_main_queue(), ^{ /// Necessary under Ventura Beta for animations to work (at that point the calling logic was different, e.g. now we also call this from the mouseEntered/mouseExited callbacks)
            [self closeNotificationWithFadeOut];
        });
        
    }
}

+ (void)closeNotificationWithFadeOut {
    
    cleanupForNotificationClose();
    
    NSPanel *w = (NSPanel *)_instance.window;
        
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
       
        /// Set duration
        context.duration = _animationDurationFadeOut;
        
        /// Animate opacity
        w.animator.alphaValue = 0.0;
        
        /// Animate position
        NSRect postAnimFrame = w.frame;
        postAnimFrame.origin.y += _toastAnimationOffset;
        [w.animator setFrame:postAnimFrame display:YES];
    }];
}

+ (void)closeNotificationImmediately {
    
    cleanupForNotificationClose();
    
    NSPanel *w = (NSPanel *)_instance.window;
    [w orderOut:nil];
}

static void cleanupForNotificationClose(void) {
    
    /// Helper function for closing the notification
    
    /// Remove the local event monitors
    if (_localClickMonitor != nil) {
        [NSEvent removeMonitor:_localClickMonitor];
        _localClickMonitor = nil;
    }
    if (_localEscapeKeyMonitor != nil) {
        [NSEvent removeMonitor:_localEscapeKeyMonitor];
        _localEscapeKeyMonitor = nil;
    }
    
    /// Remove the tracking area
    /// Notes:
    /// - This is necessary to deactivate the tracking area, otherwise mouseExited: and mouseEntered: keep getting called. We also have to do this before replacing `_instance.window` with a new window instance for it work I think. I think we could theoretically do this right before we replace the content of `_instance.window`, but I think it's easier to do it here.
    NSPanel *w = (id)_instance.window;
    [w.contentView removeTrackingArea:_toastTrackingArea];
    [w.contentView updateTrackingAreas]; /// Not sure what this does, or if it's necessary
}

+ (void)windowResignKey:(NSNotification *)notification {
    
    /// We use this to close the notification when the window which it is attached to resigns key.
    /// This prevents some jank when closing and then reopening the AddWindow while a notification is attached to it
    /// This won't work when using `closeNotificationWithFadeOut` instead of `closeNotificationImmediately` because of some conflicts between animations or something.
    /// This could also lead to weird behaviour whhen a notification starts to display while the Mac Mouse Fix window it attaches to is not in the foreground
    /// What we really want to do here is to close the notification as soon as the window whcih is it's parent becomes invisible, but I haven't found a way to do that. So we're resorting to tracking key status.
    /// This hacky solution might cause more weirdness and jank than it's worth.
    /// Edit: Under MMF 3 there are situations where it's sometimes nice if the Toast still stays up when the app is in the background. E.g. the `is-strange-helper-alert` contains a list of instruction containing a link into Finder. When you click the link it's nice if the instructions stay up. -> Consider changing / removing this
    
    NSWindow *closedWindow = notification.object;
    
    if ([_instance.window.parentWindow isEqual:closedWindow]) {
        [_showDurationTimer invalidate];
        [self closeNotificationImmediately];
    }
}

#pragma mark - Other interface

+ (NSFont *)defaultFont {
    /// At the time of writing this is only used from outside ToastController not inside - so I hope this is correct! Should we use `labelFontSize` instead?
    return [NSFont systemFontOfSize:NSFont.systemFontSize];
}

@end
