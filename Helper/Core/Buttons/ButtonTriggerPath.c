//
// ButtonTriggerPath.c
//

#include "ButtonTriggerPath.h"

#include <CoreFoundation/CoreFoundation.h>
#include <stdlib.h>

const double MFButtonTriggerHoldSeconds = 0.25;
const double MFButtonTriggerDoubleClickSeconds = 0.26;
const int MFButtonTriggerDragThreshold = 7;

static MFButtonTriggerState g_state;

const char *MFButtonTriggerPath_name(MFButtonTrigger trigger) {
    switch (trigger) {
        case MFButtonTriggerClick: return "click";
        case MFButtonTriggerDoubleClick: return "double-click";
        case MFButtonTriggerHold: return "hold";
        case MFButtonTriggerClickAndDrag: return "click-and-drag";
        case MFButtonTriggerClickAndScroll: return "click-and-scroll";
        case MFButtonTriggerNone: break;
    }
    return "none";
}

void MFButtonTriggerPath_reset(MFButtonTriggerState *state) {
    if (state == NULL) return;
    state->activeButton = 0;
    state->down = 0;
    state->clickLevel = 0;
    state->cycleStart = 0;
    state->pressStart = 0;
    state->offX = 0;
    state->offY = 0;
    state->committed = 0;
    state->selected = MFButtonTriggerNone;
}

void ButtonTriggerPath_resetGlobal(void) {
    MFButtonTriggerPath_reset(&g_state);
}

static int travel_is_drag(int offX, int offY) {
    int ax = offX < 0 ? -offX : offX;
    int ay = offY < 0 ? -offY : offY;
    int travel = ax > ay ? ax : ay;
    return travel > MFButtonTriggerDragThreshold;
}

static int blocks_another_click(MFButtonTrigger selected) {
    return selected == MFButtonTriggerHold
        || selected == MFButtonTriggerClickAndDrag
        || selected == MFButtonTriggerClickAndScroll;
}

MFButtonTrigger MFButtonTriggerPath_feed(MFButtonTriggerState *state, int button, int downNotUp, int dx, int dy, int wheel, double timeSeconds) {
    if (state == NULL) return MFButtonTriggerNone;

    if (downNotUp) {
        int wasDown = state->down && state->activeButton == button;
        if (!wasDown) {
            int second = !state->down
                && state->activeButton == button
                && state->clickLevel >= 1
                && !blocks_another_click(state->selected)
                && (timeSeconds - state->cycleStart) < MFButtonTriggerDoubleClickSeconds;
            if (second) {
                state->clickLevel += 1;
            } else {
                state->clickLevel = 1;
                state->cycleStart = timeSeconds;
            }
            state->activeButton = button;
            state->down = 1;
            state->pressStart = timeSeconds;
            state->offX = 0;
            state->offY = 0;
            state->committed = 0;
            state->selected = MFButtonTriggerNone;
        }
        state->offX += dx;
        state->offY += dy;
        if (!state->committed) {
            if (wheel != 0) {
                state->selected = MFButtonTriggerClickAndScroll;
                state->committed = 1;
            } else if (travel_is_drag(state->offX, state->offY)) {
                state->selected = MFButtonTriggerClickAndDrag;
                state->committed = 1;
            } else if ((timeSeconds - state->pressStart) >= MFButtonTriggerHoldSeconds) {
                state->selected = MFButtonTriggerHold;
                state->committed = 1;
            }
        }
        return state->selected;
    }

    if (state->down && state->activeButton == button) {
        if (!state->committed) {
            state->selected = state->clickLevel >= 2 ? MFButtonTriggerDoubleClick : MFButtonTriggerClick;
        }
        state->down = 0;
    }
    return state->selected;
}

void ButtonTriggerPath_noteButton(int button, int downNotUp) {
    MFButtonTriggerPath_feed(&g_state, button, downNotUp, 0, 0, 0, CFAbsoluteTimeGetCurrent());
}

void ButtonTriggerPath_notePointer(int dx, int dy) {
    if (!g_state.down) return;
    MFButtonTriggerPath_feed(&g_state, g_state.activeButton, 1, dx, dy, 0, CFAbsoluteTimeGetCurrent());
}

void ButtonTriggerPath_noteWheel(int wheel) {
    if (!g_state.down || wheel == 0) return;
    MFButtonTriggerPath_feed(&g_state, g_state.activeButton, 1, 0, 0, wheel, CFAbsoluteTimeGetCurrent());
}

void ButtonTriggerPath_noteTime(void) {
    if (!g_state.down) return;
    MFButtonTriggerPath_feed(&g_state, g_state.activeButton, 1, 0, 0, 0, CFAbsoluteTimeGetCurrent());
}
