//
// --------------------------------------------------------------------------
// ToastNotificationLabel.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "ToastNotificationLabel.h"
#import "WannabePrefixHeader.h"

@implementation ToastNotificationLabel

- (instancetype)init
{
    self = [super init];
    if (self) {
        DDLogInfo(@"INIT LABEL");
//        [self setSelectable: YES]; // Need this to make links work // This doesn't work, need to set this in IB
//        self.delegate = self; // This doesn't work, need to set this in IB
    }
    return self;
}

// Override text selection method to disallow selection
- (void)setSelectedRanges:(NSArray<NSValue *> *)ranges
                 affinity:(NSSelectionAffinity)affinity
           stillSelecting:(BOOL)stillSelectingFlag {
}

@end
