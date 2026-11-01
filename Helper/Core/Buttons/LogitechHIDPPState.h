// Original protocol/state helpers for this fork; licensed under the MMF License.
#ifndef MF_LOGITECH_HIDPP_STATE_H
#define MF_LOGITECH_HIDPP_STATE_H
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <string.h>

// Accept complete frames only. IOKit may include or omit the report ID.
static inline size_t MFHIDPPNormalize(uint32_t id, const uint8_t *in, size_t n, uint8_t out[20]) {
    size_t expected = id == 0x11 ? 20 : id == 0x10 ? 7 : 0;
    if (!in || !expected) return 0;
    memset(out, 0, 20);
    if (n == expected && in[0] == id) memcpy(out, in, n);
    else if (n == expected - 1) { out[0] = (uint8_t)id; memcpy(out + 1, in, n); }
    else return 0;
    return expected;
}
static inline uint8_t MFHIDPPButtonBit(uint16_t cid) {
    return (cid == 0xC3 || cid == 0xD0) ? 1 : cid == 0xC4 ? 2 : 0;
}
static inline bool MFHIDPPButtonSnapshot(const uint8_t *r, size_t n, uint8_t feature, uint8_t *mask) {
    if (!r || n != 20 || r[0] != 0x11 || r[1] != 0xFF || !feature ||
        r[2] != feature || r[3] != 0) return false;
    uint8_t result = 0;
    for (size_t i = 4; i < 12; i += 2) result |= MFHIDPPButtonBit((uint16_t)(r[i] << 8 | r[i + 1]));
    *mask = result;
    return true;
}
// Match a complete response to exactly one pending request. Rotating software IDs
// keep a delayed response to the preceding request from satisfying this one.
static inline bool MFHIDPPReply(const uint8_t *r, size_t n, uint8_t device, uint8_t feature,
                               uint8_t function, uint8_t software) {
    if (!r || (n != 7 && n != 20) || r[1] != device || !software) return false;
    uint8_t command = (uint8_t)(function << 4 | software);
    return (r[2] == feature && r[3] == command) ||
           (r[2] == 0xFF && r[4] == feature && r[5] == command);
}
typedef struct { uint8_t up, down; } MFHIDPPEdges;
static inline MFHIDPPEdges MFHIDPPTransition(uint8_t *held, uint8_t snapshot, uint8_t owned) {
    uint8_t next = snapshot & owned;
    MFHIDPPEdges edges = { (uint8_t)(*held & ~next), (uint8_t)(next & ~*held) };
    *held = next;
    return edges; // Emit up before down. Reset/disconnect/sleep use snapshot=0.
}
#endif
