//
// --------------------------------------------------------------------------
// EventTapQueue.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
@import Foundation;

NS_ASSUME_NONNULL_BEGIN

@interface GlobalEventTapThread : NSObject

+ (CFRunLoopRef)runLoop;

@end

NS_ASSUME_NONNULL_END
