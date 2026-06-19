//
// --------------------------------------------------------------------------
// TouchSimulator.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// Credits:
/// I originally found the code for the `postNavigationSwipeWithDirection:` function in Alexei Baboulevitch's SensibleSideButtons project under the name `SBFFakeSwipe:`. SensibleSideButtons was itself heavily based on natevw's macOS touch reverse engineering work ("CalfTrail Touch") for his app Sesamouse from wayy back in the day. Nate's work was the basis for all all of this. Thanks Nate! :)
///
/// On licenses:
/// SensibleSideButtons is published under the GPL license, which requires derivative work to be published under the same or equivalent license. However we're not using any code from SensibleSideButtons any more, since we rewrote that code based on our deeper understanding of the "CalTrail Touch" code. So therefore it should be fine that we're publishing MMF under the "MMF License" now.

/// Notes:
/// 
/// Between TouchSimulator.m and GestureScrollSimulator, we have all interesting touch input covered. Except a Force Touch, but we have the kMFSHLookUp symbolic hotkey which works almost as well.
///     Edit: Actually using LookUp by any other method except force touch is broken in Safari and Mail since few versions.

#import "TouchSimulator.h"
#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "Scroll.h"
#import "SharedUtility.h"
#import <Foundation/Foundation.h>
#import "HelperUtility.h"

#import <mach/mach_time.h>

#pragma mark - macOS 27 dock-swipe augmentation

/// Background:
///     Starting with macOS 27 (Tahoe/"Golden Gate" beta), the Dock server no longer acts on the *public* CGEvent gesture
///     fields for synthetic dock-swipe events. As a result the Mission Control / Spaces / Show-Desktop gestures that
///     `postDockSwipeEventWithDelta:` produces simply do nothing on the beta. See:
///         - https://github.com/noah-nuebling/mac-mouse-fix/issues/1892
///     The fix (first worked out by the InstantSpaceSwitcher / FasterSwiper community) is to embed the *raw IOKit HID
///     event payload* into the serialized CGEvent (field 4205) so the Dock server has the data it now requires. See:
///         - https://github.com/jurplel/InstantSpaceSwitcher/issues/72
///         - https://gist.github.com/mgbowen/5548f18ada2e37b23c9e86a8d80b71dc  (serialization-format notes)
///
/// How it works:
///     `CGEventCreateData()` / `CGEventCreateFromData()` use a private big-endian serialization format. We serialize the
///     event we already built, parse out its fields, splice in (or replace) field 4205 with a hand-built IOHID payload,
///     re-serialize, and rebuild the event with `CGEventCreateFromData()`. The numeric values inside the payload are
///     16.16 fixed-point, so precision is limited (a known consequence of this approach).
///
/// Caveats (this is reverse-engineered and could not be verified on-device against the beta here):
///     - The Dock server's sign convention for `progress`/`velocity` may be inverted on macOS 27 relative to older
///       versions. If a gesture triggers the *opposite* direction on the beta, flip the sign of field 124 (and/or the
///       velocity fields 129/130) in `postDockSwipeEventWithDelta:` for the augmented path.
///     - `gesture_flavor` is hard-coded to the "dock primary" flavor, which is what the space-switching apps use. If
///       vertical (Mission Control) or pinch (Show Desktop/Launchpad) gestures misbehave, this is the first knob to try.

static const uint8_t kMFCGEventDataTagInt64OrBlob   = 0b00;
static const uint8_t kMFCGEventDataTagInt32         = 0b01;
static const uint8_t kMFCGEventDataTagFloatingPoint = 0b11;

static const uint16_t kMFCGEventFieldGestureRawDataPayload = 4205;

typedef struct {
    uint16_t field_id;
    uint8_t tag;
    uint16_t size_words;
    uint8_t *payload;
    size_t payload_length;
} MFCGEventParsedField;

typedef struct {
    int32_t version;
    MFCGEventParsedField *fields;
    size_t field_count;
    size_t field_capacity;
} MFCGEventParsedData;

