//
// --------------------------------------------------------------------------
// NSScreen+Additions.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "NSScreen+Additions.h"

@implementation NSScreen (Additions)

/// Src: https://stackoverflow.com/questions/1236498/how-to-get-the-display-name-with-the-display-id-in-mac-os-x
- (CGDirectDisplayID)displayID {
    return [[[self deviceDescription] valueForKey:@"NSScreenNumber"] unsignedIntValue];
}

@end
