//
// --------------------------------------------------------------------------
// XCUIElement+Swizzle.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <XCTest/XCUIElement.h>
#import "AnnotationUtility.h"

@interface XCUIElement (Swizzle)

@end

@implementation XCUIElement (Swizzle)

+ (void)load {
    
    swizzleMethodOnClassAndSubclasses([XCUIElement class], @{ @"framework": @"XCTest" }, @selector(screenshotFrame), MakeInterceptorFactory(NSRect, (), {
        NSRect r = OGImpl();
        r = NSMakeRect(r.origin.x - 10, r.origin.y - 10, r.size.width + 20, r.size.height + 20);
        return r;
    }));
}

@end