static uint16_t MFReadBE16(const uint8_t *data, size_t offset) {
    return (uint16_t)((data[offset] << 8) | data[offset + 1]);
}
static uint32_t MFReadBE32(const uint8_t *data, size_t offset) {
    return ((uint32_t)data[offset] << 24) | ((uint32_t)data[offset + 1] << 16) |
           ((uint32_t)data[offset + 2] << 8) | (uint32_t)data[offset + 3];
}
static void MFWriteBE16(uint8_t *out, size_t offset, uint16_t value) {
    out[offset]     = (uint8_t)((value >> 8) & 0xFF);
    out[offset + 1] = (uint8_t)(value & 0xFF);
}
static void MFWriteBE32(uint8_t *out, size_t offset, uint32_t value) {
    out[offset]     = (uint8_t)((value >> 24) & 0xFF);
    out[offset + 1] = (uint8_t)((value >> 16) & 0xFF);
    out[offset + 2] = (uint8_t)((value >> 8) & 0xFF);
    out[offset + 3] = (uint8_t)(value & 0xFF);
}

static void MFParsedEventDataFree(MFCGEventParsedData *parsed) {
    if (!parsed || !parsed->fields) return;
    for (size_t i = 0; i < parsed->field_count; i++) {
        free(parsed->fields[i].payload);
    }
    free(parsed->fields);
    parsed->fields = NULL;
    parsed->field_count = 0;
    parsed->field_capacity = 0;
}

static bool MFParseEventData(const uint8_t *data, size_t length, MFCGEventParsedData *out) {
    memset(out, 0, sizeof(*out));
    if (length < 4) return false;

    out->version = (int32_t)MFReadBE32(data, 0);
    if (out->version != 2) {
        DDLogWarn(@"TouchSimulator: Unsupported CGEvent data version %d during dock-swipe augmentation", out->version);
        return false;
    }

    out->field_capacity = 16;
    out->fields = (MFCGEventParsedField *)calloc(out->field_capacity, sizeof(MFCGEventParsedField));
    if (!out->fields) return false;

    size_t offset = 4;
    while (offset < length) {
        if (offset + 4 > length) { MFParsedEventDataFree(out); return false; }

        uint16_t size_words = MFReadBE16(data, offset);
        uint16_t tag_and_field = MFReadBE16(data, offset + 2);
        uint8_t tag = (uint8_t)((tag_and_field >> 14) & 0x3);
        uint16_t field_id = (uint16_t)(tag_and_field & 0x3FFF);
        offset += 4;

        size_t payload_length = 0;
        switch (tag) {
            case kMFCGEventDataTagInt64OrBlob:
                if (size_words == 1)      payload_length = 8;
                else if (size_words > 1)  payload_length = size_words;
                else { MFParsedEventDataFree(out); return false; }
                break;
            case kMFCGEventDataTagInt32:
            case kMFCGEventDataTagFloatingPoint:
                payload_length = (size_t)size_words * 4;
                break;
            default:
                MFParsedEventDataFree(out); return false;
        }

        if (offset + payload_length > length) { MFParsedEventDataFree(out); return false; }

        if (out->field_count >= out->field_capacity) {
            size_t new_capacity = out->field_capacity * 2;
            MFCGEventParsedField *new_fields = (MFCGEventParsedField *)realloc(out->fields, new_capacity * sizeof(MFCGEventParsedField));
            if (!new_fields) { MFParsedEventDataFree(out); return false; }
            out->fields = new_fields;
            out->field_capacity = new_capacity;
        }

        MFCGEventParsedField *field = &out->fields[out->field_count++];
        field->field_id = field_id;
        field->tag = tag;
        field->size_words = size_words;
        field->payload_length = payload_length;
        if (payload_length > 0) {
            field->payload = (uint8_t *)malloc(payload_length);
            if (!field->payload) { MFParsedEventDataFree(out); return false; }
            memcpy(field->payload, data + offset, payload_length);
        } else {
            field->payload = NULL;
        }
        offset += payload_length;
    }
    return true;
}

static size_t MFComputeSerializedLength(const MFCGEventParsedData *parsed, size_t new_payload_length) {
    size_t len = 4; /// version
    bool has4205 = false;
    for (size_t i = 0; i < parsed->field_count; i++) {
        if (parsed->fields[i].field_id == kMFCGEventFieldGestureRawDataPayload) {
            len += 4 + new_payload_length;
            has4205 = true;
        } else {
            len += 4 + parsed->fields[i].payload_length;
        }
    }
    if (!has4205) len += 4 + new_payload_length;
    return len;
}

