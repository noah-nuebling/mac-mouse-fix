//
// Drives the shipped Lift fix: LiftFix_decide then LiftFix_apply, plus the
// HID++ command bytes and notification edges that device code sends.
//

#include "LiftFix.h"

#include <stdio.h>
#include <string.h>

static int g_failures = 0;

static void check(int ok, const char *what) {
    printf("%s %s\n", ok ? "PASS" : "FAIL", what);
    if (!ok) g_failures++;
}

static LiftFrame frame(LiftFrameKind kind, uint16_t control, int buttonDown, int dx, int dy, int wheel) {
    LiftFrame f;
    memset(&f, 0, sizeof f);
    f.kind = kind;
    f.control = control;
    f.buttonDown = buttonDown;
    f.dx = dx;
    f.dy = dy;
    f.wheelVertical = wheel;
    return f;
}

static void dump_report(const char *label, int index, const LiftReport *r) {
    printf("  %s[%d] button=%d down=%d up=%d held=%d dx=%d dy=%d vertical=%d horizontal=%d\n",
           label, index, r->button, r->downEdge, r->upEdge, r->held, r->dx, r->dy, r->wheelVertical, r->wheelHorizontal);
}

static int same_report(const LiftReport *r, int button, int down, int up, int held, int dx, int dy, int vertical, int horizontal) {
    return r->button == button && r->downEdge == down && r->upEdge == up && r->held == held
        && r->dx == dx && r->dy == dy && r->wheelVertical == vertical && r->wheelHorizontal == horizontal;
}

static void expect_report(const char *label, int index, const LiftReport *r, int button, int down, int up, int held, int dx, int dy, int vertical, int horizontal) {
    char what[256];
    snprintf(what, sizeof what, "%s[%d] button=%d down=%d up=%d held=%d dx=%d dy=%d vertical=%d horizontal=%d",
             label, index, button, down, up, held, dx, dy, vertical, horizontal);
    dump_report(label, index, r);
    check(same_report(r, button, down, up, held, dx, dy, vertical, horizontal), what);
}

static LiftMapping decide(const char *name, const char *manufacturer, uint16_t vendor, uint16_t product) {
    return LiftFix_decide(name, manufacturer, vendor, product);
}

static void check_identity(const char *name, const char *manufacturer, uint16_t vendor, uint16_t product, int wantLift) {
    LiftMapping mapping = decide(name, manufacturer, vendor, product);
    char what[256];
    snprintf(what, sizeof what, "decide name=\"%s\" vendor=0x%04X product=0x%04X isLift=%d holdToHorizontal=%d",
             name ? name : "", vendor, product, mapping.isLift, mapping.holdToHorizontalScroll);
    printf("observe %s\n", what);
    check(mapping.isLift == wantLift, what);
    check(mapping.holdToHorizontalScroll == (wantLift ? 0 : 1), "hold-to-horizontal-scroll follows isLift");
    check(mapping.backCID == kLiftCIDBack && mapping.forwardCID == kLiftCIDForward, "thumb cids stay 0x0053 and 0x0056");
    check(mapping.backButton == 4 && mapping.forwardButton == 5, "thumb buttons stay 4 and 5");
    if (!wantLift) {
        LiftHidppCommand cmds[2];
        int n = LiftFix_setReportingCommands(&mapping, 0xFF, 0x09, cmds);
        check(n == 0, "non-Lift setReportingCommands returns 0");
    }
}

