// Licensed under the MMF License. See License.
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

/// Temporary, visible pointer workaround. All methods must run on the main thread.
/// Does not hide, disconnect, suppress, or synthesize mouse/keyboard input.
@interface MissionControlPreviews : NSObject
- (void)toggleWithAction:(void (^)(void))action;
@end

/// Internal seams for deterministic tests; coordinates use Quartz global display points.
@interface MissionControlPreviews (Testing)
- (instancetype)initWithPosition:(CGPoint (^)(void))position
                         bounds:(CGRect (^)(CGPoint))bounds
                           warp:(CGError (^)(CGPoint))warp
                       schedule:(void (^)(NSTimeInterval, void (^)(void)))schedule;
@end
