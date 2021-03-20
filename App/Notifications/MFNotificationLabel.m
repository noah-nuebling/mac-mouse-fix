//
// --------------------------------------------------------------------------
// MFNotificationLabel.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "MFNotificationLabel.h"

@implementation MFNotificationLabel

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self setAllowsEditingTextAttributes: YES];
        [self setSelectable: YES];
    }
    return self;
}

- (void)mouseDown:(NSEvent *)theEvent {
    NSLog(@"MOUSE DOWN ON NOTIF LABEL");
    [self sendAction:[self action] to:[self target]];
    [super mouseDown:theEvent];
}

@end
