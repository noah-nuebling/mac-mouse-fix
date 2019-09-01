#import <Cocoa/Cocoa.h>

@interface SmoothScroll : NSObject

typedef enum {
    kMFStandardScrollDirection      =   1,
    kMFInvertedScrollDirection      =  -1
} MFScrollDirection;

+ (void)setHorizontalScroll:(BOOL)B;
+ (void)temporarilyDisable:(BOOL)B;

+ (void)configureWithPxPerStep:(int)px
                     msPerStep:(int)ms
                      friction:(float)f
               scrollDirection:(MFScrollDirection)d;

+ (void)startOrStopDecide;

+ (BOOL)isEnabled;
+ (void)setIsEnabled: (BOOL)B;

+ (BOOL)isRunning;


+ (void)Handle_ConsecutiveScrollTickCallback:(NSTimer *)timer;
+ (void)Handle_ConsecutiveScrollSwipeCallback:(NSTimer *)timer;

@end

