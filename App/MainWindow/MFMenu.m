//
// --------------------------------------------------------------------------
// MFMenu.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "MFMenu.h"

@implementation MFMenu

- (instancetype)init
{
    self = [super init];
    if (self) {
        [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskFlagsChanged handler:^NSEvent * _Nullable(NSEvent * _Nonnull event) {
            NSLog(@"FLAGS IN THAT MENU CHANGEDDDD");
            return event;
        }];
    }
    return self;
}

- (void)flagsChanged:(NSEvent *)event {
    NSLog(@"FLAGS IN THAT MENU CHANGED");
}

@end
