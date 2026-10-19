//
// LiftDevice.m
// HID++ I/O for the Lift thumb-button fix. The decision itself is LiftFix.
//

#import "LiftDevice.h"

#include <IOKit/hid/IOHIDKeys.h>
#include <signal.h>
#include <sys/event.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

static const CFTimeInterval kLiftReplyWaitSeconds = 0.4;
static const int kLiftSessionCap = 8;
static const int kLiftReportCap = 512;

static const uint8_t kLiftDeviceIndexes[] = {0xFF, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06};

typedef struct {
    int used;
    IOHIDDeviceRef device;
    void *deviceObject;
    LiftMapping mapping;
    LiftDeviceResult result;
    uint8_t deviceIndex;
    uint8_t featureIndex;
    int active;
    int didDivert;
    int down[2];
    int inTransaction;
    int replyReady;
    uint8_t reply[64];
    int replyLength;
    uint8_t expectDevice;
    uint8_t expectFeature;
    uint8_t expectFunction;
    uint8_t *reportBuffer;
    int callbackOn;
} LiftSession;

static LiftSession g_sessions[8];
static LiftEdgeHandler g_edge = NULL;
static CFRunLoopRef g_runLoop = NULL;
static IOHIDDeviceRef g_lastDevice = NULL;
static LiftDeviceResult g_lastResult;
static int g_quitWatch = 0;

static void destroy_session(LiftSession *s);
static void restore_session(LiftSession *s);

void LiftDeviceSetEdgeHandler(LiftEdgeHandler handler) {
    g_edge = handler;
}

static void remember_loop(void) {
    if (g_runLoop != NULL) return;
    g_runLoop = CFRunLoopGetCurrent();
    CFRetain(g_runLoop);
}

static LiftSession *find_session(IOHIDDeviceRef device) {
    if (device == NULL) return NULL;
    for (int i = 0; i < kLiftSessionCap; i++) {
        if (g_sessions[i].used && g_sessions[i].device == device) return &g_sessions[i];
    }
    return NULL;
}

static LiftSession *alloc_session(void) {
    for (int i = 0; i < kLiftSessionCap; i++) {
        if (!g_sessions[i].used) {
            memset(&g_sessions[i], 0, sizeof g_sessions[i]);
            g_sessions[i].used = 1;
            return &g_sessions[i];
        }
    }
    return NULL;
}

static void publish(LiftSession *s, IOHIDDeviceRef device, const LiftDeviceResult *result) {
    if (s) s->result = *result;
    g_lastDevice = device;
    g_lastResult = *result;
}

static void copy_prop_string(IOHIDDeviceRef device, CFStringRef key, char *buf, size_t cap) {
    buf[0] = '\0';
    CFTypeRef value = IOHIDDeviceGetProperty(device, key);
    if (value && CFGetTypeID(value) == CFStringGetTypeID()) {
        CFStringGetCString((CFStringRef)value, buf, (CFIndex)cap, kCFStringEncodingUTF8);
    }
}

static int copy_prop_int(IOHIDDeviceRef device, CFStringRef key) {
    CFTypeRef value = IOHIDDeviceGetProperty(device, key);
    int number = 0;
    if (value && CFGetTypeID(value) == CFNumberGetTypeID()) {
        CFNumberGetValue((CFNumberRef)value, kCFNumberIntType, &number);
    }
    return number;
}

static int normalize_report(uint32_t reportID, const uint8_t *report, CFIndex reportLength, uint8_t *buf, int cap) {
    if (report == NULL || reportLength <= 0 || cap < 4) return 0;
    int isHidpp = report[0] == 0x10 || report[0] == 0x11 || report[0] == 0x12;
    if (isHidpp && reportLength >= 4) {
        int n = (int)reportLength;
        if (n > cap) n = cap;
        memcpy(buf, report, (size_t)n);
        return n;
    }
    if (reportID == 0x10 || reportID == 0x11 || reportID == 0x12) {
        if ((int)reportLength + 1 > cap) return 0;
        buf[0] = (uint8_t)reportID;
        memcpy(buf + 1, report, (size_t)reportLength);
        return (int)reportLength + 1;
    }
    return 0;
}

static int reply_matches(const LiftSession *s, const uint8_t *buf, int n) {
    if (n < 4) return 0;
    if (buf[1] != s->expectDevice) return 0;
    if (buf[2] == 0xFF) return 1;
    if (buf[2] != s->expectFeature) return 0;
    if ((buf[3] & 0x0F) != kLiftSoftwareID) return 0;
    if ((buf[3] >> 4) != s->expectFunction) return 0;
    return 1;
}

