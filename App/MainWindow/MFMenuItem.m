//
// --------------------------------------------------------------------------
// MFMenuItem.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "MFMenuItem.h"

@implementation MFMenuItem
- (instancetype)init
{
    self = [super init];
    if (self) {
        self.isHideable = NO;
    }
    return self;
}
@end
