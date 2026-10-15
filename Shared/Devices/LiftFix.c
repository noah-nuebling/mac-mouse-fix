//
// LiftFix.c
//

#include "LiftFix.h"

#include <ctype.h>
#include <string.h>

static int is_logitech(const char *manufacturer, uint16_t vendorID) {
    if (vendorID == kLiftVendorID) return 1;
    if (vendorID != 0) return 0;
    if (manufacturer == NULL || manufacturer[0] == '\0') return 1;
    char buf[128];
    size_t n = 0;
    for (const char *p = manufacturer; *p && n + 1 < sizeof buf; p++) {
        buf[n++] = (char)tolower((unsigned char)*p);
    }
    buf[n] = '\0';
    return strstr(buf, "logitech") != NULL;
}

/// Lowercase, non-alphanumeric runs become a single space, trimmed.
static void normalize_name(const char *in, char *out, size_t cap) {
    size_t n = 0;
    int space = 1;
    if (in == NULL) in = "";
    for (const char *p = in; *p && n + 1 < cap; p++) {
        unsigned char c = (unsigned char)*p;
        if (isalnum(c)) {
            out[n++] = (char)tolower(c);
            space = 0;
        } else if (!space) {
            out[n++] = ' ';
            space = 1;
        }
    }
    if (n > 0 && out[n - 1] == ' ') n--;
    out[n] = '\0';
}

static int has_word(const char *name, const char *word) {
    size_t len = strlen(word);
    const char *p = name;
    while ((p = strstr(p, word)) != NULL) {
        int start = (p == name) || p[-1] == ' ';
        int end = p[len] == '\0' || p[len] == ' ';
        if (start && end) return 1;
        p += len;
    }
    return 0;
}

static int name_is_lift(const char *productName) {
    char name[256];
    normalize_name(productName, name, sizeof name);
    if (strcmp(name, "lift") == 0) return 1;
    if (strcmp(name, "logitech lift") == 0) return 1;
    if (!has_word(name, "lift")) return 0;
    return has_word(name, "vertical") || has_word(name, "ergonomic") || has_word(name, "business");
}

LiftMapping LiftFix_decide(const char *productName, const char *manufacturer, uint16_t vendorID, uint16_t productID) {
    LiftMapping m;
    memset(&m, 0, sizeof m);
    m.backCID = kLiftCIDBack;
    m.forwardCID = kLiftCIDForward;
    m.backButton = kLiftButtonBack;
    m.forwardButton = kLiftButtonForward;
    m.featureID = kLiftReprogFeature;
    m.holdToHorizontalScroll = 1;
    if (!is_logitech(manufacturer, vendorID)) return m;
    int knownProduct = productID == kLiftProductConsumer;
    if (!knownProduct && !name_is_lift(productName)) return m;
    m.isLift = 1;
    m.holdToHorizontalScroll = 0;
    return m;
}

static int button_for_cid(const LiftMapping *m, uint16_t cid) {
    if (cid == m->backCID) return m->backButton;
    if (cid == m->forwardCID) return m->forwardButton;
    return 0;
}

static LiftReport blank_report(void) {
    LiftReport r;
    memset(&r, 0, sizeof r);
    return r;
}

static void set_edge(LiftReport *r, int button, int down) {
    *r = blank_report();
    r->button = button;
    r->downEdge = down ? 1 : 0;
    r->upEdge = down ? 0 : 1;
    r->held = down ? 1 : 0;
}

int LiftFix_pressedFromNotification(const uint8_t *report, int length, uint8_t featureIndex, uint16_t *pressed, int cap) {
    if (report == NULL || pressed == NULL || cap < 0 || length < 6) return -1;
    if (report[0] != 0x10 && report[0] != 0x11 && report[0] != 0x12) return -1;
    if (report[2] == 0xFF) return -1;
    if (report[2] != featureIndex) return -1;
    /// Event 0, software id 0. Requests we sent use a non-zero software id.
    if (report[3] != 0x00) return -1;
    int pairs = (length - 4) / 2;
    if (pairs > 4) pairs = 4;
    int n = 0;
    for (int i = 0; i < pairs; i++) {
        uint16_t cid = (uint16_t)((report[4 + (i * 2)] << 8) | report[5 + (i * 2)]);
        if (cid == 0) continue;
        if (n >= cap) return -1;
        pressed[n++] = cid;
    }
    return n;
}

