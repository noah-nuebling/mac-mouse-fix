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
static NSTimer *_showDurationTimer = nil;

+ (void)initialize {
    
    if (self == [ToastController class]) {
        
        /// Setup callback when the parent window closes
        [NSNotificationCenter.defaultCenter addObserver: self selector: @selector(windowResignKey:) name: NSWindowDidResignKeyNotification object: nil];
        
        /// Create singleton
        _instance = [[ToastController alloc] initWithWindowNibName: @"Toast"];
        
        /// Setup notfication window
        NSPanel *w = (NSPanel *)_instance.window;
        {
            w.styleMask =  NSWindowStyleMaskTitled | NSWindowStyleMaskFullSizeContentView;
            w.titlebarAppearsTransparent  =   YES;
            w.titleVisibility             =   NSWindowTitleHidden;
            w.movable = NO;
        }
        
        /// Remove scrollView edge insets, because those are nothing but trouble (cause links to be not clickable and stuff)
        NSScrollView *scrollView = (NSScrollView *)_instance.label.superview.superview;
        {
            scrollView.automaticallyAdjustsContentInsets = NO; /// Doesn't remove insets // Probably calling this too late
            scrollView.contentInsets = NSEdgeInsetsMake(0, 0, 0, 0);
            /// Disable scrollView elasticity while we're at it to make it seem like it's not even there
            scrollView.verticalScrollElasticity = NSScrollElasticityNone;
            scrollView.horizontalScrollElasticity = NSScrollElasticityNone;
        }
        
        /// Get default label text attributes
        _labelAttributesFromIB = [_instance.label.attributedString attributesAtIndex: 0 effectiveRange: NULL];
    }
}

- (void) windowDidLoad {
    [super windowDidLoad];
    
    /// Make views compact on Tahoe (Does this even make any difference on Toasts?) [Jul 9 2025]
    if (@available(macOS 26.0, *)) {
        self.window.contentView.prefersCompactControlSizeMetrics = YES;
    }
}

static double _animationDurationFadeIn = 0.3;
static double _animationDurationFadeOut = 0.2;
static double _toastAnimationOffset = 20;

typedef enum {
    kToastNotificationAlignment_TopMiddle, /// Only `kToastNotificationAlignment_TopMiddle` is used.
    kToastNotificationAlignment_BottomRight,
    kToastNotificationAlignment_BottomMiddle,
} ToastNotificationAlignment;

/// Convenience function
+ (void) attachNotificationWithMessage: (NSAttributedString *)message forDuration: (NSTimeInterval)showDuration {
    [self attachNotificationWithMessage: message forDuration: showDuration alignment: kToastNotificationAlignment_TopMiddle];
}

