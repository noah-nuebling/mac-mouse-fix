#include "../../Helper/Core/Buttons/LogitechHIDPPState.h"
#include <assert.h>
#include <stdio.h>
static void edge(uint8_t *held, uint8_t snapshot, uint8_t owned, uint8_t up, uint8_t down) {
    MFHIDPPEdges e = MFHIDPPTransition(held, snapshot, owned);
    assert(e.up == up && e.down == down);
}
int main(void) {
    uint8_t report[20] = {0x11, 0xFF, 0x09, 0, 0, 0xD0, 0, 0xC4};
    uint8_t out[20], mask = 77;
    assert(MFHIDPPNormalize(0x11, report, 20, out) == 20);
    assert(!memcmp(report, out, 20));
    assert(MFHIDPPNormalize(0x11, report + 1, 19, out) == 20);
    assert(!memcmp(report, out, 20));
    for (size_t n = 0; n < 19; n++) assert(!MFHIDPPNormalize(0x11, report, n, out));
    assert(!MFHIDPPNormalize(0x11, report, 21, out));
    assert(!MFHIDPPNormalize(2, report, 20, out));
    assert(!MFHIDPPNormalize(0x11, NULL, 20, out));
    uint8_t shortReport[7] = {0x10,0xFF,0xFF,0,9,0x3C,1};
    assert(MFHIDPPNormalize(0x10, shortReport, 7, out) == 7);
    assert(MFHIDPPNormalize(0x10, shortReport + 1, 6, out) == 7);
    assert(!MFHIDPPButtonSnapshot(shortReport, 7, 9, &mask));
    assert(MFHIDPPButtonSnapshot(report, 20, 9, &mask) && mask == 3);
    for (size_t n = 0; n < 20; n++) assert(!MFHIDPPButtonSnapshot(report, n, 9, &mask));
    assert(!MFHIDPPButtonSnapshot(report, 20, 0, &mask));
    assert(!MFHIDPPButtonSnapshot(report, 20, 8, &mask));
    report[1] = 1; assert(!MFHIDPPButtonSnapshot(report, 20, 9, &mask)); report[1] = 0xFF;
    report[3] = 1; assert(!MFHIDPPButtonSnapshot(report, 20, 9, &mask)); report[3] = 0;
    report[3] = 0x10; assert(!MFHIDPPButtonSnapshot(report, 20, 9, &mask)); report[3] = 0;
    report[5] = 0xC3; report[7] = 0xD0; // alias + duplicate must produce one thumb press
    assert(MFHIDPPButtonSnapshot(report, 20, 9, &mask) && mask == 1);
    report[5] = 0x53; report[7] = 0x56; // native buttons are never diverted
    assert(MFHIDPPButtonSnapshot(report, 20, 9, &mask) && mask == 0);
    report[8] = 0x12; report[9] = 0xD0; // high byte matters
    assert(MFHIDPPButtonSnapshot(report, 20, 9, &mask) && mask == 0);
    uint8_t reply[20] = {0x11,0xFF,9,0x3C};
    assert(MFHIDPPReply(reply, 20, 0xFF, 9, 3, 12));
    assert(!MFHIDPPReply(reply, 20, 1, 9, 3, 12));
    assert(!MFHIDPPReply(reply, 20, 0xFF, 8, 3, 12));
    assert(!MFHIDPPReply(reply, 20, 0xFF, 9, 2, 12));
    assert(!MFHIDPPReply(reply, 20, 0xFF, 9, 3, 11));
    assert(!MFHIDPPReply(reply, 6, 0xFF, 9, 3, 12));
    assert(!MFHIDPPReply(reply, 20, 0xFF, 9, 3, 0));
    assert(MFHIDPPReply(shortReport, 7, 0xFF, 9, 3, 12));
    uint8_t held = 0;
    edge(&held, 1, 3, 0, 1); // thumb down
    for (int i = 0; i < 10000; i++) edge(&held, 1, 3, 0, 0); // hold, no duplicate
    edge(&held, 3, 3, 0, 2); // simultaneous mode shift
    edge(&held, 2, 3, 1, 0); // thumb up while shift remains held
    edge(&held, 1, 3, 2, 1); // release before new press
    edge(&held, 0, 3, 1, 0); // sleep/disconnect/exit cleanup
    edge(&held, 0, 3, 0, 0); // idempotent cleanup
    edge(&held, 3, 1, 0, 1); // mode shift not owned -> ignore
    edge(&held, 0, 1, 1, 0);
    edge(&held, 2, 3, 0, 2); // reconnect / fresh hold
    edge(&held, 0, 3, 2, 0);
    // Exhaustively check every snapshot and ownership combination.
    for (unsigned old = 0; old < 4; old++) for (unsigned next = 0; next < 4; next++)
    for (unsigned owned = 0; owned < 4; owned++) {
        held = old;
        MFHIDPPEdges e = MFHIDPPTransition(&held, next, owned);
        assert(held == (next & owned));
        assert(e.up == (old & ~(next & owned)) && e.down == ((next & owned) & ~old));
        assert(!(e.up & e.down));
    }
    puts("PASS: HID++ framing, CID filtering, aliases, duplicate/hold, simultaneous buttons, cleanup and 64 exhaustive transitions");
}