int LiftFix_edgesForPressed(const LiftMapping *mapping, int inoutDown[2], const uint16_t *pressed, int pressedCount, LiftReport *out, int outCap) {
    if (mapping == NULL || !mapping->isLift || inoutDown == NULL || out == NULL) return 0;
    if (pressedCount < 0 || (pressedCount > 0 && pressed == NULL)) return -1;
    int want[2] = {0, 0};
    uint16_t cids[2] = {mapping->backCID, mapping->forwardCID};
    for (int i = 0; i < pressedCount; i++) {
        for (int c = 0; c < 2; c++) {
            if (pressed[i] == cids[c]) want[c] = 1;
        }
    }
    int n = 0;
    for (int c = 0; c < 2; c++) {
        if (want[c] == inoutDown[c]) continue;
        if (n >= outCap) return -1;
        set_edge(&out[n], c == 0 ? mapping->backButton : mapping->forwardButton, want[c]);
        inoutDown[c] = want[c];
        n++;
    }
    return n;
}

typedef struct {
    int down[2];
    int wheelConsumed[2];
} LiftTrack;

static int thumb_index(const LiftMapping *m, uint16_t cid) {
    if (cid == m->backCID) return 0;
    if (cid == m->forwardCID) return 1;
    return -1;
}

static int any_down(const LiftTrack *t) {
    return t->down[0] || t->down[1];
}

static int held_button(const LiftMapping *m, const LiftTrack *t) {
    if (t->down[0]) return m->backButton;
    if (t->down[1]) return m->forwardButton;
    return 0;
}

int LiftFix_apply(const LiftMapping *mapping, const LiftFrame *frames, int count, LiftReport *out, int outCap) {
    if (mapping == NULL || frames == NULL || out == NULL || count < 0) return -1;
    if (count > outCap) return -1;
    LiftTrack track;
    memset(&track, 0, sizeof track);

    for (int i = 0; i < count; i++) {
        const LiftFrame *f = &frames[i];
        LiftReport r = blank_report();
        int idx = (f->kind == kLiftFrameThumbDown || f->kind == kLiftFrameThumbUp) ? thumb_index(mapping, f->control) : -1;

        if (!mapping->isLift) {
            /// Factory sequence, unchanged. A non-Lift is not rewritten, and a
            /// Lift that has not been fixed still clicks on release.
            if (f->kind == kLiftFrameThumbDown && idx >= 0) {
                track.down[idx] = 1;
                track.wheelConsumed[idx] = 0;
            } else if (f->kind == kLiftFrameThumbUp && idx >= 0) {
                if (track.down[idx] && !track.wheelConsumed[idx]) {
                    r.button = button_for_cid(mapping, f->control);
                    r.downEdge = 1;
                    r.upEdge = 1;
                }
                track.down[idx] = 0;
                track.wheelConsumed[idx] = 0;
            } else if (f->kind == kLiftFramePointer) {
                r.dx = f->dx;
                r.dy = f->dy;
            } else if (f->kind == kLiftFrameWheel) {
                if (any_down(&track)) {
                    r.wheelHorizontal = f->wheelVertical;
                    for (int c = 0; c < 2; c++) {
                        if (track.down[c] && f->wheelVertical != 0) track.wheelConsumed[c] = 1;
                    }
                } else {
                    r.wheelVertical = f->wheelVertical;
                }
            } else if (f->kind == kLiftFrameButton) {
                r.button = (int)f->control;
                r.held = f->buttonDown ? 1 : 0;
                r.downEdge = f->buttonDown ? 1 : 0;
                r.upEdge = f->buttonDown ? 0 : 1;
            }
            out[i] = r;
            continue;
        }

        if (f->kind == kLiftFrameThumbDown && idx >= 0) {
            track.down[idx] = 1;
            track.wheelConsumed[idx] = 0;
            set_edge(&r, button_for_cid(mapping, f->control), 1);
        } else if (f->kind == kLiftFrameThumbUp && idx >= 0) {
            track.down[idx] = 0;
            set_edge(&r, button_for_cid(mapping, f->control), 0);
        } else if (f->kind == kLiftFramePointer) {
            r.dx = f->dx;
            r.dy = f->dy;
            r.button = held_button(mapping, &track);
            r.held = r.button != 0;
        } else if (f->kind == kLiftFrameWheel) {
            /// Hold-to-horizontal-scroll is off. Notches stay vertical.
            r.wheelVertical = f->wheelVertical;
            r.wheelHorizontal = 0;
            r.button = held_button(mapping, &track);
            r.held = r.button != 0;
        } else if (f->kind == kLiftFrameButton) {
            r.button = (int)f->control;
            r.held = f->buttonDown ? 1 : 0;
            r.downEdge = f->buttonDown ? 1 : 0;
            r.upEdge = f->buttonDown ? 0 : 1;
        }
        out[i] = r;
    }
    return count;
}

static void blank_command(LiftHidppCommand *c) {
    memset(c, 0, sizeof *c);
    c->length = kLiftHidppLongLength;
    c->report[0] = 0x11;
}

