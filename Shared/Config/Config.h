//
// --------------------------------------------------------------------------
// Config.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@class Config;

NSObject * _Nullable config(NSString *keyPath);
void setConfig(NSString *keyPath, NSObject *value);
void removeFromConfig(NSString *keyPath);
void commitConfig(void);

NS_ASSUME_NONNULL_END
