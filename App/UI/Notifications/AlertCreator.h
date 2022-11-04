//
// --------------------------------------------------------------------------
// AlertCreator.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface AlertCreator : NSObject

+ (NSAlert *)alertWithTitle:(NSString *)title markdownBody:(NSString *)bodyRaw maxWidth:(int)maxWidth style:(NSAlertStyle)style isAlwaysOnTop:(BOOL)isAlwaysOnTop;

@end

NS_ASSUME_NONNULL_END