static uint16_t reporting_bits(int divert, int persistent, int rawXY, int rawWheel) {
    uint16_t bits = 0;
    /// Each mapping flag's next bit is the "valid" bit. Setting valid without
    /// the flag forces that behavior off for this session.
    if (divert) bits |= 0x0001;
    bits |= 0x0002;
    if (persistent) bits |= 0x0004;
    bits |= 0x0008;
    if (rawXY) bits |= 0x0010;
    bits |= 0x0020;
    if (rawWheel) bits |= 0x0400;
    bits |= 0x0800;
    return bits;
}

static void fill_set_reporting(LiftHidppCommand *c, uint8_t deviceIndex, uint8_t featureIndex, uint16_t cid, int button, int divert) {
    blank_command(c);
    uint16_t bits = reporting_bits(divert, 0, 0, 0);
    c->report[1] = deviceIndex;
    c->report[2] = featureIndex;
    c->report[3] = (uint8_t)((0x3 << 4) | kLiftSoftwareID); /// setCidReporting
    c->report[4] = (uint8_t)(cid >> 8);
    c->report[5] = (uint8_t)(cid & 0xFF);
    c->report[6] = (uint8_t)(bits & 0xFF);
    c->report[7] = 0; /// remap 0: keep the control's own mouse-button task
    c->report[8] = 0;
    c->report[9] = (uint8_t)((bits >> 8) & 0xFF);
    c->cid = cid;
    c->buttonNumber = button;
    c->divert = divert;
    c->persistent = 0;
    c->rawWheel = 0;
}

int LiftFix_setReportingCommands(const LiftMapping *mapping, uint8_t deviceIndex, uint8_t featureIndex, LiftHidppCommand out[2]) {
    if (mapping == NULL || !mapping->isLift || out == NULL) return 0;
    fill_set_reporting(&out[0], deviceIndex, featureIndex, mapping->backCID, mapping->backButton, 1);
    fill_set_reporting(&out[1], deviceIndex, featureIndex, mapping->forwardCID, mapping->forwardButton, 1);
    return 2;
}

int LiftFix_clearReportingCommands(const LiftMapping *mapping, uint8_t deviceIndex, uint8_t featureIndex, LiftHidppCommand out[2]) {
    if (mapping == NULL || !mapping->isLift || out == NULL) return 0;
    fill_set_reporting(&out[0], deviceIndex, featureIndex, mapping->backCID, mapping->backButton, 0);
    fill_set_reporting(&out[1], deviceIndex, featureIndex, mapping->forwardCID, mapping->forwardButton, 0);
    return 2;
}

void LiftFix_getFeatureCommand(uint8_t deviceIndex, uint8_t report[kLiftHidppLongLength]) {
    memset(report, 0, kLiftHidppLongLength);
    report[0] = 0x11;
    report[1] = deviceIndex;
    report[2] = 0x00; /// ROOT
    report[3] = (uint8_t)((0x0 << 4) | kLiftSoftwareID);
    report[4] = (uint8_t)(kLiftReprogFeature >> 8);
    report[5] = (uint8_t)(kLiftReprogFeature & 0xFF);
}

void LiftFix_getReportingCommand(uint8_t deviceIndex, uint8_t featureIndex, uint16_t cid, uint8_t report[kLiftHidppLongLength]) {
    memset(report, 0, kLiftHidppLongLength);
    report[0] = 0x11;
    report[1] = deviceIndex;
    report[2] = featureIndex;
    report[3] = (uint8_t)((0x2 << 4) | kLiftSoftwareID); /// getCidReporting
    report[4] = (uint8_t)(cid >> 8);
    report[5] = (uint8_t)(cid & 0xFF);
}

uint8_t LiftFix_parseFeatureIndex(const uint8_t *report, int length) {
    if (report == NULL || length < 7) return 0;
    if (report[0] != 0x11 && report[0] != 0x10) return 0;
    if (report[2] == 0xFF) return 0; /// HID++ error
    if (report[2] != 0x00) return 0;
    if ((report[3] >> 4) != 0x0) return 0;
    return report[4];
}

int LiftFix_readbackIsImmediateButton(const LiftMapping *mapping, const uint8_t *report, int length, uint16_t cid, int *buttonOut) {
    if (buttonOut) *buttonOut = 0;
    if (mapping == NULL || !mapping->isLift || report == NULL || length < 10) return 0;
    if (report[0] != 0x11 && report[0] != 0x10) return 0;
    if (report[2] == 0xFF) return 0;
    if ((report[3] >> 4) != 0x2) return 0;
    uint16_t got = (uint16_t)((report[4] << 8) | report[5]);
    if (got != cid) return 0;
    uint16_t flags = (uint16_t)(report[6] | (report[9] << 8));
    int diverted = (flags & 0x0001) != 0;
    int persistent = (flags & 0x0004) != 0;
    int rawXY = (flags & 0x0010) != 0;
    int rawWheel = (flags & 0x0400) != 0;
    int button = button_for_cid(mapping, cid);
    if (buttonOut) *buttonOut = button;
    return diverted && !persistent && !rawXY && !rawWheel && button != 0;
}