/// Factory thumb press: silent until release, and a wheel tick while held is horizontal scroll.
static void check_factory(const LiftMapping *mapping, uint16_t cid, int button, const char *label) {
    LiftFrame frames[] = {
        frame(kLiftFrameThumbDown, cid, 0, 0, 0, 0),
        frame(kLiftFramePointer, 0, 0, 3, 4, 0),
        frame(kLiftFrameWheel, 0, 0, 0, 0, 5),
        frame(kLiftFrameThumbUp, cid, 0, 0, 0, 0),
    };
    LiftReport out[4];
    int n = LiftFix_apply(mapping, frames, 4, out, 4);
    printf("observe factory %s apply=%d\n", label, n);
    check(n == 4, "factory apply writes one report per frame");
    expect_report(label, 0, &out[0], 0, 0, 0, 0, 0, 0, 0, 0);
    expect_report(label, 1, &out[1], 0, 0, 0, 0, 3, 4, 0, 0);
    expect_report(label, 2, &out[2], 0, 0, 0, 0, 0, 0, 0, 5);
    expect_report(label, 3, &out[3], 0, 0, 0, 0, 0, 0, 0, 0);

    LiftFrame click[] = {
        frame(kLiftFrameThumbDown, cid, 0, 0, 0, 0),
        frame(kLiftFrameThumbUp, cid, 0, 0, 0, 0),
    };
    LiftReport pulse[2];
    n = LiftFix_apply(mapping, click, 2, pulse, 2);
    printf("observe factory click %s apply=%d\n", label, n);
    check(n == 2, "factory click apply writes both frames");
    expect_report(label, 0, &pulse[0], 0, 0, 0, 0, 0, 0, 0, 0);
    expect_report(label, 1, &pulse[1], button, 1, 1, 0, 0, 0, 0, 0);
}

static void check_fixed_thumb(const LiftMapping *mapping, uint16_t cid, int button, const char *label) {
    LiftFrame frames[] = {
        frame(kLiftFrameThumbDown, cid, 0, 0, 0, 0),
        frame(kLiftFramePointer, 0, 0, 9, -2, 0),
        frame(kLiftFrameWheel, 0, 0, 0, 0, 4),
        frame(kLiftFrameThumbUp, cid, 0, 0, 0, 0),
    };
    LiftReport out[4];
    int n = LiftFix_apply(mapping, frames, 4, out, 4);
    printf("observe fixed %s apply=%d\n", label, n);
    check(n == 4, "fixed apply writes one report per frame");
    expect_report(label, 0, &out[0], button, 1, 0, 1, 0, 0, 0, 0);
    expect_report(label, 1, &out[1], button, 0, 0, 1, 9, -2, 0, 0);
    expect_report(label, 2, &out[2], button, 0, 0, 1, 0, 0, 4, 0);
    expect_report(label, 3, &out[3], button, 0, 1, 0, 0, 0, 0, 0);
}

static void check_buttons_and_idle_wheel(const LiftMapping *mapping, const char *label) {
    LiftFrame frames[] = {
        frame(kLiftFrameButton, 1, 1, 0, 0, 0),
        frame(kLiftFrameButton, 1, 0, 0, 0, 0),
        frame(kLiftFrameButton, 2, 1, 0, 0, 0),
        frame(kLiftFrameButton, 2, 0, 0, 0, 0),
        frame(kLiftFrameButton, 3, 1, 0, 0, 0),
        frame(kLiftFrameButton, 3, 0, 0, 0, 0),
        frame(kLiftFrameWheel, 0, 0, 0, 0, 2),
    };
    LiftReport out[7];
    int n = LiftFix_apply(mapping, frames, 7, out, 7);
    printf("observe buttons %s apply=%d\n", label, n);
    check(n == 7, "button 1-3 apply writes every frame");
    expect_report(label, 0, &out[0], 1, 1, 0, 1, 0, 0, 0, 0);
    expect_report(label, 1, &out[1], 1, 0, 1, 0, 0, 0, 0, 0);
    expect_report(label, 2, &out[2], 2, 1, 0, 1, 0, 0, 0, 0);
    expect_report(label, 3, &out[3], 2, 0, 1, 0, 0, 0, 0, 0);
    expect_report(label, 4, &out[4], 3, 1, 0, 1, 0, 0, 0, 0);
    expect_report(label, 5, &out[5], 3, 0, 1, 0, 0, 0, 0, 0);
    expect_report(label, 6, &out[6], 0, 0, 0, 0, 0, 0, 2, 0);
}

