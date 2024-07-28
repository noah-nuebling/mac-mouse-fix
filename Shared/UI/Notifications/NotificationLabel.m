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
