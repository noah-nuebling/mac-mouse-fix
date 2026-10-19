#pragma once
#import <Cocoa/Cocoa.h>
#define kMFModifiedDragTypeThreeFingerSwipe @"threeFingerSwipe"
#define kMFModifiedDragTypeThreeFingerSwipeInstant @"threeFingerSwipeInstant"
typedef enum { kMFAxisHorizontal, kMFAxisVertical } MFAxis;
typedef enum { kMFDockSwipeTypeHorizontal, kMFDockSwipeTypeVertical } MFDockSwipeType;
typedef enum { kIOHIDEventPhaseBegan = 1, kIOHIDEventPhaseChanged = 2,
               kIOHIDEventPhaseEnded = 4, kIOHIDEventPhaseCancelled = 8 } IOHIDEventPhaseBits;
typedef struct {
    NSString *type;
    MFAxis usageAxis;
    BOOL naturalDirection;
    CGPoint originOffset, usageOrigin;
    BOOL firstCallback;
} ModifiedDragState;
@interface TestScreen : NSObject
+ (TestScreen *)mainScreen;
- (NSRect)frame;
- (NSString *)mf_UUIDString;
@end
#define NSScreen TestScreen
@interface GeneralConfig : NSObject
+ (BOOL)freezePointerDuringModifiedDrag;
@end
@interface PointerFreeze : NSObject
+ (void)freezePointerAtPosition:(CGPoint)position;
+ (void)unfreeze;
@end
@interface TouchSimulator : NSObject
+ (void)postDockSwipeEventWithDelta:(double)delta type:(MFDockSwipeType)type
                             phase:(IOHIDEventPhaseBits)phase invertedFromDevice:(BOOL)inverted;
@end
int CGSMainConnectionID(void);
CFArrayRef CGSCopyManagedDisplaySpaces(int connection);
#define DDLogDebug(...) ((void)0)
