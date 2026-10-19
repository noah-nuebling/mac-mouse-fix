//
// Drives the shipped button-trigger path from its reset state.
// Buttons 3, 4, and 5 share one classifier.
//

#include "ButtonTriggerPath.h"

#include <stdio.h>

static int g_failures = 0;

static void check(int ok, const char *what) {
    printf("%s %s\n", ok ? "PASS" : "FAIL", what);
    if (!ok) g_failures++;
}

typedef struct {
    int down;
    int dx;
    int dy;
    int wheel;
    double time;
} Sample;

static MFButtonTrigger play(int button, const Sample *samples, int count) {
    MFButtonTriggerState state;
    MFButtonTriggerPath_reset(&state);
    MFButtonTrigger selected = MFButtonTriggerNone;
    for (int i = 0; i < count; i++) {
        selected = MFButtonTriggerPath_feed(&state, button, samples[i].down, samples[i].dx, samples[i].dy, samples[i].wheel, samples[i].time);
    }
    return selected;
}

static void expect_play(int button, const char *name, MFButtonTrigger want, const Sample *samples, int count) {
    MFButtonTrigger got = play(button, samples, count);
    char what[160];
    snprintf(what, sizeof what, "button %d %s => %s", button, name, MFButtonTriggerPath_name(got));
    printf("observe %s\n", what);
    check(got == want, what);
}

static void run_button(int button) {
    expect_play(button, "click", MFButtonTriggerClick, (Sample[]){
        {1, 0, 0, 0, 0.00},
        {0, 0, 0, 0, 0.05},
    }, 2);
    expect_play(button, "double-click", MFButtonTriggerDoubleClick, (Sample[]){
        {1, 0, 0, 0, 0.00},
        {0, 0, 0, 0, 0.05},
        {1, 0, 0, 0, 0.12},
        {0, 0, 0, 0, 0.18},
    }, 4);
    expect_play(button, "second press at 0.26 is a new click", MFButtonTriggerClick, (Sample[]){
        {1, 0, 0, 0, 0.00},
        {0, 0, 0, 0, 0.05},
        {1, 0, 0, 0, 0.26},
        {0, 0, 0, 0, 0.30},
    }, 4);
    expect_play(button, "hold", MFButtonTriggerHold, (Sample[]){
        {1, 0, 0, 0, 0.00},
        {1, 0, 0, 0, 0.25},
        {0, 0, 0, 0, 0.40},
    }, 3);
    expect_play(button, "release before hold is a click", MFButtonTriggerClick, (Sample[]){
        {1, 0, 0, 0, 0.00},
        {1, 0, 0, 0, 0.249},
        {0, 0, 0, 0, 0.249},
    }, 3);
    expect_play(button, "click-and-drag", MFButtonTriggerClickAndDrag, (Sample[]){
        {1, 0, 0, 0, 0.00},
        {1, 8, 0, 0, 0.05},
        {0, 0, 0, 0, 0.10},
    }, 3);
    expect_play(button, "movement of 7 is not drag", MFButtonTriggerClick, (Sample[]){
        {1, 0, 0, 0, 0.00},
        {1, 7, 0, 0, 0.05},
        {0, 0, 0, 0, 0.10},
    }, 3);
    expect_play(button, "movement of 3 is not drag", MFButtonTriggerClick, (Sample[]){
        {1, 0, 0, 0, 0.00},
        {1, 3, 0, 0, 0.05},
        {0, 0, 0, 0, 0.10},
    }, 3);
    expect_play(button, "accumulated movement is drag", MFButtonTriggerClickAndDrag, (Sample[]){
        {1, 0, 0, 0, 0.00},
        {1, 4, 0, 0, 0.02},
        {1, 4, 0, 0, 0.04},
        {0, 0, 0, 0, 0.06},
    }, 4);
    expect_play(button, "vertical pointer movement is drag", MFButtonTriggerClickAndDrag, (Sample[]){
        {1, 0, 0, 0, 0.00},
        {1, 0, 8, 0, 0.05},
        {0, 0, 0, 0, 0.10},
    }, 3);
    expect_play(button, "negative pointer movement is drag", MFButtonTriggerClickAndDrag, (Sample[]){
        {1, 0, 0, 0, 0.00},
        {1, -8, 0, 0, 0.05},
        {0, 0, 0, 0, 0.10},
    }, 3);
    expect_play(button, "click-and-scroll", MFButtonTriggerClickAndScroll, (Sample[]){
        {1, 0, 0, 0, 0.00},
        {1, 0, 0, 1, 0.05},
        {0, 0, 0, 0, 0.10},
    }, 3);
    expect_play(button, "wheel wins over drag in the same sample", MFButtonTriggerClickAndScroll, (Sample[]){
        {1, 0, 0, 0, 0.00},
        {1, 8, 0, 2, 0.05},
        {0, 0, 0, 0, 0.10},
    }, 3);
}

int main(void) {
    printf("lift-gestures\n");
    printf("observe hold=%.2f double=%.2f drag>%d\n", MFButtonTriggerHoldSeconds, MFButtonTriggerDoubleClickSeconds, MFButtonTriggerDragThreshold);
    check(MFButtonTriggerHoldSeconds == 0.25, "hold threshold is 0.25s");
    check(MFButtonTriggerDoubleClickSeconds == 0.26, "double-click window is 0.26s from mouse down");
    check(MFButtonTriggerDragThreshold == 7, "drag threshold is 7");

    MFButtonTriggerState fresh;
    MFButtonTriggerPath_reset(&fresh);
    check(fresh.down == 0 && fresh.clickLevel == 0 && fresh.selected == MFButtonTriggerNone && fresh.committed == 0, "reset is the real start state");

    int buttons[] = {3, 4, 5};
    for (int i = 0; i < 3; i++) run_button(buttons[i]);

    MFButtonTriggerState state;
    MFButtonTriggerPath_reset(&state);
    MFButtonTriggerPath_feed(&state, 4, 1, 0, 0, 0, 0.00);
    MFButtonTriggerPath_feed(&state, 4, 0, 0, 0, 0, 0.05);
    MFButtonTrigger got = MFButtonTriggerPath_feed(&state, 5, 1, 0, 0, 0, 0.10);
    got = MFButtonTriggerPath_feed(&state, 5, 0, 0, 0, 0, 0.12);
    printf("observe button 5 after button 4 click => %s\n", MFButtonTriggerPath_name(got));
    check(got == MFButtonTriggerClick, "a different button does not continue the double-click");

    printf("RESULT %s failures=%d\n", g_failures ? "FAIL" : "PASS", g_failures);
    return g_failures ? 1 : 0;
}
