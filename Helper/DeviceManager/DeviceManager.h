//
// --------------------------------------------------------------------------
// DeviceManager.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

@import CoreGraphics;

@interface DeviceManager : NSObject

+ (void)load_Manual;
+ (BOOL)relevantDevicesAreAttached;
@end

