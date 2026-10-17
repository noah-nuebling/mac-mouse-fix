//
// LiftDevice.h
// Apply LiftFix to a real IOHID device. Session-scoped HID++ only.
//

#ifndef LiftDevice_h
#define LiftDevice_h

#import <Foundation/Foundation.h>
#import <IOKit/hid/IOHIDManager.h>
#import "LiftFix.h"

NS_ASSUME_NONNULL_BEGIN

typedef struct {
    int matched;
    int opened;
    int featureIndex;
    int backImmediate;
    int forwardImmediate;
    int diverted;
    char name[256];
    char detail[512];
} LiftDeviceResult;

/// `deviceObject` is the helper's Device, or nil. `downNotUp` is 1 for the whole press.
typedef void (*LiftEdgeHandler)(id _Nullable deviceObject, int button, int downNotUp);

void LiftDeviceSetEdgeHandler(LiftEdgeHandler _Nullable handler);

/// 1 when both thumb controls read back as immediate buttons 4 and 5.
int LiftDeviceApply(IOHIDDeviceRef device, id _Nullable deviceObject);

/// Send the divert-off commands and drop the session. Safe to call with no Lift.
void LiftDeviceRestoreAll(void);

/// Restore on the run loop Apply used. Best effort from another thread.
void LiftDeviceRequestRestore(void);

void LiftDeviceDetach(IOHIDDeviceRef device);

/// Catch SIGTERM on the current run loop and restore before quitting.
/// Only the long-running helper should call this, and only after a divert sticks.
void LiftDeviceEnableQuitRestore(void);

/// 1 when Apply has stored a result for `device`.
int LiftDeviceCopyResult(IOHIDDeviceRef device, LiftDeviceResult *out);

NS_ASSUME_NONNULL_END

#endif