static void input_callback(void *context, IOReturn result, void *sender, IOHIDReportType type, uint32_t reportID, uint8_t *report, CFIndex reportLength) {
    (void)result; (void)sender; (void)type;
    LiftSession *s = context;
    if (s == NULL || !s->used) return;
    uint8_t buf[64];
    int n = normalize_report(reportID, report, reportLength, buf, (int)sizeof buf);
    if (n < 4) return;

    if (s->inTransaction && reply_matches(s, buf, n)) {
        if (n > (int)sizeof s->reply) n = (int)sizeof s->reply;
        memcpy(s->reply, buf, (size_t)n);
        s->replyLength = n;
        s->replyReady = 1;
        return;
    }
    if (s->inTransaction || !s->active) return;

    uint16_t pressed[4];
    int count = LiftFix_pressedFromNotification(buf, n, s->featureIndex, pressed, 4);
    if (count < 0) return;
    LiftReport edges[4];
    int edgeCount = LiftFix_edgesForPressed(&s->mapping, s->down, pressed, count, edges, 4);
    if (edgeCount <= 0 || g_edge == NULL) return;
    id deviceObject = (__bridge id)s->deviceObject;
    for (int i = 0; i < edgeCount; i++) {
        int down = edges[i].downEdge ? 1 : 0;
        g_edge(deviceObject, edges[i].button, down);
    }
}

/// 1 reply, 0 timeout, -1 send failed. Does not stop the outer run loop.
static int transact(LiftSession *s, const uint8_t *cmd, uint8_t *reply, int *replyLen) {
    s->expectDevice = cmd[1];
    s->expectFeature = cmd[2];
    s->expectFunction = (uint8_t)(cmd[3] >> 4);
    s->replyReady = 0;
    s->replyLength = 0;
    s->inTransaction = 1;
    IOReturn sent = IOHIDDeviceSetReport(s->device, kIOHIDReportTypeOutput, cmd[0], cmd, kLiftHidppLongLength);
    if (sent != kIOReturnSuccess) {
        s->inTransaction = 0;
        return -1;
    }
    CFAbsoluteTime deadline = CFAbsoluteTimeGetCurrent() + kLiftReplyWaitSeconds;
    while (!s->replyReady && CFAbsoluteTimeGetCurrent() < deadline) {
        CFTimeInterval slice = deadline - CFAbsoluteTimeGetCurrent();
        if (slice <= 0) break;
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, slice, true);
    }
    s->inTransaction = 0;
    if (!s->replyReady) return 0;
    int n = s->replyLength;
    if (n > kLiftHidppLongLength) n = kLiftHidppLongLength;
    memcpy(reply, s->reply, (size_t)n);
    if (replyLen) *replyLen = n;
    return 1;
}

static void send_clear(LiftSession *s) {
    if (!s->didDivert || s->featureIndex == 0) return;
    LiftHidppCommand cmds[2];
    int n = LiftFix_clearReportingCommands(&s->mapping, s->deviceIndex, s->featureIndex, cmds);
    for (int i = 0; i < n; i++) {
        uint8_t reply[20];
        int replyLen = 0;
        transact(s, cmds[i].report, reply, &replyLen);
    }
    s->didDivert = 0;
    s->active = 0;
    s->down[0] = 0;
    s->down[1] = 0;
}

static void destroy_session(LiftSession *s) {
    if (s == NULL || !s->used) return;
    if (s->callbackOn && s->device && s->reportBuffer) {
        IOHIDDeviceRegisterInputReportCallback(s->device, s->reportBuffer, kLiftReportCap, NULL, NULL);
        s->callbackOn = 0;
    }
    free(s->reportBuffer);
    s->reportBuffer = NULL;
    if (s->deviceObject) {
        CFRelease(s->deviceObject);
        s->deviceObject = NULL;
    }
    if (s->device) {
        CFRelease(s->device);
        s->device = NULL;
    }
    memset(s, 0, sizeof *s);
}

static void restore_session(LiftSession *s) {
    if (s == NULL || !s->used) return;
    s->active = 0;
    send_clear(s);
    s->result.diverted = 0;
    publish(s, s->device, &s->result);
    IOHIDDeviceRef device = s->device;
    LiftDeviceResult result = s->result;
    destroy_session(s);
    g_lastDevice = device;
    g_lastResult = result;
}

static void on_sigterm(CFFileDescriptorRef fd, CFOptionFlags callBackTypes, void *info) {
    (void)callBackTypes; (void)info;
    struct kevent event;
    struct timespec none = {0, 0};
    int kq = CFFileDescriptorGetNativeDescriptor(fd);
    kevent(kq, NULL, 0, &event, 1, &none);
    LiftDeviceRestoreAll();
    signal(SIGTERM, SIG_DFL);
    raise(SIGTERM);
}

