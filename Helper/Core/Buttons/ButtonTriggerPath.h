//
// ButtonTriggerPath.h
// Click, double-click, hold, click-and-drag, and click-and-scroll.
// The thresholds are the ones ClickCycle and ModifiedDrag already use.
//

#ifndef ButtonTriggerPath_h
#define ButtonTriggerPath_h

#include <stdint.h>

/// Hold fires once the press has lasted this long with no drag and no wheel.
extern const double MFButtonTriggerHoldSeconds;
/// A second press that starts within this long of the first press is a double-click.
/// ClickCycle arms that deadline on mouse-down.
extern const double MFButtonTriggerDoubleClickSeconds;
/// ModifiedDrag enters use when pointer travel from the press exceeds this.
extern const int MFButtonTriggerDragThreshold;

typedef enum {
    MFButtonTriggerNone = 0,
    MFButtonTriggerClick = 1,
    MFButtonTriggerDoubleClick = 2,
    MFButtonTriggerHold = 3,
    MFButtonTriggerClickAndDrag = 4,
    MFButtonTriggerClickAndScroll = 5,
} MFButtonTrigger;

typedef struct {
    int activeButton;
    int down;
    int clickLevel;
    double cycleStart;
    double pressStart;
    int offX;
    int offY;
    int committed;
    MFButtonTrigger selected;
} MFButtonTriggerState;

void MFButtonTriggerPath_reset(MFButtonTriggerState *state);

/// `downNotUp` is the button state after this event. Pointer and wheel samples
/// keep it 1. Time is seconds on the same clock as earlier events for `state`.
MFButtonTrigger MFButtonTriggerPath_feed(MFButtonTriggerState *state, int button, int downNotUp, int dx, int dy, int wheel, double timeSeconds);

const char *MFButtonTriggerPath_name(MFButtonTrigger trigger);

/// Live-path wrappers. They share one state, clocked with CFAbsoluteTimeGetCurrent.
void ButtonTriggerPath_resetGlobal(void);
void ButtonTriggerPath_noteButton(int button, int downNotUp);
void ButtonTriggerPath_notePointer(int dx, int dy);
void ButtonTriggerPath_noteWheel(int wheel);
void ButtonTriggerPath_noteTime(void);

#endif
