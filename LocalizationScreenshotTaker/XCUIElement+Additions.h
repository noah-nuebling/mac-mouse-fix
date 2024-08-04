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

///
/// Use `listMethods([XCUIElement class])` in the lldb console to easily discover private methods
///

@interface XCUIApplication (MFStuff)
- (void)_waitForQuiescence;
@end

@interface XCUIScreen (MFStuff)
- (CGDirectDisplayID)displayID;
@end

@interface XCUIElement (MFStuff)

- (id)identifier;

- (NSRect)screenshotFrame;

- (XCUIApplication *)application;
- (XCUIDevice *)device;
- (XCUIScreen *)screen;

@end
