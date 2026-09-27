//
// --------------------------------------------------------------------------
// EventTapQueue.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
@import Foundation;

NS_ASSUME_NONNULL_BEGIN

@interface GlobalEventTapThread : NSObject

    + (void) load_Manual;
    + (void) start;
    + (CFRunLoopRef)runLoop CF_RETURNS_NOT_RETAINED;

@end

NS_ASSUME_NONNULL_END