+ (void) attachNotificationWithMessage: (NSAttributedString *)message forDuration: (NSTimeInterval)showDuration alignment: (ToastNotificationAlignment)alignment {

    /// Usage:
    /// - Pass `kMFToastDurationAutomatic` to `showDuration` to get the default duration
    ///
    /// Implementation notes:
    ///     - Discussion: Why calculate the layout manually instead of using autolayout? [Sep 2025]
    ///         - Our `NotificationLabel` is an NSTextView, and NSTextView doesn't report an intrinsicContentSize, so autolayout doesn't know how big the NSTextView needs to be to prevent clipping content.
    ///         - Alternatives to manual calculation:
    ///             1. Use NSTextField
    ///                 - Pro: It *does* report an intrinsicContentSize, and could solve this layout, which would simplify the code a bit.
    ///                     > See our `NSTextViewSizeExperiments` test project.
    ///                 - Con: I thought there was a specific reason that we used NSTextView over NSTextField. But I can't find notes on it [Sep 2025]
    ///                     - Ah I think NSTextField didn't support clickable links or something?
    ///                         (^ Should maybe test this and then clarify these notes)
    ///             2. Override NSTextView's intrinsicContentSize
    ///                 - Contra: To make it work properly is more complicated than the current solution since we'd have to
    ///                     use private APIs and make the layout engine give us 2 passes and stuff (since the desired height depends on the width that the layoutEngine grants us.)
    ///                     > See our `NSTextViewSizeExperiments` test project
    ///                     ... The only reason to implement this might be if we need auto-resizing NSTextViews in multiple places in the app, but I don't think we do [Sep 2025]
    ///                 Update: [Oct 2025] We managed to make something like this work in `mf-xcloc-editor` (`MFTextField`) – maybe it's not so hard after all?  (But it's being dsplayed in an NSTableView with fixed-width columns which makes things less complicated – maybe that's why it works)
    ///
    /// Future ideas:
    ///     - For the Tahoe overhaul, maybe change the look to be capsule shaped like native iOS Toasts? (https://x.com/jsngr/status/1340317069359919104) [Sep 2025]
    ///         - Under Sequoia, the Toasts look almost identical to popovers – maybe we should keep that similarity for Tahoe.
    ///     - Maybe make the text selectable / copy-paste able [Sep 2025]
    ///
    /// Protocol:
    ///     Cleaned this up and deleted a bunch of old stuff in commit a95d5cddcc46acfc22d2113ce28aa4c146ff8587 [Sep 2025]
    
    
    /// Find windows
    ///     Why does our code need 2 windows? [Sep 2025]
    ///         The parent window should be the frontMost sheet, otherwise the toast will appear in the background with a dark overlay
    ///         The position should be relative to the mainWindow though, so the toast isn't crammed into a little sheet.
    NSWindow *parentWindow = MainAppState.shared.frontMostWindowOrSheet;
    NSWindow *mainWindow   = MainAppState.shared.window;
    if (!parentWindow) parentWindow = mainWindow; /// Not sure this ever happens but why not [Sep 2025]
    if (!mainWindow) return;
    
    /// Process showDuration
    if (showDuration < 0) {
        assert(showDuration == kMFToastDurationAutomatic);
        showDuration = (message.length * [LocalizationUtility informationDensityOfCurrentLanguage]) * 0.08;
    } else {
        showDuration *= [LocalizationUtility informationDensityOfCurrentLanguage]; /// Why would we multiply with information density if the duration is specified by the caller? Note: this Is called with 10.0 at k-enable-timeout-toast, in all other cases it's called with automatic duration (Summer 2024)
    }
    
    /// Process message
    
    {
        /// Give first line 'title' style and give remaining lines 'hint' style
        ///     Discussion: [Sep 2025]
        ///         Context / Why we're doing this:
        ///             Before, the toast messages were single localizable strings with some markdown markup.
        ///             But the way the messages were written there was this pattern, where the first line was also an easily scannable 'title' and the next lines gave extra context.
        ///                 We also often made the whole or parts of the first line bold to make it more 'title-ly'
        ///             Problem: The problem was that for our new capture Toast messages (`%2$@ is no longer captured by Mac Mouse Fix\nThe button now works as if Mac Mouse Fix was disabled`),
        ///                 the second line was longer than the first, which made it not feel like its 'secondary' to the first line anymore.
        ///                 Only solutions I could think of is a) shorten the second line, or b) make it feel 'secondary' by changing the font.
        ///                     We first implemented the different font in CapturedToasts.m (See `useSmallHintStyling`{Update: Removed in commit fb78175}), but having this style *only* for the CaptureToasts also felt weird.
        ///                     So we're activating this style for all the Toasts here!
        ///         Questionable:
        ///             - This is a little 'magical'. We could instead have separate args for the title and subtitle, but then we'd kinda have to split up all the localizable strings into title and subtitle and I'm too lazy for that now. This approach also may be more flexible, since the caller could theoretically override the hint styling, which I might use for the 'Learn More' links at the end of the CaptureToasts.
        ///             - `attributedStringByTrimmingWhitespace` is a bit of a hack. Before, we had some toasts with a single and others with a double linebreak after the first 'title' line. But that looks weird now. The 'semantic' difference is still in the localizable strings but not displayed anymore.
        {
            auto splitMessage    = [message split: @"\n" maxSplit: 1];
            if (splitMessage.count > 1) {
                auto messageTitle    = splitMessage.firstObject;
                auto messageSubtitle = splitMessage.lastObject;
                
                messageTitle    = [messageTitle    attributedStringByTrimmingWhitespace];
                messageSubtitle = [messageSubtitle attributedStringByTrimmingWhitespace]; /// Remove double linebreaks. See discussion above.
                { /// Prepend separator to messageSubtitle
                    NSAttributedString *separator = [@"\n\n" attributed];
                    if ((1)) {
                        /// Set separator size
                        ///     Discussion: [Oct 2025]
                        ///         - By setting the separator size to 4.0, the margin above and below the title looks equal.
                        ///         - But that makes paragraph gaps inside the subtitle larger than the gap between the title and subtitle. Which seems awkward, but it looks fine to me. We can leave the separator size equal to the subtitle size to make those gaps equal.
                        separator = [separator attributedStringBySettingFontSize: 4.0];
                    }
                    messageSubtitle = astringf(@"%@%@", separator, messageSubtitle);
                }
                
                messageTitle    = [messageTitle    attributedStringByFillingOutBase];
                messageSubtitle = [messageSubtitle attributedStringByFillingOutBaseAsHint]; /// Style everything after the first line as greyed out, small, hint text
                
                message = astringf(@"%@%@", messageTitle, messageSubtitle);
            }
            else {
                message = [message attributedStringByFillingOutBase];
            }
        }
        
        message = [message attributedStringByAddingAttributesAsBase: _labelAttributesFromIB]; /// This makes the text centered, prevents orphaned words (`NSLineBreakStrategyPushOut`). Not sure if anything else [Sep 2025] || Orphan-prevention doesn't seem to work (at least in German) Not sure why. `NSLineBreakStrategyPushOut` is present. [Oct 2025]
    }
    
    /// Set message
    [_instance.label.textStorage setAttributedString: message];

    /// Debug
    DDLogDebug(@"Toast has attributed string: %@", message);
    
    /// Get constants
    
    double mainWindowTitleBarHeight = 17; /// [Sep 2025] This should probably be varied by macOS version! (Or maybe there's a builtin method for this?) (Maybe see our pull request for Sparkle where we measured titlebar sizes in different macOS versions IIRC.)
    
    NSEdgeInsets toastMargins = {0,0,0,0}; /// Margin between the toastWindow and the mainWindow it sits inside
    _toastAnimationOffset = 0;
    {
        if (alignment == kToastNotificationAlignment_TopMiddle) {
            toastMargins = (NSEdgeInsets) {
                .top    = 5.0,           /// 0.0 // -25.0
                .left   = 2,             /// In MMF 3 the views are so narrow that the notifications maybe should be allowed to spill out.
                .right  = 2,
                .bottom = CGFLOAT_MAX,   /// Unused
            };
            _toastAnimationOffset = 20;
        }
        else if (alignment == kToastNotificationAlignment_BottomRight) {
            toastMargins = (NSEdgeInsets) {
                .top    = CGFLOAT_MAX,
                .left   = 5,
                .right  = 5,
                .bottom = 10,
            };
            _toastAnimationOffset = -20;
        }
        else if (alignment == kToastNotificationAlignment_BottomMiddle) {
            toastMargins = (NSEdgeInsets) {
                .top    = CGFLOAT_MAX,
                .left   = 5,
                .right  = 5,
                .bottom = 10,
            };
            _toastAnimationOffset = -20;
        }
        else assert(false);
    }
    
    /// Close existing notification
    ///     This is a TEST to maybe prevent seeming raceconditions seen during our LocalizationScreenshot tests where the escapeKey monitor seemingly never got removed after screenshotting toasts on the licensesheet window.
    [self closeNotificationWithFadeOut];
    
    /// Get existing notif instance and close
    NSPanel *toastWindow = (NSPanel *)_instance.window;
    [toastWindow close];
    
    /// Set Toast frame
    {
        /// Get margins between text and edge of the toast window
        auto textMargins = (NSEdgeInsets){
            .top    = _instance.label.textContainerInset.height,
            .left   = _instance.label.textContainerInset.width,
            .bottom = _instance.label.textContainerInset.height,
            .right  = _instance.label.textContainerInset.width
        };
        
        /// Calculate the text size
        NSSize newTextSize;
        {
            
            CGFloat maxTextWidth = CGFLOAT_MAX;
            {
                /// Make sure toast doesn't spill out of parent window
                maxTextWidth = MIN(maxTextWidth,
                    mainWindow.frame.size.width
                        - toastMargins.left - toastMargins.right
                        - textMargins.left - textMargins.right
                );
                
                /// Make the `messageTitle` (first line) determine the width (So the `messageSubtitle` can't be wider than the `messageTitle`)
                maxTextWidth = MIN(
                    maxTextWidth,
                    ({
                        auto s = _instance.label.attributedString;
                        auto firstLinebreak = [s.string rangeOfString: @"\n"].location;
                        auto firstLine = [s attributedSubstringFromRange: NSMakeRange(0,
                            (firstLinebreak != NSNotFound) ?
                            firstLinebreak+1 : /// +1 to include the `\n` This is necessary to measure the `。` character in Chinese correctly (it seems to change size if followed by a linebreak) (Not sure if bug) (Observed [Nov 2025], macOS Tahoe and Sequoia)
                            s.string.length
                        )];
                        [firstLine sizeAtMaxWidth: maxTextWidth].width;
                    })
                );
                
                /// Make sure lines don't get too long
                ///     - At width 300.0, the subtitles using hint-style (`-[attributedStringByFillingOutBaseAsHint]`) have ~50 characters per line  (50-75 is considered optimal in English) [Sep 2025]
                ///     - I tried scaling by `-[informationDensityOfCurrentLanguage]` but that made the Toasts too narrow in Chinese. Also see `InformationDensity.md` [Sep 2025]
                if ((0)) /// Turning this off: Now that we have the first line determine the width, maybe this is unnecessary. So the only effect this could have is wrapping the first line, which may look weird. [Sep 2025]
                    maxTextWidth = MIN(maxTextWidth, 300.0);
                
            }
            
            /// Get the size
            newTextSize = [_instance.label.attributedString sizeAtMaxWidth: maxTextWidth];
        }
        
        /// Adjust newTextSize for lineFragmentPadding.
        ///     See https://stackoverflow.com/questions/13621084/boundingrectwithsize-for-nsattributedstring-returning-wrong-size
        ///     ... Actually this breaks short "Primary Mouse Button can't be used" notifications.
        ///     Update: Seems necessary after updating sizeAtMaxWidth to new TextKit 2 methods. ... Update2: And it works perfectly with the TextKit 1 methods as well after we fixed them.
        newTextSize.width += _instance.label.textContainer.lineFragmentPadding * 2;
        
        /// Calculate the new toast size
        NSSize newToastSize = (NSSize) {
            .width  = newTextSize.width + textMargins.left + textMargins.right,
            .height = newTextSize.height + textMargins.top + textMargins.bottom
        };
        
        /// Calculate the Toasts position
        NSPoint newToastOrigin = {};
        {
            if (alignment == kToastNotificationAlignment_TopMiddle) {
            
                newToastOrigin.x = NSMidX(mainWindow.frame) - (newToastSize.width / 2);
                newToastOrigin.y = (mainWindow.frame.origin.y + mainWindow.frame.size.height - mainWindowTitleBarHeight - toastMargins.top) - newToastSize.height;
            }
            else if (alignment == kToastNotificationAlignment_BottomRight) {
            
                newToastOrigin.x = mainWindow.frame.origin.x + mainWindow.frame.size.width - newToastSize.width - toastMargins.right;
                newToastOrigin.y = mainWindow.frame.origin.y + toastMargins.bottom;
            }
            else if (alignment == kToastNotificationAlignment_BottomMiddle) {
            
                newToastOrigin.x = NSMidX(mainWindow.frame) - (newToastSize.width / 2);
                newToastOrigin.y = mainWindow.frame.origin.y + toastMargins.bottom;
            }
            else assert(false);
        }
        
        /// Set new Toasts frame
        [toastWindow setFrame: (NSRect){ .origin = newToastOrigin, .size = newToastSize } display: YES];
    }
    
    /// Attach Toast as child window
    [parentWindow addChildWindow: toastWindow ordered: NSWindowAbove];
    
    /// Make the parentWindow key
    ///     ([Sep 2025] is this necessary? We're not bringing the window to front, so what does this even do?)
    [parentWindow makeKeyWindow];
    
    /// Fade and animate the notification window in
    {
        /// Set pre animation alpha
        toastWindow.alphaValue = 0.0;
        
        /// Set pre animation position
        NSRect targetFrame = toastWindow.frame;
        NSRect preAnimFrame = toastWindow.frame;
        preAnimFrame.origin.y += _toastAnimationOffset;
        [toastWindow setFrame: preAnimFrame display: NO];
        
        /// Fix layout bug [Sep 2025]
        ///     Observed on: Tahoe RC, with UIDesignRequiresCompatibility – Never observed this before. May be a Tahoe bug.
        ///     Description of what I observed: After triggering the forbidden capture notifications for the primary and secondary button a few times, all of a sudden the text starts wrapping incorrectly and the bottom of the text becomes cut off. This seems to be due to `_instance.label.frame`s right edge being inset by 4 pixels from its superview for some reason.
        ///     Update: Merged this from master into feature-strings-catalog (where we have made lots of changes to ToastNotificationController.m and renamed it ToastController.m) – Not sure this is necessary on feature-strings-catalog [Oct 2025]
        {
            _instance.label.frame = _instance.label.superview.bounds;
        }

        /// Animate
        [NSAnimationContext beginGrouping];
        {
            NSAnimationContext.currentContext.duration = _animationDurationFadeIn;
            toastWindow.animator.alphaValue = 1.0;
            [toastWindow.animator setFrame: targetFrame display: YES];
        }
        [NSAnimationContext endGrouping];
        
        /// Debug
        DDLogDebug(@"Toast frames: before=%@, after=%@", @(preAnimFrame), @(targetFrame));
    }
    
    /// Close if user clicks elsewhere
    _localClickMonitor = [NSEvent addLocalMonitorForEventsMatchingMask: (NSEventMaskLeftMouseDown) handler: ^NSEvent * _Nullable(NSEvent * _Nonnull event) {
        
        NSPoint loc = NSEvent.mouseLocation;
        
        /// Check where mouse is located relative to other stuff
        ///     Since we track mouseHover now, we might be able to reuse that here, instead of this hit-test stuff obsolete? Edit: I don't think so, since here, we don't *only* check if the cursor is over the toast.
        
        /// Get mouse location in the main content views' coordinate system. Need this to do a hit-test later.
        ///     Note: Should we treat clicks in the mainWindow's contentView differently when there's a sheet in front of it (then `parentWindow` is the sheet) [Sep 2025]
        NSPoint locWindow = [mainWindow convertRectFromScreen: (NSRect){ .origin = loc }].origin; /// convertPointFromScreen: only available in 10.12+
        NSPoint locContentView = [mainWindow.contentView convertPoint: locWindow fromView: nil];
        
        /// Analyze where the user clicked
        BOOL locIsOverNotification = [NSWindow windowNumberAtPoint: NSEvent.mouseLocation belowWindowWithWindowNumber: 0] == _instance.window.windowNumber; /// So notification isn't dismissed when we click on it. Not sure if necessary when we're using `locIsOverMainWindowContentView`.
        BOOL locIsOverMainWindowContentView = [mainWindow.contentView hitTest: locContentView] != nil; /// So that we can drag the window by its titlebar without dismissing the notification.
        
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
    _localEscapeKeyMonitor = [NSEvent addLocalMonitorForEventsMatchingMask: (NSEventMaskKeyDown) handler: ^NSEvent * _Nullable(NSEvent * _Nonnull event) {
        
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
    
    _toastTrackingArea = [[NSTrackingArea alloc] initWithRect: toastWindow.contentView.bounds
                                                      options: NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways
                                                        owner: self
                                                     userInfo: nil];
    
    [toastWindow.contentView addTrackingArea: _toastTrackingArea];
    
    /// Track showDuration
    ///     On retain cycles: `self` is a Class not an instance, and `_showDurationTimer` is a static var, so neither get retained when the block captures them (I think) [Sep 2025]
    [_showDurationTimer invalidate];
    _showDurationTimer = [NSTimer scheduledTimerWithTimeInterval: showDuration repeats: NO block: ^(NSTimer * _Nonnull timer) {
        
        /// Invalidate the timer
        ///     Note: After the timer fires, I thought it invalidates itself, but `timer.isValid` seems to be true in here (if I didn't test wrong)
        [_showDurationTimer invalidate];
        _showDurationTimer = nil; /// [Sep 2025] Capturing the outer timer variable so we can set it to nil
        
        /// Signal the decide method
        [self decideOverNotificationClose];
    }];
}

#pragma mark Track toastHover

static NSTrackingArea *_toastTrackingArea;
static BOOL _mouseIsOverToast = NO;

+ (void)mouseEntered:(NSEvent *)event { /// The mouse has entered the notifications content view
    _mouseIsOverToast = YES;
    [self decideOverNotificationClose];
}
+ (void)mouseExited:(NSEvent *)event { /// The mouse has left the notifications content view
    _mouseIsOverToast = NO;
    [self decideOverNotificationClose];
}

//+ (void)closeNotification:(NSTimer *)timer {
//    
//    dispatch_async(dispatch_get_main_queue(), ^{ /// Necessary under Ventura Beta for animations to work (this function used to be called by the showDuration timer)
//        [self closeNotificationWithFadeOut];
//    });
//}

#pragma mark Close the Toast

+ (void) decideOverNotificationClose {
    
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
        [NSEvent removeMonitor: _localClickMonitor];
        _localClickMonitor = nil;
    }
    if (_localEscapeKeyMonitor != nil) {
        [NSEvent removeMonitor: _localEscapeKeyMonitor];
        _localEscapeKeyMonitor = nil;
    }
    
    /// Remove the tracking area
    /// Notes:
    /// - This is necessary to deactivate the tracking area, otherwise mouseExited: and mouseEntered: keep getting called. We also have to do this before replacing `_instance.window` with a new window instance for it work I think. I think we could theoretically do this right before we replace the content of `_instance.window`, but I think it's easier to do it here.
    NSPanel *w = (id)_instance.window;
    [w.contentView removeTrackingArea: _toastTrackingArea];
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
    
    if ((1)) {
    
        NSWindow *closedWindow = notification.object;
    
        if ([_instance.window.parentWindow isEqual: closedWindow]) {
            [_showDurationTimer invalidate];
            [self closeNotificationImmediately];
        }
    }
    else {
        
        /// Code we wrote for when Toast window can become key. (See `NotificationLabel.m` for discussion) [Sep 2025]
    
        NSWindow *oldKeyWindow = notification.object;
        NSWindow *newKeyWindow = NSApp.keyWindow; /// I hope this is reliable [Sep 2025]
        
        if (
            ( /// oldKeyWindow is one of 'our' windows
                [oldKeyWindow  isEqual: _instance.window.parentWindow] ||
                [oldKeyWindow  isEqual: _instance.window]
            )
            && !( /// newKeyWindow is *not* one of 'our' windows
                [newKeyWindow isEqual: _instance.window.parentWindow] ||
                [newKeyWindow isEqual: _instance.window]
            )
        ) {
            [_showDurationTimer invalidate];
            [self closeNotificationImmediately];
        }
    }
}

#pragma mark - Other interface

+ (NSFont *)defaultFont {
    /// At the time of writing this is only used from outside ToastController not inside - so I hope this is correct! Should we use `labelFontSize` instead?
    return [NSFont systemFontOfSize:NSFont.systemFontSize];
}

@end
