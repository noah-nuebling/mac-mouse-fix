//
// --------------------------------------------------------------------------
// XCUIElement+Swizzle.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <XCTest/XCUIElement.h>

@interface XCUIElement (Swizzle)

@end

@implementation XCUIElement (Swizzle)

+ (void)load {
    
        
    swizzleMethodOnClassAndSubclasses([XCUIElement class], @{ @"framework": @"XCTest" }, @selector(screenshotFrame), MakeInterceptorFactory(NSRect, (), {
        
        OGImpl()
    }));
}

@end
