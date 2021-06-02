//
// --------------------------------------------------------------------------
// ToastNotification.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "ToastNotification.h"
#import "AppDelegate.h"

@implementation ToastNotification {
    id _localEventMonitor;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        // Not called (?)
    }
    return self;
}

- (void)awakeFromNib {
    
    // Trying to dismiss the notification window on click, but this doesn't work
    
//    if (_localEventMonitor == nil) {
//
//        _localEventMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskLeftMouseDown handler:^NSEvent * _Nullable(NSEvent * _Nonnull event) {
//
//            // Dismiss notification on click
//            NSView *viewUnderMousePointer = [AppDelegate.mainWindow.contentView hitTest:event.locationInWindow];
//            if ([viewUnderMousePointer isEqual:self.contentView]) {
//                [ToastNotificationController closeNotificationWithFadeOut];
//            }
//
//            return event;
//        }];
//    }
}

- (BOOL)canBecomeKeyWindow {
    return NO;
}

- (void)mouseDown:(NSEvent *)event { // Is never never called
    [ToastNotificationController closeNotificationWithFadeOut];
}

@end
