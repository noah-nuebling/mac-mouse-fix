//
// --------------------------------------------------------------------------
// ScrollConfigInterface.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ScrollConfig : NSObject
/**
 Function:
    This class expose values from the config dict that are relevant for scrolling via readonly class properties.
        (So maybe it should be called ScrollConfigInterface, but that's harder to write)
 Motivation:
    - We used to have a copy of the relevant config values in the ScrollControl / SmoothScroll. They were filled by MainConfigInterface. This was bad because:
        That made it cumbersome to add new scroll values to the config and we duplicated state which is generally bad because you have to manually keep it in sync and things can go wrong.
    - We learned our lesson (unfortunately too late) while writing the advanced remapping engine that referencing the internal structure of a complex dictionary in tons of different places is bad because it makes things really hard to change.
        So what we're doing here is exposing the values from the dict as class properties, (which are super easy to refactor), and only referencing the internal structure of the dictionary here.
        Ideally we'd only want to reference the internal structure of the dict in classes whose name contains ConfigInterface, so we hide the internal structure of the config file from everything else. But that's a long way off.
        I also feel like maybe this complete encapsulation might be overkill in this case because the structure of the nested dicts we're dealing with is not that complicated like it was for the advanced remapping engine. But I'll just implement it like this and try to learn from it.
 */

typedef enum {
    kMFStandardScrollDirection      =   1,
    kMFInvertedScrollDirection      =  -1
} MFScrollDirection;

// General

+ (BOOL)smoothEnabled;
+ (MFScrollDirection)scrollDirection;
+ (BOOL)disableAll;

// Scroll ticks/wipes, and fast scroll

+ (NSUInteger)scrollSwipeThreshold_inTicks;
+ (NSUInteger)fastScrollThreshold_inSwipes;
+ (NSTimeInterval)consecutiveScrollTickMaxInterval;
+ (NSTimeInterval)consecutiveScrollSwipeMaxInterval;
+ (double)fastScrollExponentialBase;
+ (double)fastScrollFactor;

@end

NS_ASSUME_NONNULL_END
