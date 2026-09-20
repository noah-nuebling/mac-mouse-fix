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

@interface NSScreen (PrivateStuffInDotMFile)
    - (NSString *)_UUIDString; /// Didn't test under which macOS versions this is available [Sep 2026]
@end

@implementation NSScreen (Additions)

+ (NSScreen * _Nullable)screenUnderMousePointerWithEvent:(CGEventRef _Nullable)event {
    
    /// TODO: Simplify / optimize this: Use [NSScreen +_screenAtPoint:]
    
#if IS_HELPER
    
    CGDirectDisplayID displayID;
    [HelperUtility displayUnderMousePointer:&displayID withEvent:event];
    
    return [NSScreen screenWithDisplayID:displayID];
    
#endif
    
    assert(false);
    return nil;
}

+ (NSScreen * _Nullable)screenWithDisplayID:(CGDirectDisplayID)displayID {

    /// TODO: Simplify/optimize this: Use [NSScreen +_screenForScreenNumber:]
    
    for (NSScreen *screen in NSScreen.screens) {
        if (screen.displayID == displayID)
            return screen;
    }
    
    return nil;
}

/// Src: https://stackoverflow.com/questions/1236498/how-to-get-the-display-name-with-the-display-id-in-mac-os-x
- (CGDirectDisplayID)displayID {
    return [[[self deviceDescription] valueForKey: @"NSScreenNumber"] unsignedIntValue]; /// TODO: Simplify/optimize this. In lldb we can just do `self->_displayID`
}

- (NSString *)mf_UUIDString {

    if ((1)) {
        /// Use NSScreen's private getter `_UUIDString`.
        ///     Disassembly looks kinda looks like this is faster / cached vs the `CGSCopyDisplayUUID` approach (below) [Sep 2026]. Untested.
        return [self _UUIDString];
    } else {

        extern CGError CGSCopyDisplayUUID(CGDirectDisplayID displayID, CFUUIDRef *uuid); /// Note: There's a public `CGDisplayCreateUUIDFromDisplayID` in ColorSync.framework (weird)

        CFUUIDRef screenUUID = NULL;
        CGError err = CGSCopyDisplayUUID([self displayID], &screenUUID);

        if (!screenUUID) return nil;
        if (err) { CFRelease(screenUUID); return nil; }

        NSString *stringUUID = CFBridgingRelease(CFUUIDCreateString(kCFAllocatorDefault, screenUUID));
        CFRelease(screenUUID);

        return stringUUID;
    }
}

@end