static uint8_t *MFSerializeEventData(const MFCGEventParsedData *parsed, const uint8_t *new_payload, size_t new_payload_length, size_t *out_length) {
    size_t total_length = MFComputeSerializedLength(parsed, new_payload_length);
    uint8_t *result = (uint8_t *)malloc(total_length);
    if (!result) return NULL;

    size_t offset = 0;
    MFWriteBE32(result, offset, (uint32_t)parsed->version);
    offset += 4;

    bool added4205 = false;
    for (size_t i = 0; i < parsed->field_count; i++) {
        const MFCGEventParsedField *field = &parsed->fields[i];
        if (field->field_id == kMFCGEventFieldGestureRawDataPayload) {
            MFWriteBE16(result, offset, (uint16_t)new_payload_length); offset += 2;
            MFWriteBE16(result, offset, (uint16_t)((kMFCGEventDataTagInt64OrBlob << 14) | kMFCGEventFieldGestureRawDataPayload)); offset += 2;
            memcpy(result + offset, new_payload, new_payload_length); offset += new_payload_length;
            added4205 = true;
        } else {
            MFWriteBE16(result, offset, field->size_words); offset += 2;
            MFWriteBE16(result, offset, (uint16_t)((field->tag << 14) | field->field_id)); offset += 2;
            memcpy(result + offset, field->payload, field->payload_length); offset += field->payload_length;
        }
    }

    if (!added4205) {
        MFWriteBE16(result, offset, (uint16_t)new_payload_length); offset += 2;
        MFWriteBE16(result, offset, (uint16_t)((kMFCGEventDataTagInt64OrBlob << 14) | kMFCGEventFieldGestureRawDataPayload)); offset += 2;
        memcpy(result + offset, new_payload, new_payload_length); offset += new_payload_length;
    }

    *out_length = offset;
    return result;
}

#pragma pack(push, 1)
typedef struct {
    uint32_t size;
    uint32_t type;
    uint32_t options;
    uint8_t depth;
    uint8_t reserved[3];
} MFIOHIDEventBase;

typedef struct {
    MFIOHIDEventBase base;
    int32_t position_x;
    int32_t position_y;
    int32_t position_z;
    uint32_t swipe_mask;
    uint16_t gesture_motion;
    uint16_t gesture_flavor;
    int32_t swipe_progress;
} MFIOHIDFluidTouchGestureData;

typedef struct {
    MFIOHIDEventBase base;
    int32_t velocity_x;
    int32_t velocity_y;
    int32_t velocity_z;
} MFIOHIDVelocityEventData;

typedef struct {
    uint64_t timestamp;
    uint64_t sender_id;
    uint32_t options;
    uint32_t attribute_length;
    uint32_t event_count;
} MFIOHIDSystemQueueElementHeader;
#pragma pack(pop)

static const uint32_t kMFIOHIDEventTypeVelocity          = 9;
static const uint32_t kMFIOHIDEventTypeFluidTouchGesture = 23;
static const uint16_t kMFIOHIDGestureFlavorDockPrimary   = 3;

static int32_t MFDoubleToFixed1616(double val) {
    int32_t fixed = (int32_t)(val * 65536.0);
    if (fixed == 0 && val != 0.0) {
        return val > 0.0 ? 1 : -1;
    }
    return fixed;
}

