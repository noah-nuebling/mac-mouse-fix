//
// --------------------------------------------------------------------------
// HelperStateObjC.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "HelperStateObjC.h"
#import "AppKit/AppKit.h"

@implementation HelperStateObjC

+ (id _Nullable)__SWIFT_UNBRIDGED_serializeApp:(id _Nonnull)app {
    return [self serializeApp:app];
}

+ (NSString * _Nullable)serializeApp:(NSRunningApplication * _Nonnull)app MF_SWIFT_HIDDEN {
    
    /// Note: Implementing this in ObjC because I think this would've been slow to implement in swift due to forced bridging of NSString
    
    NSString *result;
    
    if (app.bundleIdentifier) {
        
        result = app.bundleIdentifier;
        
    } else if (app.bundleURL) {
        
        /// Notes:
        /// - bundleURL points to the executableURL if the executable isn't embedded in a bundle
        /// - Maybe we should use `bookmarkDataWithOptions:` to make the reference work even after the user moves the executable
        
        result = app.bundleURL.absoluteString;
        
    } else {
        assert(false); /// Not sure when / if this ever happens
        result = nil;
    }
    
    return result;
}

@end
