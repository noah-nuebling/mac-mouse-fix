//
// --------------------------------------------------------------------------
// NSTimer+Additions.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2026
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

@interface NSTimer (Additions)
    + (instancetype) mf_scheduledTimerWithTimeInterval: (NSTimeInterval)timeInterval mode: (NSRunLoopMode)mode block: (void (^)(NSTimer *timer))block;
@end