static uint8_t *MFGenerateIOHIDPayload(CGEventRef event, size_t *out_length) {

    /// Read the public gesture fields we already set on `e30` in `postDockSwipeEventWithDelta:`.
    int64_t phase     = CGEventGetIntegerValueField(event, (CGEventField)132);
    int64_t motion    = CGEventGetIntegerValueField(event, (CGEventField)123); /// MFDockSwipeType (horizontal/vertical/pinch)
    double  progress  = CGEventGetDoubleValueField (event, (CGEventField)124); /// origin offset
    double  pos_x     = CGEventGetDoubleValueField (event, (CGEventField)125);
    double  pos_y     = CGEventGetDoubleValueField (event, (CGEventField)126);
    double  vel_x     = CGEventGetDoubleValueField (event, (CGEventField)129); /// exit speed
    double  vel_y     = CGEventGetDoubleValueField (event, (CGEventField)130);
    int64_t swipe_mask = CGEventGetIntegerValueField(event, (CGEventField)115);

    bool include_velocity = (vel_x != 0.0 || vel_y != 0.0 || phase == kIOHIDEventPhaseEnded);
    uint32_t event_count = include_velocity ? 2 : 1;
    size_t payload_length = sizeof(MFIOHIDSystemQueueElementHeader) + sizeof(MFIOHIDFluidTouchGestureData);
    if (include_velocity) payload_length += sizeof(MFIOHIDVelocityEventData);

    uint8_t *payload = (uint8_t *)malloc(payload_length);
    if (!payload) return NULL;
    memset(payload, 0, payload_length);

    size_t offset = 0;

    MFIOHIDSystemQueueElementHeader *header = (MFIOHIDSystemQueueElementHeader *)(payload + offset);
    offset += sizeof(MFIOHIDSystemQueueElementHeader);
    uint64_t timestamp = CGEventGetTimestamp(event);
    if (timestamp == 0) timestamp = mach_absolute_time();
    header->timestamp = timestamp;
    header->sender_id = 0;
    header->options = 0;
    header->attribute_length = 0;
    header->event_count = event_count;

    MFIOHIDFluidTouchGestureData *fluid = (MFIOHIDFluidTouchGestureData *)(payload + offset);
    offset += sizeof(MFIOHIDFluidTouchGestureData);
    fluid->base.size = sizeof(MFIOHIDFluidTouchGestureData);
    fluid->base.type = kMFIOHIDEventTypeFluidTouchGesture;
    fluid->base.options = (uint32_t)((phase & 0xFF) << 24);
    fluid->base.depth = 0;
    fluid->position_x = MFDoubleToFixed1616(pos_x);
    fluid->position_y = MFDoubleToFixed1616(pos_y);
    fluid->position_z = 0;
    fluid->swipe_mask = (uint32_t)swipe_mask;
    fluid->gesture_motion = (uint16_t)motion;
    fluid->gesture_flavor = kMFIOHIDGestureFlavorDockPrimary;
    fluid->swipe_progress = MFDoubleToFixed1616(progress);

    if (include_velocity) {
        MFIOHIDVelocityEventData *velocity = (MFIOHIDVelocityEventData *)(payload + offset);
        velocity->base.size = sizeof(MFIOHIDVelocityEventData);
        velocity->base.type = kMFIOHIDEventTypeVelocity;
        velocity->base.options = 0;
        velocity->base.depth = 1;
        velocity->velocity_x = MFDoubleToFixed1616(vel_x);
        velocity->velocity_y = MFDoubleToFixed1616(vel_y);
        velocity->velocity_z = 0;
    }

    *out_length = payload_length;
    return payload;
}

/// Returns a retained, augmented copy of `event` (caller must CFRelease), or NULL on failure.
static CGEventRef MFCreateAugmentedDockSwipeEvent(CGEventRef event) {
    if (!event) return NULL;

    CFDataRef data = CGEventCreateData(kCFAllocatorDefault, event);
    if (!data) {
        DDLogWarn(@"TouchSimulator: CGEventCreateData failed during dock-swipe augmentation");
        return NULL;
    }

    const uint8_t *bytes = CFDataGetBytePtr(data);
    CFIndex length = CFDataGetLength(data);

    MFCGEventParsedData parsed = {0};
    if (!MFParseEventData(bytes, (size_t)length, &parsed)) {
        CFRelease(data);
        return NULL;
    }

    size_t payload_length = 0;
    uint8_t *payload = MFGenerateIOHIDPayload(event, &payload_length);
    if (!payload) {
        MFParsedEventDataFree(&parsed);
        CFRelease(data);
        return NULL;
    }

    size_t new_length = 0;
    uint8_t *new_bytes = MFSerializeEventData(&parsed, payload, payload_length, &new_length);
    MFParsedEventDataFree(&parsed);
    free(payload);
    CFRelease(data);
    if (!new_bytes) {
        DDLogWarn(@"TouchSimulator: Failed to serialize augmented dock-swipe CGEvent");
        return NULL;
    }

    CFDataRef new_data = CFDataCreate(kCFAllocatorDefault, new_bytes, (CFIndex)new_length);
    free(new_bytes);
    if (!new_data) return NULL;

    CGEventRef result = CGEventCreateFromData(kCFAllocatorDefault, new_data);
    CFRelease(new_data);
    if (!result) {
        DDLogWarn(@"TouchSimulator: CGEventCreateFromData failed during dock-swipe augmentation");
    }
    return result;
}

/// Whether the running OS needs the IOHID-payload augmentation (macOS 27+).
static BOOL MFDockSwipeEventAugmentationRequired(void) {
    static BOOL required = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        required = [NSProcessInfo.processInfo isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){27, 0, 0}];
    });
    return required;
}

