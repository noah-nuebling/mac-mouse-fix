//
// --------------------------------------------------------------------------
// XCUIElement+Swizzle.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "XCUIElement+Additions.h"

@implementation XCUIElement (MFStuff)

+ (void)load {
    
    ///
    /// Extend screenshots beyond Elements bounds
    ///
    
    /// Notes:
    /// - We want to do this so there's context for localizers about where an NSMenu appears inside the app (If you just screenshot the entire parent window, the NSMenu will be cut off if it extendes beyond the window bounds, but if you screenshot the NSMenu, there is no context.)
    /// - If the `screenshotFrame` we output includes off-screen areas, those will automatically be cut off, and it won't lead to problems.
    
    swizzleMethodOnClassAndSubclasses([XCUIElement class], @{ @"framework": @"XCTest" }, @selector(screenshotFrame), MakeInterceptorFactory(NSRect, (), {
        
        /// Call original implementation
        NSRect r = OGImpl();
        
        /// Get self
        XCUIElement *self = m_self;
        
        /// Determine screenshot extension
        double extension = 0;
        if (self.elementType == XCUIElementTypeMenu) {
            extension = 100;
            
        } else if (self.elementType == XCUIElementTypeSheet) {
            extension = 100;
        } else {
            extension = 0;
        }
        
        /// Extend frame
        if (extension > 0) {
            r = NSMakeRect(r.origin.x - extension, r.origin.y - extension, r.size.width + 2*extension, r.size.height + 2*extension);
        }        
        /// Return
        return r;
    }));
}

@end
