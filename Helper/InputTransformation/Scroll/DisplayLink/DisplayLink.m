//
// --------------------------------------------------------------------------
// DisplayLink.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "DisplayLink.h"

/// Wrapper functino for CVDisplayLink, supporting blocks
/// Didn't write this in Swift, because CVDisplayLink is clearly a C API that's been machine-translated to Swift. So it should be easier to deal with from Objc

@interface DisplayLink ()

@end

@implementation DisplayLink

// Interface

- (void)start {
    
}
- (void)stop {
    
}

- (instancetype)initWithBlock:(DisplayLinkBlock)block
{
    self = [super init];
    if (self) {
        
        // Assign block
        
        self.block = block;
        
        // Setup internal CVDisplayLink
        
//        CVDisplayLinkCreateWithActive;
//        CVDisplayLinkSetOutputCallback(_displayLink, displayLinkCallback, nil);
//        _displaysUnderMousePointer = malloc(sizeof(CGDirectDisplayID) * 3); // TODO: Why 3?
    }
    return self;
}

@end