void LiftDeviceEnableQuitRestore(void) {
    if (g_quitWatch) return;
    remember_loop();
    /// Ignore first so the signal is delivered through kqueue, not by killing us.
    signal(SIGTERM, SIG_IGN);
    int kq = kqueue();
    if (kq < 0) {
        signal(SIGTERM, SIG_DFL);
        return;
    }
    struct kevent change;
    EV_SET(&change, SIGTERM, EVFILT_SIGNAL, EV_ADD, 0, 0, NULL);
    if (kevent(kq, &change, 1, NULL, 0, NULL) < 0) {
        close(kq);
        signal(SIGTERM, SIG_DFL);
        return;
    }
    CFFileDescriptorContext context = {0, NULL, NULL, NULL, NULL};
    CFFileDescriptorRef fd = CFFileDescriptorCreate(kCFAllocatorDefault, kq, true, on_sigterm, &context);
    if (fd == NULL) {
        close(kq);
        signal(SIGTERM, SIG_DFL);
        return;
    }
    CFFileDescriptorEnableCallBacks(fd, kCFFileDescriptorReadCallBack);
    CFRunLoopSourceRef source = CFFileDescriptorCreateRunLoopSource(kCFAllocatorDefault, fd, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopCommonModes);
    CFRelease(source);
    CFRelease(fd);
    g_quitWatch = 1;
}

void LiftDeviceRestoreAll(void) {
    if (g_runLoop != NULL && CFRunLoopGetCurrent() != g_runLoop) {
        LiftDeviceRequestRestore();
        return;
    }
    for (int i = 0; i < kLiftSessionCap; i++) {
        if (g_sessions[i].used) restore_session(&g_sessions[i]);
    }
}

void LiftDeviceRequestRestore(void) {
    if (g_runLoop == NULL) return;
    if (CFRunLoopGetCurrent() == g_runLoop) {
        LiftDeviceRestoreAll();
        return;
    }
    CFRunLoopPerformBlock(g_runLoop, kCFRunLoopCommonModes, ^{
        LiftDeviceRestoreAll();
    });
    CFRunLoopWakeUp(g_runLoop);
}

void LiftDeviceDetach(IOHIDDeviceRef device) {
    LiftSession *s = find_session(device);
    if (s == NULL) return;
    restore_session(s);
}

int LiftDeviceCopyResult(IOHIDDeviceRef device, LiftDeviceResult *out) {
    if (out == NULL || device == NULL) return 0;
    LiftSession *s = find_session(device);
    if (s) {
        *out = s->result;
        return 1;
    }
    if (g_lastDevice == device) {
        *out = g_lastResult;
        return 1;
    }
    return 0;
}

static void fill_identity(IOHIDDeviceRef device, LiftDeviceResult *result, LiftMapping *mapping) {
    char name[256];
    char manufacturer[256];
    copy_prop_string(device, CFSTR(kIOHIDProductKey), name, sizeof name);
    copy_prop_string(device, CFSTR(kIOHIDManufacturerKey), manufacturer, sizeof manufacturer);
    int vendor = copy_prop_int(device, CFSTR(kIOHIDVendorIDKey));
    int product = copy_prop_int(device, CFSTR(kIOHIDProductIDKey));
    snprintf(result->name, sizeof result->name, "%s", name);
    *mapping = LiftFix_decide(name, manufacturer, (uint16_t)vendor, (uint16_t)product);
    result->matched = mapping->isLift;
}