@implementation TouchSimulator

static NSArray *_nullArray;
static NSMutableDictionary *_swipeInfo;

/// This function allows you to go back and forward in apps like Safari.
///
/// Navigation swipe events are actually quite complex and seem to be similar to dock swipes internally (They seem to also have an origin offset and other similar fields from what i've seen)
/// However, this simple function replicates all of their interesting functionality, so I didn't bother reverse engineering them more thoroughly.
/// Navigation swipes are naturally produced by three finger swipes, but only if you set "System Preferences > Trackpad > More Gestures > Swipe between pages" to "Swipe with three fingers" or to "Swipe with two or three fingers"
+ (void)postNavigationSwipeEventWithDirection:(IOHIDSwipeMask)dir {
    
    CGEventRef e = CGEventCreate(NULL);
    CGEventSetIntegerValueField(e, 55, NSEventTypeGesture);
    CGEventSetIntegerValueField(e, 110, kIOHIDEventTypeNavigationSwipe);
    CGEventSetIntegerValueField(e, 132, kIOHIDEventPhaseBegan);
    CGEventSetIntegerValueField(e, 115, dir);
    
    CGEventPost(kCGHIDEventTap, e);
    CGEventSetIntegerValueField(e, 115, kIOHIDSwipeNone);
    CGEventSetIntegerValueField(e, 132, kIOHIDEventPhaseEnded);
    CGEventPost(kCGHIDEventTap, e);
    CFRelease(e);
}

+ (void)postSmartZoomEvent {
    
    CGEventRef e = CGEventCreate(NULL);
    CGEventSetIntegerValueField(e, 55, 29); /// NSEventTypeGesture
    CGEventSetIntegerValueField(e, 110, 22); /// kIOHIDEventTypeZoomToggle
    CGEventPost(kCGHIDEventTap, e);
    CFRelease(e);
}

+ (void)postRotationEventWithRotation:(double)rotation phase:(IOHIDEventPhaseBits)phase {
    
    CGEventRef e = CGEventCreate(NULL);
    /// Could also use CGEventSetType() here
    CGEventSetIntegerValueField(e, 55, 29); /// NSEventTypeGesture
    CGEventSetIntegerValueField(e, 110, 5); /// kIOHIDEventTypeRotation
    CGEventSetDoubleValueField(e, 114, rotation);
    CGEventSetIntegerValueField(e, 132, phase);
    CGEventPost(kCGHIDEventTap, e);
    CFRelease(e);
}

+ (void)postMagnificationEventWithMagnification:(double)magnification phase:(IOHIDEventPhaseBits)phase {
    
    /// Using undocumented CGEventFields found through Calftrail TouchExtractor and through analyzing Calftrail TouchSynthesis to create a working magnification event from scratch
    ///  This was the the start of this whole touch simulation thing!
    
    /// Debug
    
    DDLogDebug(@"Posting magnification event with amount: %f, phase: %d", magnification, phase);
    
    /// Create and post event
    
    CGEventRef event = CGEventCreate(NULL);
    CGEventSetType(event, 29); /// 29 -> NSEventTypeGesture
    CGEventSetIntegerValueField(event, 110, 8); /// 8 -> kIOHIDEventTypeZoom
    CGEventSetIntegerValueField(event, 132, phase);
    CGEventSetDoubleValueField(event, 113, magnification);
    CGEventPost(kCGHIDEventTap, event);
    CFRelease(event);
}

