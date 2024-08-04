//
// --------------------------------------------------------------------------
// Toast.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "Toast.h"
#import "AppDelegate.h"

@implementation Toast {
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
    
//    if (_localClickMonitor == nil) {
//
//        _localClickMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskLeftMouseDown handler:^NSEvent * _Nullable(NSEvent * _Nonnull event) {
//
//            // Dismiss notification on click
//            NSView *viewUnderMousePointer = [AppDelegate.mainWindow.contentView hitTest:event.locationInWindow];
//            if ([viewUnderMousePointer isEqual:self.contentView]) {
//                [ToastController closeNotificationWithFadeOut];
//            }
//
//            return event;
//        }];
//    }
}

- (BOOL)canBecomeKeyWindow {
    return NO;
}

- (void)mouseDown:(NSEvent *)event { /// Is never never called
    [ToastController closeNotificationWithFadeOut];
}

@end
