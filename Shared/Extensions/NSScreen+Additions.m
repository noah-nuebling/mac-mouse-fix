//
// --------------------------------------------------------------------------
// NSScreen+Additions.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "NSScreen+Additions.h"
#import "SharedUtility.h"

#if IS_HELPER
#import "HelperUtility.h"
#endif

@implementation NSScreen (Additions)

+ (NSScreen * _Nullable)screenWithDisplayID:(CGDirectDisplayID)displayID {
    
    for (NSScreen *screen in NSScreen.screens) {
        if (screen.displayID == displayID)
            return screen;
    }
    
    return nil;
}

- (CGDirectDisplayID)displayID {
    /// Src: https://stackoverflow.com/questions/1236498/how-to-get-the-display-name-with-the-display-id-in-mac-os-x
    return [[[self deviceDescription] valueForKey:@"NSScreenNumber"] unsignedIntValue];
}

@end