static void check_both_thumbs(const LiftMapping *mapping) {
    LiftFrame frames[] = {
        frame(kLiftFrameThumbDown, kLiftCIDBack, 0, 0, 0, 0),
        frame(kLiftFrameThumbDown, kLiftCIDForward, 0, 0, 0, 0),
        frame(kLiftFrameWheel, 0, 0, 0, 0, 1),
        frame(kLiftFrameThumbUp, kLiftCIDBack, 0, 0, 0, 0),
        frame(kLiftFrameWheel, 0, 0, 0, 0, 3),
        frame(kLiftFrameThumbUp, kLiftCIDForward, 0, 0, 0, 0),
    };
    LiftReport out[6];
    int n = LiftFix_apply(mapping, frames, 6, out, 6);
    printf("observe both-thumbs apply=%d\n", n);
    check(n == 6, "both thumbs apply writes every frame");
    expect_report("both", 0, &out[0], 4, 1, 0, 1, 0, 0, 0, 0);
    expect_report("both", 1, &out[1], 5, 1, 0, 1, 0, 0, 0, 0);
    expect_report("both", 2, &out[2], 4, 0, 0, 1, 0, 0, 1, 0);
    expect_report("both", 3, &out[3], 4, 0, 1, 0, 0, 0, 0, 0);
    expect_report("both", 4, &out[4], 5, 0, 0, 1, 0, 0, 3, 0);
    expect_report("both", 5, &out[5], 5, 0, 1, 0, 0, 0, 0, 0);
}