+ (void)postDockSwipeEventWithDelta:(double)d type:(MFDockSwipeType)type phase:(IOHIDEventPhaseBits)phase invertedFromDevice:(BOOL)invertedFromDevice {

    /// Fix Apple bug
    ///   If we don't do this, the exitSpeed is interpreted in the wrong direction when opening Launchpad, leading to a noticable jitter.
    ///   This also happens on an Apple Trackpad if you turn natural scrolling off.
    ///
    /// Old notes on trying to figure out the problem:
    /// 
    /// (At first we tried adjust the exitSpeed)
    /// - ... this jitter is also present with the trackpad but it's far less noticable.
    ///   I don't know why it's so much less noticable on the trackpad. Maybe our exitSpeed values are too large, or something about the timing of how the events are sent affects the jitter.
    ///     Sidenote: I just compared this to the real events, and I noticed these differences which might affect the issue:
    ///     1. Real pinch events seem to be sent about every 8ms (but with a lot of variation so maybe it's just a coincidence) on a 16ms refresh rate screen.
    ///     2. The `end` events usually still have non-zero deltas in the real dockswipes! I was under the assumption that `end` events should always have 0 deltas (and that's how the TouchAnimator works, too)
    /// - Solution: By halving the exitSpeed, we keep Reveal Desktop feeling nice and responsive, while making the LaunchPad jitter about as noticable as with a real trackpad.
    
    if (type == kMFDockSwipeTypePinch && !invertedFromDevice) {
        invertedFromDevice = YES;
        d = -d;
    }
    
    /// State
    
    static double _dockSwipeOriginOffset = 0.0;
    static double _dockSwipeLastDelta = 0.0;
    static NSTimer *_doubleSendTimer;
    static NSTimer *_tripleSendTimer;
    
    /// Constants
    
    int valFor41 = 33231;
    
    /// Update originOffset
    
    if (phase == kIOHIDEventPhaseBegan) {
        _dockSwipeOriginOffset = d;
    } else if (phase == kIOHIDEventPhaseChanged){
        if (d == 0) {
            return;
        }
        _dockSwipeOriginOffset += d;
    }
    
    /// Debug
    
    
    if (runningPreRelease()) {
        static CFTimeInterval _dockSwipeLastTimeStamp = 0.0;
        CFTimeInterval ts = CACurrentMediaTime();
        CFTimeInterval timeDiff = ts - _dockSwipeLastTimeStamp;
        _dockSwipeLastTimeStamp = ts;
        DDLogDebug(@"\nDock Swipe send with "
                   @"delta: %@, "
//                   @"lastDelta: %@, "
//                   @"prevOriginOffset: %@ "
//                   @"type: %@, "
                   @"phase: %@, "
                   @"timeSinceLast: %@"
                   ,
                   @(d),
//                   @(_dockSwipeLastDelta),
//                   @(_dockSwipeOriginOffset),
//                   @(type),
                   @(phase),
                   @(timeDiff));
    }
    
    /// Override end phase with canceled phase
    ///     Note: Would it make more sense for this to happen in the 'driver' of the event simulation? (As of [Feb 2025] the 'drivers' are Scroll.m and ModifiedDragOutputThreeFingerSwipe.m)
    if (phase == kIOHIDEventPhaseEnded) {
        if ([SharedUtility signOf:_dockSwipeLastDelta] == [SharedUtility signOf:_dockSwipeOriginOffset]) {
            phase = kIOHIDEventPhaseEnded;
        } else {
            phase = kIOHIDEventPhaseCancelled;
        }
    }
    
    ///
    /// Create events
    ///
    
    /// Create type 29 (NSEventTypeGesture) event
    
    CGEventRef e29 = CGEventCreate(NULL);
    CGEventSetDoubleValueField(e29, 55, NSEventTypeGesture); /// Set event type
    CGEventSetDoubleValueField(e29, 41, valFor41); /// No idea what this does but it might help. // TODO: Why?
    
    /// Create type 30 event
    
    CGEventRef e30 = CGEventCreate(NULL);
    
    CGEventSetDoubleValueField(e30, 55,  NSEventTypeMagnify); /// Set event type (idk why it's magnify but it is...)
    CGEventSetDoubleValueField(e30, 110, kIOHIDEventTypeDockSwipe); /// Set subtype
    CGEventSetDoubleValueField(e30, 132, phase);
    CGEventSetDoubleValueField(e30, 134, phase); /// Not sure if necessary

    CGEventSetDoubleValueField(e30, 124, _dockSwipeOriginOffset); /// Origin offset
    Float32 ofsFloat32 = (Float32)_dockSwipeOriginOffset;
    uint32_t ofsInt32; /// Has to be `uint32_t` not `int32_t`!
    memcpy(&ofsInt32, &ofsFloat32, sizeof(ofsFloat32));
    int64_t ofsInt64 = (int64_t)ofsInt32;
    CGEventSetIntegerValueField(e30, 135, ofsInt64); /// Weird ass encoded version of origin offset. It's a 64 bit integer containing the bits for a 32 bit float. No idea why this is necessary, but it is.
    
    CGEventSetDoubleValueField(e30, 41, valFor41); /// This mighttt help not sure what it do
    
    /// The values below are probably an encoded version of the values in MFDockSwipeType. We could probably somehow convert that and put it in here instead of assigning these weird constants
    
    double weirdTypeOrSum = -1;
    if (type == kMFDockSwipeTypeHorizontal) {
        weirdTypeOrSum = 1.401298464324817e-45;
    } else if (type == kMFDockSwipeTypeVertical) {
        weirdTypeOrSum = 2.802596928649634e-45;
    } else if (type == kMFDockSwipeTypePinch) {
        weirdTypeOrSum = 4.203895392974451e-45;
    } else {
        assert(false);
    }
    
    CGEventSetDoubleValueField(e30, 119, weirdTypeOrSum);
    CGEventSetDoubleValueField(e30, 139, weirdTypeOrSum);  /// Probs not necessary
    
    CGEventSetDoubleValueField(e30, 123, type); /// Horizontal or vertical
    CGEventSetDoubleValueField(e30, 165, type); /// Horizontal or vertical // Probs not necessary
    
    CGEventSetIntegerValueField(e30, 136, invertedFromDevice ? 1 : 0);
    
    if (phase == kIOHIDEventPhaseEnded || phase == kIOHIDEventPhaseCancelled) {
        
        /// Set Exit Speed
        /// Notes:
        /// - This only seems to affect the pinch dockSwipes. Doesn't seem to affect horiztonal or vertical.
        /// -`*100` is a rough approximation of how the real values look. `*50` also seemed to work well.
        
        double exitSpeed = _dockSwipeLastDelta*100;
        CGEventSetDoubleValueField(e30, 129, exitSpeed);
        CGEventSetDoubleValueField(e30, 130, exitSpeed);
        
        /// Debug
        ///     Debugging of stuck-bug. When the stuck bug occurs, This always seems to be called and in the appropriate order (The fake dockSwipe with the end-phase is always called after all other phases).
        ///     Random observation: I just got it stuck with just the trackpad! Right after getting it stuck with mouse.
        ///     This makes me think the bug is about timing / how slow the events are sent, and not in which order the events are sent or with on which thread the events are sent as I suspected initially.
        ///     Another hint towards this is, that the stuck-bug seems to occur more, the slower and more stuttery the UI is (the longer the computer has been running)
        /// I fixed the stuck-bug now. (See the comment with "This fixed the stuck-bug!" in ModifiedDrag.m) But I still don't know what caused it exactly.
        DDLogDebug(@"Dock Swipe exit: %f, originOffset: %f, phase: %hu", _dockSwipeLastDelta*100, _dockSwipeOriginOffset, phase);

    } else {
        DDLogDebug(@"Dock Swipe delta: %f originOffset: %f, phase: %hu", d, _dockSwipeOriginOffset, phase);
        
    }
    
    ///
    /// Augment for macOS 27+
    ///   On macOS 27 the Dock server ignores the public CGEvent gesture fields for synthetic dock swipes; it requires the
    ///   raw IOHID payload embedded in the serialized event. We post the augmented copy of `e30` instead of `e30` itself.
    ///   `e29` (the generic NSEventTypeGesture event) doesn't carry the dock-swipe data, so it's posted unchanged.
    ///   See the big comment block near the top of this file for background & caveats.
    ///

    CGEventRef e30ToPost = e30; /// Borrowed reference unless we replace it with an owned augmented copy below.
    if (MFDockSwipeEventAugmentationRequired()) {
        CGEventRef augmented = MFCreateAugmentedDockSwipeEvent(e30);
        if (augmented != NULL) {
            e30ToPost = augmented; /// Owned (+1); released at the end of this function.
        } else {
            DDLogWarn(@"TouchSimulator: Dock-swipe augmentation failed; posting un-augmented event (will likely be ignored on macOS 27+)");
        }
    }

    ///
    /// Send events
    ///

    DDLogDebug(@"TouchSimulator: Sending dockSwipe with phase %d with events: %@ %@", phase, e30ToPost, e29);

    CGEventPost(kCGSessionEventTap, e30ToPost); /// Not sure if order matters
    CGEventPost(kCGSessionEventTap, e29);
    
    if (phase == kIOHIDEventPhaseBegan) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            /// Invalidate scheduled double-send
            /// Notes:
            ///     - We invalidate the double/triple send timers here, since otherwise, the double/triple-sent end events can cancel the new gesture.
            ///     - Docs say timers must be scheduled and invalidated from the same thread. That's why we dispatch to the main thread.
            ///     - Threading is a bit messy. We should probably have a unified output-event thread, where we do all this.
            ///     - Race condition? – Since we dispatch_async() right above, in edge-cases, the gesture might still be canceled right after the kIOHIDEventPhaseBegan events are sent. A unified output-event thread should allow us to fix this.
            
            if (_doubleSendTimer != nil) [_doubleSendTimer invalidate];
            if (_tripleSendTimer != nil) [_tripleSendTimer invalidate];
            _doubleSendTimer = nil;
            _tripleSendTimer = nil;
        });
        
    } else if (phase == kIOHIDEventPhaseEnded || phase == kIOHIDEventPhaseCancelled) {

        /// Double-send end-events
        /// Notes:
        ///     - The inital dockSwipe event we post will be ignored by the system when it is under load (I called this the "stuck bug" in other places). Sending the event again with a delay of 200ms (0.2s) gets it unstuck almost always. Sending the event twice gives us the best of both responsiveness and reliability.
        ///     - In Scroll.m, even with sending the event again after 0.2 seconds, the stuck bug still happens a bunch for some reason. Even though this almost completely eliminates the bug in ModifiedDrag.m . Sending it again after 0.5 seconds works better but still sometimes happens.
        ///         Edit: Doesn't happen anymore on M1. Edit 2: [Feb 2025] The double-sending code used to be broken for a while (fixed in e8f90d2f32829e3e5f1621fa8e4b58634c9ea07b) . Maybe that's why we observed the stuck-bug for Scroll.m here?

        /// Put the events into a dict
        ///     Note: The `events` dict retains the events, and the timers retain the events dict -> Once the timers are invalidated, the events are automatically released.
        ///     Edit: We didn't release the events in MMF 3.0.0 Beta 6. I wonder why I didn't notice this? (Should leak a little bit of memory.) We then moved to using `__bridge_transfer`
        ///                 On 28.08.2024 we moved to using `__bridge` and simply calling `CFRelease()` afterwards. (That's the same as using `__bridge_transfer`, which I find confusing.)

        NSDictionary *events = @{@"e30": (__bridge id)e30ToPost, @"e29": (__bridge id)e29};
        
        /// Dispatch to main queue
        /// Notes:
        ///     - 27.08.2024 (macOS Sequoia Beta) - The double/triple send didn't work. I fixed it by adding  `dispatch_async(dispatch_get_main_queue()`. Not sure how long this had been broken. (Fixed in e8f90d2f32829e3e5f1621fa8e4b58634c9ea07b)
        ///     - Might worsen responsivity to do this on the main thread? I feel like we should simplify the threading of the entire app so there are 4 threads: input events, output events, ui (main thread) and background (stuff like checking for updates)
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            /// Invalidate existing timers
            /// Notes:
            ///     - Docs say timers must be scheduled and invalidated from the same thread. We should be doing that since we dispatch everything to the main queue
            
            if (_doubleSendTimer != nil) [_doubleSendTimer invalidate];
            if (_tripleSendTimer != nil) [_tripleSendTimer invalidate];

            /// Schedule new timers
            
            _doubleSendTimer = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(dockSwipeTimerFired:) userInfo:events repeats:NO];
            _tripleSendTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(dockSwipeTimerFired:) userInfo:events repeats:NO];
        });
        
    }
    
    ///
    /// Release events
    ///

    CFRelease(e29);
    CFRelease(e30);
    if (e30ToPost != e30) {
        /// Release our owned augmented copy. If it was stored in the `events` dict above, that dict holds its own
        /// retain, so it stays alive until the double/triple-send timers are invalidated.
        CFRelease(e30ToPost);
    }
    
    ///
    /// Update state
    ///
    
    _dockSwipeLastDelta = d;
}

+ (void)dockSwipeTimerFired:(NSTimer *)timer {
    
    NSDictionary *events = timer.userInfo;
    CGEventRef e30 = (__bridge CGEventRef)events[@"e30"];
    CGEventRef e29 = (__bridge CGEventRef)events[@"e29"];
    
    DDLogDebug(@"TouchSimulator: Sending dockSwipe end (Double/Triple) with events: %@ %@", e30, e29);
    
    CGEventPost(kCGSessionEventTap, e30);
    CGEventPost(kCGSessionEventTap, e29);
}


@end

