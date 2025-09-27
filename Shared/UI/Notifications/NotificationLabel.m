//
// --------------------------------------------------------------------------
// NotificationLabel.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "NotificationLabel.h"
#import "Logging.h"

@implementation NotificationLabel

/// Discussion:
/// - At the time of writing this is used inside TrialNotifications and ToastNotifications.
/// - I'm not really sure if it's beneficial to have one class to determine the behaviour of labels in both of those types of notifications.

- (instancetype)init
{
    self = [super init];
    if (self) {
        DDLogInfo(@"INIT LABEL");
        if ((0)) [self setSelectable: YES]; /// Need this to make links work /// This doesn't work, need to set this in IB
        if ((0)) self.delegate = self; /// This doesn't work, need to set this in IB
    }
    return self;
}

- (void)setSelectedRanges:(NSArray<NSValue *> *)ranges
                 affinity:(NSSelectionAffinity)affinity
           stillSelecting:(BOOL)stillSelectingFlag {
    
    /**
        Disallow selection
        Discussion: [Sep 2025]
            - We would like text selection for copy-pasting but that requires allowing Toasts to become key.
            - If we allow the Toast to become key, there are the following issues which we'd have the 'goal' to solve:
                1. When you click on the Toast, the main Window looses key and appears greyed out, while the Toast window's appears more prominent (Assessment: This is not too bad.)
                2. When you try to click on the 'learn more' link in the Toast, it activates the Toast (makes it key) instead of opening the link. (Assessment: I really don't like this)
            - Possible 'goal configurations' we could go for:
                1. Solve issue 1. and 2. – What we ideally want is for the Toast and mainWindow to both have 'stable' appearance the whole time, while actually routing the key events (e.g. Command-C) to whatever UI element the user has selected  (e.g. the  text on the Toast.)
                    - Solution ideas:
                        - NSPopover and NSDrawer have the desired behavior and are implemented using separate windows from what I could gather. -> We could reverse engineer them.
                        - We could draw the Toast as a view inside our window, instead of using a separate window.
                            Con: There may be good reasons why NSPopover and NSDrawer are implemented as windows (IIRC)
                                E.g. when we have a sheet attached to the mainWindow, the Toast would be drawn in the background.
                        - We could avoid making the Toast window a 'real' key window but still hack together the necessary functionality for copy pasting Toast text:
                            - Tasks:
                                - Override the text-selection color
                                - Override the event-routing for Command-C
                            - See 'Resources' below for leads on how to solve these. tasks. [Sep 2025]
                2. Only solve issue 2. – We could give up on the 'stable appearance' goal, and just let the Toast become a normal key window, and just solve the problem of clicking on the Toast activating it instead of opening the link.
                    - Can't find anything on the internet. Ideas:
                        - Override NSApplication event routing to not block 'activation clicks' from being propagated to the views. (Probably requires some reverse engineering)
                        - Override NSTextView event handling (In case it already receives the click, but just doesn't react to it because it thinks 'oh I'm not active, yet' or something.)
                            - I did a quick attempt overriding `-[NSLayoutManager layoutManagerOwnsFirstResponderInWindow:]` to make the NSTextView always think it's focused. But didn't make a difference (Also didn't test thoroughly)
            Resources:
                - SO: Override text-selection color on NSTextView: https://stackoverflow.com/a/34578400/10601702
                    - Make the NSTextView think it's first-responder: https://stackoverflow.com/a/58951020/10601702
                - SO: childWindow with text input without making mainWindow inactive: https://stackoverflow.com/questions/2940091/cocoa-objective-c-child-window-with-text-input-without-main-window-becoming-in
            
            Sidenotes:
                If we allow toasts to become key, we also need to adjust `+[ToastController windowResignKey:]` (But that shouldn't be too hard)
     
            Conclusion: [Sep 2025]
                I'll just keep text selection disabled for now. This will take too much time.
    */
    
    if ((0)) /// Block text selection
        [super setSelectedRanges: ranges affinity: affinity stillSelecting: stillSelectingFlag];
}

@end