static void check_commands(const LiftMapping *mapping) {
    LiftHidppCommand cmds[2];
    int n = LiftFix_setReportingCommands(mapping, 0xFF, 0x0B, cmds);
    printf("observe setReporting count=%d\n", n);
    check(n == 2, "Lift setReportingCommands returns 2");
    uint16_t cids[2] = {kLiftCIDBack, kLiftCIDForward};
    int buttons[2] = {4, 5};
    for (int i = 0; i < 2; i++) {
        const uint8_t *r = cmds[i].report;
        printf("  set[%d] id=0x%02X dev=0x%02X feat=0x%02X fn=0x%02X cid=%02X%02X flags=%02X%02X remap=%02X%02X divert=%d persistent=%d rawWheel=%d button=%d\n",
               i, r[0], r[1], r[2], r[3], r[4], r[5], r[9], r[6], r[7], r[8], cmds[i].divert, cmds[i].persistent, cmds[i].rawWheel, cmds[i].buttonNumber);
        check(cmds[i].cid == cids[i] && cmds[i].buttonNumber == buttons[i], "command cid and button");
        check(r[0] == 0x11 && r[1] == 0xFF && r[2] == 0x0B, "long report, device index, feature index");
        check(r[3] == 0x31, "setCidReporting function 3 software id 1");
        check(r[4] == (cids[i] >> 8) && r[5] == (cids[i] & 0xFF), "cid bytes");
        check(r[6] == 0x2B && r[9] == 0x08, "divert on, persist off, raw-xy off, raw-wheel off");
        check(r[7] == 0 && r[8] == 0, "remap 0 keeps the control's own button task");
        check(cmds[i].divert == 1 && cmds[i].persistent == 0 && cmds[i].rawWheel == 0, "session divert, not persistent, raw wheel off");
        check((r[6] & 0x01) == 0x01 && (r[6] & 0x04) == 0 && (r[9] & 0x04) == 0, "diverted bit set, persistent and raw-wheel value bits clear");
    }

    LiftHidppCommand clear[2];
    n = LiftFix_clearReportingCommands(mapping, 0xFF, 0x0B, clear);
    check(n == 2, "clearReportingCommands returns 2");
    for (int i = 0; i < 2; i++) {
        const uint8_t *r = clear[i].report;
        printf("  clear[%d] flags=%02X%02X divert=%d persistent=%d\n", i, r[9], r[6], clear[i].divert, clear[i].persistent);
        check(r[6] == 0x2A && r[9] == 0x08, "clear keeps valid bits and turns divert off");
        check((r[6] & 0x03) == 0x02, "divert value clear, divert-valid set");
        check(clear[i].divert == 0 && clear[i].persistent == 0 && clear[i].rawWheel == 0, "clear is not persistent");
    }

    uint8_t feature[kLiftHidppLongLength];
    LiftFix_getFeatureCommand(0xFF, feature);
    check(feature[0] == 0x11 && feature[2] == 0x00 && feature[3] == 0x01, "ROOT GetFeature header");
    check(feature[4] == 0x1B && feature[5] == 0x04, "asks for feature 0x1B04");

    uint8_t got[20];
    memset(got, 0, sizeof got);
    got[0] = 0x11;
    got[2] = 0x00;
    got[3] = 0x01;
    got[4] = 0x0B;
    check(LiftFix_parseFeatureIndex(got, 20) == 0x0B, "parse feature index 0x0B");
    got[2] = 0xFF;
    check(LiftFix_parseFeatureIndex(got, 20) == 0, "HID++ error is not a feature index");

    uint8_t read[20];
    memset(read, 0, sizeof read);
    read[0] = 0x11;
    read[2] = 0x0B;
    read[3] = 0x21;
    read[4] = 0x00;
    read[5] = 0x53;
    read[6] = 0x2B;
    read[9] = 0x08;
    int button = 0;
    int ok = LiftFix_readbackIsImmediateButton(mapping, read, 20, kLiftCIDBack, &button);
    printf("observe readback back ok=%d button=%d\n", ok, button);
    check(ok == 1 && button == 4, "readback of diverted cid 0x0053 is button 4");
    read[5] = 0x56;
    ok = LiftFix_readbackIsImmediateButton(mapping, read, 20, kLiftCIDForward, &button);
    printf("observe readback forward ok=%d button=%d\n", ok, button);
    check(ok == 1 && button == 5, "readback of diverted cid 0x0056 is button 5");
    read[9] = 0x0C;
    ok = LiftFix_readbackIsImmediateButton(mapping, read, 20, kLiftCIDForward, &button);
    check(ok == 0, "raw-wheel still on is not an immediate button");
    read[9] = 0x08;
    read[6] = 0x2F;
    ok = LiftFix_readbackIsImmediateButton(mapping, read, 20, kLiftCIDForward, &button);
    check(ok == 0, "persistent divert is not the session fix");
    read[6] = 0x2A;
    ok = LiftFix_readbackIsImmediateButton(mapping, read, 20, kLiftCIDForward, &button);
    check(ok == 0, "divert off is not an immediate button");
}

static void check_notification(const LiftMapping *mapping) {
    uint8_t note[20];
    memset(note, 0, sizeof note);
    note[0] = 0x11;
    note[1] = 0xFF;
    note[2] = 0x0B;
    note[3] = 0x00;
    note[4] = 0x00;
    note[5] = 0x53;
    note[8] = 0x00;
    note[9] = 0x56;
    uint16_t pressed[4];
    int count = LiftFix_pressedFromNotification(note, 20, 0x0B, pressed, 4);
    printf("observe notification count=%d c0=0x%04X c1=0x%04X\n", count, count > 0 ? pressed[0] : 0, count > 1 ? pressed[1] : 0);
    check(count == 2 && pressed[0] == kLiftCIDBack && pressed[1] == kLiftCIDForward, "notification lists both thumb cids and skips the zero slot");

    int down[2] = {0, 0};
    LiftReport edges[4];
    int n = LiftFix_edgesForPressed(mapping, down, pressed, count, edges, 4);
    check(n == 2, "both thumbs produce a down edge");
    expect_report("edge", 0, &edges[0], 4, 1, 0, 1, 0, 0, 0, 0);
    expect_report("edge", 1, &edges[1], 5, 1, 0, 1, 0, 0, 0, 0);

    memset(note + 4, 0, 8);
    count = LiftFix_pressedFromNotification(note, 20, 0x0B, pressed, 4);
    n = LiftFix_edgesForPressed(mapping, down, pressed, count, edges, 4);
    printf("observe release count=%d edges=%d\n", count, n);
    check(count == 0 && n == 2, "all-zero notification releases both thumbs");
    expect_report("edge", 0, &edges[0], 4, 0, 1, 0, 0, 0, 0, 0);
    expect_report("edge", 1, &edges[1], 5, 0, 1, 0, 0, 0, 0, 0);

    note[3] = 0x01;
    check(LiftFix_pressedFromNotification(note, 20, 0x0B, pressed, 4) < 0, "a software-id reply is not a button event");
}

