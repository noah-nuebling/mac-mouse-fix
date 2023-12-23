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

+ (NSScreen * _Nullable)screenUnderMousePointerWithEvent:(CGEventRef _Nullable)event {
    
#if IS_HELPER
    
    CGDirectDisplayID displayID;
    [HelperUtility displayUnderMousePointer:&displayID withEvent:event];
    
    return [NSScreen screenWithDisplayID:displayID];
    
#endif
    
    assert(false);
    return nil;
}

+ (NSScreen * _Nullable)screenWithDisplayID:(CGDirectDisplayID)displayID {
    
    for (NSScreen *screen in NSScreen.screens) {
        if (screen.displayID == displayID)
            return screen;
    }
    
    return nil;
}

/// Src: https://stackoverflow.com/questions/1236498/how-to-get-the-display-name-with-the-display-id-in-mac-os-x
- (CGDirectDisplayID)displayID {
    return [[[self deviceDescription] valueForKey:@"NSScreenNumber"] unsignedIntValue];
}

@end
