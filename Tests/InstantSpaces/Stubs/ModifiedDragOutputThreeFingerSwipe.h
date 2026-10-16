// External MMF dependencies for testing the real output plugin in isolation.
#import <Cocoa/Cocoa.h>
#import "TestDependencies.h"
@interface ModifiedDragOutputThreeFingerSwipe : NSObject
+ (void)initializeWithDragState:(ModifiedDragState *)state;
+ (void)handleBecameInUse;
+ (void)handleMouseInputWhileInUseWithDeltaX:(double)x deltaY:(double)y;
+ (void)handleDeactivationWhileInUseWithCancel:(BOOL)cancel;
@end
