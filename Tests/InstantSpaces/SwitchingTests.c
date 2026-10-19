// Tests the embedded upstream switching engine without changing any real Spaces.
#include <ApplicationServices/ApplicationServices.h>
#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

static CFAbsoluteTime testTime = 100;
static CFAbsoluteTime test_now(void) { return testTime; }
static CFArrayRef displayFixture;
static bool infoUnavailable;
static int naturalMode = 1;
static Boolean test_natural(CFStringRef key, CFStringRef application, Boolean *valid) {
    (void)key; (void)application;
    *valid = naturalMode >= 0;
    return naturalMode == 1;
}
static int postedCount;
static CGEventRef posted[64];
static void capture_event(CGEventTapLocation location, CGEventRef event) {
    assert(location == kCGSessionEventTap);
    assert(postedCount < 64);
    posted[postedCount++] = CGEventCreateCopy(event);
}
#define CFPreferencesGetAppBooleanValue test_natural
#define CGEventPost capture_event
#define CFAbsoluteTimeGetCurrent test_now
#define CGSMainConnectionID test_connection
#define CGSGetActiveSpace test_active_space
#define CGSCopyManagedDisplaySpaces test_spaces
#include "../../Helper/Core/Drag/ThreeFingerSwipe/InstantSpaceSwitcher/ISS.c"

int32_t test_connection(void) { return 1; }
uint64_t test_active_space(int32_t connection) { (void)connection; return 101; }
CFArrayRef test_spaces(int32_t connection, CFStringRef display) {
    (void)connection; (void)display;
    return infoUnavailable ? NULL : CFRetain(displayFixture);
}

static CFDictionaryRef make_space(int id) {
    CFNumberRef number = CFNumberCreate(NULL, kCFNumberIntType, &id);
    const void *keys[] = {CFSTR("id64")};
    const void *values[] = {number};
    CFDictionaryRef result = CFDictionaryCreate(NULL, keys, values, 1,
        &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFRelease(number);
    return result;
}
static CFDictionaryRef make_display(const char *name, int current, int count) {
    CFStringRef identifier = CFStringCreateWithCString(NULL, name, kCFStringEncodingUTF8);
    CFMutableArrayRef spaces = CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);
    for (int i = 0; i < count; i++) {
        CFDictionaryRef space = make_space(100 + i);
        CFArrayAppendValue(spaces, space); CFRelease(space);
    }
    CFDictionaryRef active = make_space(current);
    const void *keys[] = {CFSTR("Display Identifier"), CFSTR("Spaces"), CFSTR("Current Space")};
    const void *values[] = {identifier, spaces, active};
    CFDictionaryRef result = CFDictionaryCreate(NULL, keys, values, 3,
        &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFRelease(identifier); CFRelease(spaces); CFRelease(active);
    return result;
}
static void clear_events(void) {
    for (int i = 0; i < postedCount; i++) CFRelease(posted[i]);
    postedCount = 0;
}
static void set_display(int current, int count) {
    if (displayFixture) CFRelease(displayFixture);
    CFDictionaryRef display = make_display("test-display", current, count);
    const void *values[] = {display};
    displayFixture = CFArrayCreate(NULL, values, 1, &kCFTypeArrayCallBacks);
    CFRelease(display);
    if (predictionsDict) CFDictionaryRemoveAllValues(predictionsDict);
    testTime += 2;
    clear_events();
}
static void assert_gesture(ISSDirection direction) {
    bool modern = iss_requires_event_augmentation();
    assert(postedCount == (modern ? 6 : 3));
    int phases[] = {1, 2, 4};
    for (int i = 0; i < 3; i++) {
        CGEventRef event = posted[i * (modern ? 2 : 1)];
        assert(CGEventGetIntegerValueField(event, (CGEventField)55) == 30);
        assert(CGEventGetIntegerValueField(event, (CGEventField)110) == 23);
        assert(CGEventGetIntegerValueField(event, (CGEventField)123) == 1);
        assert(CGEventGetIntegerValueField(event, (CGEventField)132) == phases[i]);
        double progress = CGEventGetDoubleValueField(event, (CGEventField)124);
        assert(fabs(progress) > 0 && fabs(progress) < 0.001);
        double expectedSign = direction == ISSDirectionRight ? 1 : -1;
        if (modern && naturalMode != 0) expectedSign *= -1;
        assert(progress * expectedSign > 0);
        double velocity = CGEventGetDoubleValueField(event, (CGEventField)129);
        assert(modern && i < 2 ? velocity == 0 : fabs(velocity) >= 2000);
        if (modern) {
            assert(CGEventGetIntegerValueField(posted[i * 2 + 1], (CGEventField)55) == 29);
            CFDataRef data = CGEventCreateData(NULL, event);
            assert(data && CFDataGetLength(data) > 0);
            CFRelease(data);
        }
    }
}
int main(void) {
    // Direction works with natural scrolling on/off and the system default.
    for (naturalMode = -1; naturalMode <= 1; naturalMode++) {
        set_display(101, 3);
        assert(iss_switch(ISSDirectionLeft)); assert_gesture(ISSDirectionLeft);
        set_display(101, 3);
        assert(iss_switch(ISSDirectionRight)); assert_gesture(ISSDirectionRight);
    }
    naturalMode = 1;
    // Initialization must stay embedded: no global input tap.
    assert(globalTap == NULL);
    set_display(100, 3);
    assert(!iss_switch(ISSDirectionLeft)); assert(postedCount == 0);
    assert(iss_switch(ISSDirectionRight)); assert_gesture(ISSDirectionRight);
    assert(globalTap == NULL);

    // A burst uses predictions while CGS still reports the old Space.
    clear_events();
    assert(iss_switch(ISSDirectionRight)); assert_gesture(ISSDirectionRight);
    clear_events();
    assert(!iss_switch(ISSDirectionRight)); assert(postedCount == 0);
    assert(iss_switch(ISSDirectionLeft)); assert_gesture(ISSDirectionLeft);

    set_display(102, 3);
    assert(!iss_switch(ISSDirectionRight)); assert(postedCount == 0);
    assert(iss_switch(ISSDirectionLeft)); assert_gesture(ISSDirectionLeft);

    set_display(100, 1);
    assert(!iss_switch(ISSDirectionLeft));
    assert(!iss_switch(ISSDirectionRight)); assert(postedCount == 0);

    // Missing APIs/data must never cause an unbounded high-velocity fling.
    infoUnavailable = true;
    assert(!iss_switch(ISSDirectionRight)); assert(postedCount == 0);
    infoUnavailable = false;

    // Per-display current Space overrides the global active Space.
    CFDictionaryRef display = make_display("second-display", 102, 4);
    ISSSpaceInfo info;
    assert(extract_space_info_from_display(display, 100, true, &info));
    assert(info.currentIndex == 2 && info.spaceCount == 4);
    assert(strcmp(info.displayID, "second-display") == 0);
    CFRelease(display);

    // A prediction expires so external Space changes are read again.
    set_display(100, 2);
    assert(iss_switch(ISSDirectionRight));
    clear_events();
    testTime += 2;
    assert(iss_switch(ISSDirectionRight)); assert_gesture(ISSDirectionRight);
    clear_events();
    CFRelease(displayFixture); iss_destroy();
    puts("Embedded instant switching tests passed");
    return 0;
}