int main(void) {
    printf("lift-buttons\n");
    check_identity("LIFT VERTICAL ERGONOMIC MOUSE", "Logitech", kLiftVendorID, kLiftProductConsumer, 1);
    check_identity("LIFT For Business", "Logitech", kLiftVendorID, 0, 1);
    check_identity("Lift for Business", "Logitech", kLiftVendorID, 0, 1);
    check_identity("LIFT", "Logitech", kLiftVendorID, 0, 1);
    check_identity("logitech lift", "Logitech", kLiftVendorID, 0, 1);
    check_identity("LIFT VERTICAL ERGONOMIC MOUSE", "", 0, 0, 1);
    check_identity("", "Logitech", kLiftVendorID, kLiftProductConsumer, 1);
    check_identity("MX Master 3S", "Logitech", kLiftVendorID, 0xB034, 0);
    check_identity("Signature M650", "Logitech", kLiftVendorID, 0xB02A, 0);
    check_identity("Magic Mouse", "Apple", 0x004C, 0x0269, 0);
    check_identity("Logi Bolt Receiver", "Logitech", kLiftVendorID, 0xC548, 0);
    check_identity("LIFT VERTICAL ERGONOMIC MOUSE", "Other", 0x1234, kLiftProductConsumer, 0);
    check_identity("liftkit", "Logitech", kLiftVendorID, 0, 0);

    LiftMapping consumer = decide("LIFT VERTICAL ERGONOMIC MOUSE", "Logitech", kLiftVendorID, kLiftProductConsumer);
    LiftMapping business = decide("LIFT For Business", "Logitech", kLiftVendorID, 0);
    check(consumer.isLift && business.isLift, "consumer and business mappings come from decide");

    check_fixed_thumb(&consumer, kLiftCIDBack, 4, "consumer-back");
    check_fixed_thumb(&consumer, kLiftCIDForward, 5, "consumer-forward");
    check_fixed_thumb(&business, kLiftCIDBack, 4, "business-back");
    check_fixed_thumb(&business, kLiftCIDForward, 5, "business-forward");
    check_buttons_and_idle_wheel(&consumer, "consumer-buttons");
    check_buttons_and_idle_wheel(&business, "business-buttons");
    check_both_thumbs(&consumer);

    LiftMapping master = decide("MX Master 3S", "Logitech", kLiftVendorID, 0xB034);
    LiftMapping bolt = decide("Logi Bolt Receiver", "Logitech", kLiftVendorID, 0xC548);
    check(!master.isLift && !bolt.isLift, "non-Lift decide stays off");
    check_factory(&master, kLiftCIDBack, 4, "mx-back");
    check_factory(&master, kLiftCIDForward, 5, "mx-forward");
    check_buttons_and_idle_wheel(&master, "mx-buttons");
    check_factory(&bolt, kLiftCIDBack, 4, "bolt-back");

    check_commands(&consumer);
    check_notification(&consumer);

    printf("RESULT %s failures=%d\n", g_failures ? "FAIL" : "PASS", g_failures);
    return g_failures ? 1 : 0;
}
