//
// --------------------------------------------------------------------------
// MFSegmentedControl.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "MFSegmentedControl.h"
#import <Carbon/Carbon.h>
#import "Logging.h"

@interface MFSegmentedControl ()
@property (nonatomic) IBInspectable NSNumber *keyEquivKC;
@end

/*
 KeyCodes:
 - Delete -> kVK_Delete -> 0x33 -> 51
*/

@implementation MFSegmentedControl

- (BOOL)performKeyEquivalent:(NSEvent *)key {
    
    DDLogInfo(@"%d %@", key.keyCode, _keyEquivKC);
    
    if (key.keyCode == _keyEquivKC.intValue) {
        [self selectSegmentWithTag:-1];
        [self performClick:self];
        return YES;
    }
    return NO;
}

@end