int LiftDeviceApply(IOHIDDeviceRef device, id deviceObject) {
    LiftDeviceResult result;
    memset(&result, 0, sizeof result);
    if (device == NULL) {
        snprintf(result.detail, sizeof result.detail, "no device");
        return 0;
    }
    remember_loop();

    LiftSession *existing = find_session(device);
    if (existing && existing->active) {
        return 1;
    }
    if (existing) destroy_session(existing);

    LiftMapping mapping;
    fill_identity(device, &result, &mapping);
    if (!mapping.isLift) {
        snprintf(result.detail, sizeof result.detail, "not a Lift");
        publish(NULL, device, &result);
        return 0;
    }

    IOReturn opened = IOHIDDeviceOpen(device, kIOHIDOptionsTypeNone);
    /// Device.m may already have opened this mouse. A second open can report
    /// exclusive access even though SetReport still works. Never Close here:
    /// that would drop the helper's own open, and open is not a refcount we own.
    if (opened == kIOReturnSuccess || opened == kIOReturnExclusiveAccess) {
        result.opened = 1;
    } else {
        result.opened = 0;
        snprintf(result.detail, sizeof result.detail, "could not open Lift (IOReturn %x)", opened);
        publish(NULL, device, &result);
        return 0;
    }

    LiftSession *s = alloc_session();
    if (s == NULL) {
        snprintf(result.detail, sizeof result.detail, "too many Lift sessions");
        publish(NULL, device, &result);
        return 0;
    }
    s->device = (IOHIDDeviceRef)CFRetain(device);
    if (deviceObject) s->deviceObject = (__bridge_retained void *)deviceObject;
    s->mapping = mapping;
    s->result = result;
    s->reportBuffer = calloc(1, kLiftReportCap);
    if (s->reportBuffer == NULL) {
        snprintf(result.detail, sizeof result.detail, "out of memory");
        publish(s, device, &result);
        destroy_session(s);
        return 0;
    }
    IOHIDDeviceScheduleWithRunLoop(s->device, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    IOHIDDeviceRegisterInputReportCallback(s->device, s->reportBuffer, kLiftReportCap, input_callback, s);
    s->callbackOn = 1;

    int spoke = 0;
    uint8_t featureIndex = 0;
    uint8_t deviceIndex = 0;
    for (size_t i = 0; i < sizeof kLiftDeviceIndexes; i++) {
        uint8_t cmd[kLiftHidppLongLength];
        LiftFix_getFeatureCommand(kLiftDeviceIndexes[i], cmd);
        uint8_t reply[kLiftHidppLongLength];
        int replyLen = 0;
        int rc = transact(s, cmd, reply, &replyLen);
        if (rc < 0) {
            snprintf(result.detail, sizeof result.detail, "HID++ send failed");
            publish(s, device, &result);
            destroy_session(s);
            return 0;
        }
        if (rc == 0) {
            snprintf(result.detail, sizeof result.detail, "HID++ timeout on device index 0x%02X", kLiftDeviceIndexes[i]);
            publish(s, device, &result);
            destroy_session(s);
            return 0;
        }
        if (reply[2] == 0xFF) continue;
        spoke = 1;
        featureIndex = LiftFix_parseFeatureIndex(reply, replyLen);
        deviceIndex = kLiftDeviceIndexes[i];
        break;
    }
    if (!spoke || featureIndex == 0) {
        snprintf(result.detail, sizeof result.detail, "REPROG_CONTROLS_V4 0x1B04 is not available");
        result.featureIndex = 0;
        publish(s, device, &result);
        destroy_session(s);
        return 0;
    }
    s->featureIndex = featureIndex;
    s->deviceIndex = deviceIndex;
    result.featureIndex = featureIndex;

    LiftHidppCommand sets[2];
    int setCount = LiftFix_setReportingCommands(&mapping, deviceIndex, featureIndex, sets);
    if (setCount != 2) {
        snprintf(result.detail, sizeof result.detail, "refusing to rewrite this device");
        publish(s, device, &result);
        destroy_session(s);
        return 0;
    }
    for (int i = 0; i < setCount; i++) {
        uint8_t reply[kLiftHidppLongLength];
        int replyLen = 0;
        int rc = transact(s, sets[i].report, reply, &replyLen);
        if (rc < 0 || rc == 0 || reply[2] == 0xFF) {
            if (s->didDivert) send_clear(s);
            snprintf(result.detail, sizeof result.detail, "setCidReporting failed for cid 0x%04X", sets[i].cid);
            result.diverted = 0;
            publish(s, device, &result);
            destroy_session(s);
            return 0;
        }
        s->didDivert = 1;
    }

    uint16_t cids[2] = {mapping.backCID, mapping.forwardCID};
    int *immediate[2] = {&result.backImmediate, &result.forwardImmediate};
    for (int i = 0; i < 2; i++) {
        uint8_t cmd[kLiftHidppLongLength];
        LiftFix_getReportingCommand(deviceIndex, featureIndex, cids[i], cmd);
        uint8_t reply[kLiftHidppLongLength];
        int replyLen = 0;
        int rc = transact(s, cmd, reply, &replyLen);
        int button = 0;
        int ok = (rc == 1) && LiftFix_readbackIsImmediateButton(&mapping, reply, replyLen, cids[i], &button);
        *immediate[i] = ok && button == (i == 0 ? mapping.backButton : mapping.forwardButton);
        if (!*immediate[i]) {
            send_clear(s);
            snprintf(result.detail, sizeof result.detail, "readback failed for cid 0x%04X", cids[i]);
            result.diverted = 0;
            result.backImmediate = i == 0 ? 0 : result.backImmediate;
            publish(s, device, &result);
            destroy_session(s);
            return 0;
        }
    }

    s->active = 1;
    result.diverted = 1;
    snprintf(result.detail, sizeof result.detail, "thumb controls are immediate buttons %d and %d", mapping.backButton, mapping.forwardButton);
    publish(s, device, &result);
    return 1;
}
