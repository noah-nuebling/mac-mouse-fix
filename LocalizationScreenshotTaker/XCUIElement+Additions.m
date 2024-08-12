//
// --------------------------------------------------------------------------
// XCUIElement+Swizzle.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "XCUIElement+Additions.h"
#import "objc/runtime.h"
@import XCTest;

/// Wrappers for Swift
///     We can't import `XCElementSnapshot` into Swift - due to linker errors - and so we have to expose these wrappers using`id<XCUIElementSnapshot>` to Swift instead.)

XCUIHitPointResult *hitPointForSnapshot_ForSwift(id<XCUIElementSnapshot>snapshot, id *idk) {
    XCUIHitPointResult *hitPoint = [(XCElementSnapshot *)snapshot hitPoint:idk];
    return hitPoint;
}
AXUIElementRef getAXUIElementForXCElementSnapshot(id<XCUIElementSnapshot> snapshot) {
    
    /// Retrieve the AXUIElement for a snapshot
    ///     Should we retain the AXUIElement?
    
    XCAccessibilityElement *xcAccessibilityElement = [(XCElementSnapshot *)snapshot accessibilityElement];
    AXUIElementRef axuiElement = (__bridge AXUIElementRef)[xcAccessibilityElement AXUIElement];
    
    return axuiElement;
}


@implementation XCUIElement (MFStuff)

+ (void)load {
    
    ///
    /// Extend screenshots beyond Elements bounds
    ///
    
    /// Notes:
    /// - We want to do this so there's context for localizers about where an NSMenu appears inside the app (If you just screenshot the entire parent window, the NSMenu will be cut off if it extendes beyond the window bounds, but if you screenshot the NSMenu, there is no context.)
    /// - If the `screenshotFrame` we output includes off-screen areas, those will automatically be excluded from the screenshots that the XCUI framework takes.
    
    swizzleMethodOnClassAndSubclasses([XCUIElement class], @{ @"framework": @"XCTest" }, @selector(screenshotFrame), MakeInterceptorFactory(NSRect, (), {
        
        /// Call original implementation
        NSRect r = OGImpl();
        
        /// Get self
        XCUIElement *self = m_self;
        
        if (self.elementType == XCUIElementTypeMenuBar) {
            
            /// Get the range of the menuBar where menuItems appear
            ///     This doesn't include the statusItems on the right (Wifi controls etc) which we want to exclude from the screenshot.
            NSArray *menuBarItems = [[self childrenMatchingType:XCUIElementTypeMenuBarItem] allElementsBoundByAccessibilityElement];
            XCUIElement *lastItem = menuBarItems.lastObject;
            XCUIElement *firstItem = menuBarItems.firstObject;
            NSRect firstItemFrame = [firstItem frame];
            NSRect lastItemFrame = [lastItem frame];
            double minItemX = firstItemFrame.origin.x;
            double maxItemX = lastItemFrame.origin.x + lastItemFrame.size.width;
            
            /// Update the screenshot frame
            r.size.width = maxItemX - minItemX;
            r.origin.x = minItemX;
            
            /// Return
            return r;
            
        } else {
        
            /// Determine screenshot extension
            double extension = 0;
            if (self.elementType == XCUIElementTypeMenu) {
                extension = 100;
            } else if (self.elementType == XCUIElementTypeSheet) {
                extension = 100;
            } else if (self.elementType == XCUIElementTypeDialog) { /// Our toastNotifications appear as dialog elements. Not sure how the classification works
                extension = 100;
            } else if (self.elementType == XCUIElementTypePopover) {
                extension = 90;                                    /// Popovers already have an extended screenshot frame naturally
            } else {
                extension = 0;
            }
            
            /// Extend frame
            if (extension > 0) {
                r = NSMakeRect(r.origin.x - extension, r.origin.y - extension, r.size.width + 2*extension, r.size.height + 2*extension);
            }
            /// Return
            return r;
        }
    }));
}

@end
