#include "event_serialize.h"

#include <ApplicationServices/ApplicationServices.h>
#include <CoreFoundation/CoreFoundation.h>
#include <mach/mach_time.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/sysctl.h>

#pragma pack(push, 1)

typedef struct {
    uint32_t size;
    uint32_t type;
    uint32_t options;
    uint8_t depth;
    uint8_t reserved[3];
} IOHIDEventBase;

typedef struct {
    IOHIDEventBase base;
    int32_t position_x;
    int32_t position_y;
    int32_t position_z;
    uint32_t swipe_mask;
    uint16_t gesture_motion;
    uint16_t gesture_flavor;
    int32_t swipe_progress;
} IOHIDFluidTouchGestureData;

typedef struct {
    IOHIDEventBase base;
    int32_t velocity_x;
    int32_t velocity_y;
    int32_t velocity_z;
} IOHIDVelocityEventData;

typedef struct {
    uint64_t timestamp;
    uint64_t sender_id;
    uint32_t options;
    uint32_t attribute_length;
    uint32_t event_count;
} IOHIDSystemQueueElementHeader;

#pragma pack(pop)

_Static_assert(sizeof(IOHIDEventBase) == 16, "unexpected IOHID event base layout");
_Static_assert(sizeof(IOHIDFluidTouchGestureData) == 40,
               "unexpected IOHID fluid gesture layout");
_Static_assert(sizeof(IOHIDVelocityEventData) == 28,
               "unexpected IOHID velocity layout");
_Static_assert(sizeof(IOHIDSystemQueueElementHeader) == 28,
               "unexpected IOHID queue header layout");

static const uint32_t kIOHIDEventTypeVelocity = 9;
static const uint32_t kIOHIDEventTypeFluidTouchGesture = 23;
static const uint16_t kIOHIDGestureFlavorDockPrimary = 3;

static int32_t iss_double_to_fixed1616(double val) {
    int32_t fixed = (int32_t)(val * 65536.0);
    if (fixed == 0 && val != 0.0) {
        return val > 0.0 ? 1 : -1;
    }
    return fixed;
}

static uint8_t *iss_generate_iohid_payload(CGEventRef event, size_t *out_length) {
    int64_t phase = CGEventGetIntegerValueField(event, (CGEventField)132);
    int64_t motion = CGEventGetIntegerValueField(event, (CGEventField)123);
    double progress = CGEventGetDoubleValueField(event, (CGEventField)124);
    double pos_x = CGEventGetDoubleValueField(event, (CGEventField)125);
    double pos_y = CGEventGetDoubleValueField(event, (CGEventField)126);
    double vel_x = CGEventGetDoubleValueField(event, (CGEventField)129);
    double vel_y = CGEventGetDoubleValueField(event, (CGEventField)130);
    int64_t swipe_mask = CGEventGetIntegerValueField(event, (CGEventField)115);

    bool include_velocity = (vel_x != 0.0 || vel_y != 0.0 || phase == 4);
    uint32_t event_count = include_velocity ? 2 : 1;
    size_t payload_length = sizeof(IOHIDSystemQueueElementHeader) + sizeof(IOHIDFluidTouchGestureData);
    if (include_velocity) {
        payload_length += sizeof(IOHIDVelocityEventData);
    }

    uint8_t *payload = (uint8_t *)malloc(payload_length);
    if (!payload) {
        return NULL;
    }
    memset(payload, 0, payload_length);

    IOHIDSystemQueueElementHeader *header = (IOHIDSystemQueueElementHeader *)payload;
    uint64_t timestamp = CGEventGetTimestamp(event);
    if (timestamp == 0) {
        timestamp = mach_absolute_time();
    }
    header->timestamp = timestamp;
    header->sender_id = 0;
    header->options = 0;
    header->attribute_length = 0;
    header->event_count = event_count;

    IOHIDFluidTouchGestureData *fluid = (IOHIDFluidTouchGestureData *)(payload + sizeof(IOHIDSystemQueueElementHeader));
    fluid->base.size = sizeof(IOHIDFluidTouchGestureData);
    fluid->base.type = kIOHIDEventTypeFluidTouchGesture;
    fluid->base.options = (uint32_t)((phase & 0xFF) << 24);
    fluid->base.depth = 0;
    fluid->position_x = iss_double_to_fixed1616(pos_x);
    fluid->position_y = iss_double_to_fixed1616(pos_y);
    fluid->position_z = 0;
    fluid->swipe_mask = (uint32_t)swipe_mask;
    fluid->gesture_motion = (uint16_t)motion;
    fluid->gesture_flavor = kIOHIDGestureFlavorDockPrimary;
    fluid->swipe_progress = iss_double_to_fixed1616(progress);

    if (include_velocity) {
        IOHIDVelocityEventData *velocity = (IOHIDVelocityEventData *)(payload + sizeof(IOHIDSystemQueueElementHeader) + sizeof(IOHIDFluidTouchGestureData));
        velocity->base.size = sizeof(IOHIDVelocityEventData);
        velocity->base.type = kIOHIDEventTypeVelocity;
        velocity->base.options = 0;
        velocity->base.depth = 1;
        velocity->velocity_x = iss_double_to_fixed1616(vel_x);
        velocity->velocity_y = iss_double_to_fixed1616(vel_y);
        velocity->velocity_z = 0;
    }

    *out_length = payload_length;
    return payload;
}

