//
// --------------------------------------------------------------------------
// MFNotification.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "MFNotification.h"

@implementation MFNotification

- (BOOL)canBecomeKeyWindow {
    return NO;
}
@end
