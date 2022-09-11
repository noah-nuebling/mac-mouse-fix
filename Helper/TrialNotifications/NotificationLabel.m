//
// --------------------------------------------------------------------------
// NotificationLabel.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

#import "NotificationLabel.h"
#import "WannabePrefixHeader.h"

@implementation NotificationLabel

- (instancetype)init
{
    self = [super init];
    if (self) {
        DDLogInfo(@"INIT LABEL");
//        [self setSelectable: YES]; /// Need this to make links work /// This doesn't work, need to set this in IB
//        self.delegate = self; /// This doesn't work, need to set this in IB
    }
    return self;
}

- (void)setSelectedRanges:(NSArray<NSValue *> *)ranges
                 affinity:(NSSelectionAffinity)affinity
           stillSelecting:(BOOL)stillSelectingFlag {
    
    /// Override text selection method to disallow selection
    ///     Selection is fine in itself but it looks weird since the window can't become key so it's always grey
}

@end
