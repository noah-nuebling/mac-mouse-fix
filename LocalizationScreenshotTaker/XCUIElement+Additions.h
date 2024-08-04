//
// --------------------------------------------------------------------------
// XCUIElement+Swizzle.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

@import XCTest;

#import "AnnotationUtility.h"

NS_ASSUME_NONNULL_BEGIN

///
/// Use `listMethods([XCUIElement class])` in the lldb console to easily discover private methods
///

///
/// Other
///

AXUIElementRef copyAXUIElementForXCElementSnapshot(id<XCUIElementSnapshot> snapshot);

///
/// Extending public interfaces
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


NS_ASSUME_NONNULL_END
