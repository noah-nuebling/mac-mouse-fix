//
// Opens attached mice and applies the shipped Lift device change.
// Restores before exit so a short run cannot leave the thumb buttons diverted.
//

#import "LiftDevice.h"

#import <IOKit/hid/IOHIDManager.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>

static void probe_device(IOHIDDeviceRef device, int *matched, int *openedLift) {
    char name[256] = {0};
    int vendor = 0;
    int product = 0;
    CFTypeRef nameValue = IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
    if (nameValue && CFGetTypeID(nameValue) == CFStringGetTypeID()) {
        CFStringGetCString((CFStringRef)nameValue, name, (CFIndex)sizeof name, kCFStringEncodingUTF8);
    }
    CFTypeRef vendorValue = IOHIDDeviceGetProperty(device, CFSTR(kIOHIDVendorIDKey));
    CFTypeRef productValue = IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductIDKey));
    if (vendorValue && CFGetTypeID(vendorValue) == CFNumberGetTypeID()) {
        CFNumberGetValue((CFNumberRef)vendorValue, kCFNumberIntType, &vendor);
    }
    if (productValue && CFGetTypeID(productValue) == CFNumberGetTypeID()) {
        CFNumberGetValue((CFNumberRef)productValue, kCFNumberIntType, &product);
    }

    int applied = LiftDeviceApply(device, nil);
    LiftDeviceResult result;
    memset(&result, 0, sizeof result);
    int copied = LiftDeviceCopyResult(device, &result);
    printf("device name=\"%s\" vendor=0x%04X product=0x%04X copied=%d matched=%d opened=%d feature=%d back=%d forward=%d diverted=%d applied=%d detail=%s\n",
           name, vendor, product, copied, result.matched, result.opened, result.featureIndex,
           result.backImmediate, result.forwardImmediate, result.diverted, applied, result.detail);
    if (result.matched) {
        *matched += 1;
        if (result.opened) *openedLift += 1;
        if (result.backImmediate && result.forwardImmediate) {
            printf("readback thumb controls are immediate buttons 4 and 5\n");
        }
    }
}

int main(void) {
    printf("lift-device\n");
    IOHIDManagerRef manager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDManagerOptionNone);
    if (manager == NULL) {
        printf("no Lift attached or could not be opened: HID manager create failed\n");
        return 0;
    }
    NSDictionary *mouse = @{
        @(kIOHIDDeviceUsagePageKey): @(kHIDPage_GenericDesktop),
        @(kIOHIDDeviceUsageKey): @(kHIDUsage_GD_Mouse),
    };
    NSDictionary *pointer = @{
        @(kIOHIDDeviceUsagePageKey): @(kHIDPage_GenericDesktop),
        @(kIOHIDDeviceUsageKey): @(kHIDUsage_GD_Pointer),
    };
    IOHIDManagerSetDeviceMatchingMultiple(manager, (__bridge CFArrayRef)@[mouse, pointer]);
    IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    IOReturn opened = IOHIDManagerOpen(manager, kIOHIDOptionsTypeNone);
    CFSetRef devices = IOHIDManagerCopyDevices(manager);
    int count = devices ? (int)CFSetGetCount(devices) : 0;
    printf("mice=%d managerOpen=0x%x\n", count, opened);

    int matched = 0;
    int openedLift = 0;
    if (count > 0) {
        IOHIDDeviceRef *list = calloc((size_t)count, sizeof(IOHIDDeviceRef));
        CFSetGetValues(devices, (const void **)list);
        for (int i = 0; i < count; i++) probe_device(list[i], &matched, &openedLift);
        free(list);
    }
    LiftDeviceRestoreAll();
    printf("restore-done\n");
    if (matched == 0 || openedLift == 0) {
        printf("no Lift attached or could not be opened\n");
    }
    if (devices) CFRelease(devices);
    CFRelease(manager);
    fflush(stdout);
    return 0;
}
