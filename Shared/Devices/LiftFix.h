//
// LiftFix.h
// Pure Logitech Lift decision and report fix. No IOHID / HID++ I/O.
//

#ifndef LiftFix_h
#define LiftFix_h

#include <stdint.h>

/// Logitech vendor, and the consumer Lift wireless product id (046d:b031).
#define kLiftVendorID 0x046D
#define kLiftProductConsumer 0xB031

/// Thumb controls. Same cids on the consumer Lift and Lift for Business.
#define kLiftCIDBack 0x0053
#define kLiftCIDForward 0x0056
#define kLiftButtonBack 4
#define kLiftButtonForward 5

/// HID++ 2.0 REPROG_CONTROLS_V4.
#define kLiftReprogFeature 0x1B04
#define kLiftHidppLongLength 20
#define kLiftSoftwareID 0x01

typedef struct {
    int isLift;
    /// 0 after the fix. Factory Lift behavior keeps this gesture on.
    int holdToHorizontalScroll;
    uint16_t backCID;
    uint16_t forwardCID;
    int backButton;
    int forwardButton;
    uint16_t featureID;
} LiftMapping;

/// Factory-style frames. A thumb press does not carry a button-down; the
/// click arrives on release, and wheel ticks while a thumb is held are the
/// horizontal-scroll gesture.
typedef enum {
    kLiftFrameThumbDown = 1,
    kLiftFrameThumbUp = 2,
    kLiftFramePointer = 3,
    kLiftFrameWheel = 4,
    kLiftFrameButton = 5,
} LiftFrameKind;

typedef struct {
    LiftFrameKind kind;
    /// Thumb cid, or a standard button number for kLiftFrameButton.
    uint16_t control;
    /// For kLiftFrameButton: 1 while that button is down, 0 on release.
    int buttonDown;
    int dx;
    int dy;
    /// Physical vertical-wheel notches. The factory gesture reports these
    /// as horizontal scroll while a thumb control is held.
    int wheelVertical;
} LiftFrame;

typedef struct {
    int button;
    int downEdge;
    int upEdge;
    int held;
    int dx;
    int dy;
    int wheelVertical;
    int wheelHorizontal;
} LiftReport;

typedef struct {
    uint8_t report[kLiftHidppLongLength];
    int length;
    uint16_t cid;
    int buttonNumber;
    int divert;
    int persistent;
    int rawWheel;
} LiftHidppCommand;

LiftMapping LiftFix_decide(const char *productName, const char *manufacturer, uint16_t vendorID, uint16_t productID);

/// One output report per input frame. Returns the number written, or -1.
int LiftFix_apply(const LiftMapping *mapping, const LiftFrame *frames, int count, LiftReport *out, int outCap);

/// Session-scoped setCidReporting for the two thumb controls.
/// Returns 2 for a Lift, 0 when the device must not be rewritten.
int LiftFix_setReportingCommands(const LiftMapping *mapping, uint8_t deviceIndex, uint8_t featureIndex, LiftHidppCommand out[2]);

/// Undo of LiftFix_setReportingCommands. Divert off, still not persistent.
int LiftFix_clearReportingCommands(const LiftMapping *mapping, uint8_t deviceIndex, uint8_t featureIndex, LiftHidppCommand out[2]);

void LiftFix_getFeatureCommand(uint8_t deviceIndex, uint8_t report[kLiftHidppLongLength]);
void LiftFix_getReportingCommand(uint8_t deviceIndex, uint8_t featureIndex, uint16_t cid, uint8_t report[kLiftHidppLongLength]);

/// feature index from a ROOT.GetFeature reply, or 0 if this reply is not it.
uint8_t LiftFix_parseFeatureIndex(const uint8_t *report, int length);

/// 1 when a getCidReporting reply shows this thumb control as an immediate
/// mouse button (diverted for the session, raw-wheel gesture off, not persisted).
int LiftFix_readbackIsImmediateButton(const LiftMapping *mapping, const uint8_t *report, int length, uint16_t cid, int *buttonOut);

/// Pressed-cid list from a divertedButtonsEvent. An empty list means every diverted control is up.
/// `inoutDown` is the previous down-state for buttons 4 and 5 (index 0 = back).
/// Writes one edge report per control that changed. Returns the number written.
int LiftFix_edgesForPressed(const LiftMapping *mapping, int inoutDown[2], const uint16_t *pressed, int pressedCount, LiftReport *out, int outCap);

/// divertedButtonsEvent (notification function 0): up to four currently pressed cids.
/// Empty slots are cid 0. Returns the number of pressed cids, or -1 if `report` is not that event.
int LiftFix_pressedFromNotification(const uint8_t *report, int length, uint8_t featureIndex, uint16_t *pressed, int cap);

#endif
