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

@interface XCUIScreen (Swizzle)

- (CGDirectDisplayID)displayID;

@end

@interface XCUIElement (Swizzle)

- (NSRect)screenshotFrame;

- (XCUIApplication *)application;
- (XCUIDevice *)device;
- (XCUIScreen *)screen;

@end