CGEventRef iss_augment_dock_swipe_event(CGEventRef event) {
    if (!event) {
        return NULL;
    }

    CFDataRef data = CGEventCreateData(kCFAllocatorDefault, event);
    if (!data) {
        return NULL;
    }

    const uint8_t *bytes = CFDataGetBytePtr(data);
    CFIndex length = CFDataGetLength(data);

    // Verify format version 2 (first 4 bytes: 00 00 00 02)
    if (length < 4 || bytes[0] != 0 || bytes[1] != 0 || bytes[2] != 0 || bytes[3] != 2) {
        CFRelease(data);
        return NULL;
    }

    size_t payload_length = 0;
    uint8_t *payload = iss_generate_iohid_payload(event, &payload_length);
    if (!payload) {
        CFRelease(data);
        return NULL;
    }

    // Allocate buffer for original data + 4-byte Tag + payload
    size_t new_length = (size_t)length + 4 + payload_length;
    uint8_t *new_bytes = (uint8_t *)malloc(new_length);
    if (!new_bytes) {
        free(payload);
        CFRelease(data);
        return NULL;
    }

    // Copy original event data
    memcpy(new_bytes, bytes, length);

    // Append 4-byte Tag:
    // Word 1: Size Words (payload_length in big-endian)
    new_bytes[length] = (uint8_t)((payload_length >> 8) & 0xFF);
    new_bytes[length + 1] = (uint8_t)(payload_length & 0xFF);
    // Word 2: (Type << 14) | Field ID (4205 in big-endian)
    new_bytes[length + 2] = (uint8_t)((4205 >> 8) & 0xFF);
    new_bytes[length + 3] = (uint8_t)(4205 & 0xFF);

    // Append Payload
    memcpy(new_bytes + length + 4, payload, payload_length);

    free(payload);
    CFRelease(data);

    CFDataRef new_data = CFDataCreate(kCFAllocatorDefault, new_bytes, (CFIndex)new_length);
    free(new_bytes);
    if (!new_data) {
        return NULL;
    }

    CGEventRef result = CGEventCreateFromData(kCFAllocatorDefault, new_data);
    CFRelease(new_data);
    return result;
}

bool iss_requires_event_augmentation(void) {
    static int cached_result = -1;
    if (cached_result != -1) {
        return cached_result;
    }

    const char *force_override = getenv("ISS_FORCE_EVENT_AUGMENTATION");
    if (force_override) {
        cached_result = (strcmp(force_override, "1") == 0) ? 1 : 0;
        return cached_result;
    }

    char version[32] = {0};
    size_t size = sizeof(version);
    if (sysctlbyname("kern.osproductversion", version, &size, NULL, 0) != 0) {
        cached_result = 0;
        return false;
    }

    int major = 0, minor = 0, patch = 0;
    int matched = sscanf(version, "%d.%d.%d", &major, &minor, &patch);
    if (matched < 1) {
        cached_result = 0;
        return false;
    }

    cached_result = (major >= 27) ? 1 : 0;
    return cached_result;
}
