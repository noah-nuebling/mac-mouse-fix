// Derived from lcandy2's PR #1995; licensed under the unchanged MMF License.
#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
/// Opt-in HID++ support for MX Master 3 B023 over Bluetooth only.
@interface LogitechButtonDiverter : NSObject
/// Called on MMF's config/event-tap run loop. Reads the explicit device opt-in at startup.
+ (void)load_Manual;
/// Schedule startup after MMF finishes initializing Config and starts its event loop.
+ (void)scheduleStartOnRunLoop:(CFRunLoopRef)runLoop;
/// Effective remaps include temporary Add-mode feedback mappings. Called on the config run loop.
+ (void)updateRemaps:(NSDictionary *)remaps;
/// Serialize cleanup onto the HID++ worker and wait up to four seconds.
/// Call from normal application code, never from a POSIX signal handler.
+ (void)restoreNativeBehavior;
@end
NS_ASSUME_NONNULL_END
