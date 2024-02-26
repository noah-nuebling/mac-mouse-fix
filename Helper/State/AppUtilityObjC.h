//
// --------------------------------------------------------------------------
// Apps.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface AppUtilityObjC : NSObject

//+ (NSRunningApplication * _Nullable)getRunningAppWithPIDObjC:(pid_t)pid;
//pid_t getPIDUnderMousePointerObjC(CGPoint pointerLocCG);
+ (void)openMainApp;

@end

NS_ASSUME_NONNULL_END
