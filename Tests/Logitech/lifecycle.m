// Exercise the production activation/verification/cleanup methods with an in-memory
// HID++ transport. Never create a HID manager, device or CGEvent.
#include <assert.h>
#import <CoreGraphics/CoreGraphics.h>
static CGEventRef captured;
static void capturePost(CGEventTapLocation location, CGEventRef event) {
    assert(location == kCGHIDEventTap);
    if (captured) CFRelease(captured);
    captured = CGEventCreateCopy(event);
}
#define CGEventPost capturePost
#import "../../Helper/Core/Buttons/LogitechButtonDiverter.m"
#undef CGEventPost
#include <assert.h>

@interface FakeDiverter : LogitechButtonDiverter
@property NSMutableDictionary<NSNumber *, NSNumber *> *reporting;
@property NSMutableArray<NSString *> *edges;
@property BOOL asleep;
@property BOOL protectedInput;
@property int requests;
@property int opens;
@property BOOL failOpen;
@property BOOL shortReportingReply;
@property BOOL loseWriteReply;
@property int writes;
@end
@implementation FakeDiverter
- (instancetype)init {
    if ((self = [super init])) { _reporting = [NSMutableDictionary dictionary]; _edges = [NSMutableArray array]; }
    return self;
}
- (void)enqueue:(dispatch_block_t)block { block(); }
- (BOOL)secureInputActive { return _protectedInput; }
- (BOOL)openInterface:(MFLogiInterface *)i { _opens++; i.isOpen = !_failOpen; return i.isOpen; }
- (int)request:(MFLogiInterface *)i deviceIndex:(uint8_t)d feature:(uint8_t)f function:(uint8_t)fn params:(const uint8_t *)p length:(int)n {
    _requests++;
    if (_asleep) return -1;
    memset(i.responseBytes, 0, 20); i.responseLength = 20;
    if (!f) { i.responseBytes[4] = p[0] == 0x1B ? 9 : 10; return 0; }
    if (fn == 0) { i.responseBytes[4] = 3; return 0; }
    if (fn == 1) {
        const uint16_t cids[] = {0xD0,0xC4,0x53}; uint16_t cid = cids[p[0]];
        i.responseBytes[4] = cid >> 8; i.responseBytes[5] = cid & 255; i.responseBytes[8] = 0x20;
        return 0;
    }
    uint16_t cid = (uint16_t)(p[0] << 8 | p[1]);
    i.responseBytes[4] = p[0]; i.responseBytes[5] = p[1];
    if (fn == 2) { if (_shortReportingReply) i.responseLength = 7; i.responseBytes[6] = [_reporting[@(cid)] unsignedCharValue]; return 0; }
    assert(fn == 3 && n == 5 && (p[2] == 2 || p[2] == 3));
    _writes++; _reporting[@(cid)] = @(([_reporting[@(cid)] unsignedCharValue] & ~1) | (p[2] & 1)); i.responseBytes[6] = p[2];
    if (_loseWriteReply && (p[2] & 1)) return -1; // firmware accepted it, reply was lost
    return 0;
}
- (void)postCID:(NSNumber *)cid down:(BOOL)down target:(MFLogiTarget *)t {
    [_edges addObject:[NSString stringWithFormat:@"%@:%d", cid, down]];
}
- (void)closeInterface:(MFLogiInterface *)i { i.isOpen = NO; }
@end
static MFLogiInterface *interface(FakeDiverter *d) {
    d.modeShiftRequested = _modeShiftRequestedAtStartup;
    MFLogiInterface *i = [MFLogiInterface new]; i.isOpen = YES;
    MFLogiTarget *t = [MFLogiTarget new]; t.deviceIndex = 0xFF;
    [i.targets addObject:t]; [d.interfaces addObject:i]; return i;
}
// Exercise production deferral with the real CF run loop, without HID or IPC.
static BOOL configReady, startupObserved;
@interface StartupOrderDiverter : LogitechButtonDiverter @end
@implementation StartupOrderDiverter
+ (void)load_Manual { assert(configReady); startupObserved = YES; }
@end
static void keepLoopAlive(void *info) {}
int main(void) { @autoreleasepool {
    CFRunLoopSourceContext context = {0}; context.perform = keepLoopAlive;
    CFRunLoopSourceRef source = CFRunLoopSourceCreate(NULL, 0, &context);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopDefaultMode);
    [StartupOrderDiverter scheduleStartOnRunLoop:CFRunLoopGetCurrent()];
    assert(!startupObserved); // DeviceManager must not read policy before Config.
    configReady = YES;        // Config.load_Manual completes before loop starts.
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.001, false);
    assert(startupObserved);
    CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, kCFRunLoopDefaultMode);
    CFRelease(source);

    postButtonEvent(6, YES, 1234);
    assert(CGEventGetType(captured) == kCGEventOtherMouseDown);
    assert(CGEventGetIntegerValueField(captured, kCGMouseEventButtonNumber) == 5);
    assert(CGEventGetIntegerValueField(captured, kCGMouseEventPressure) == 1);
    assert(CGEventGetIntegerValueField(captured, (CGEventField)87) == 1234);
    postButtonEvent(7, NO, 5678);
    assert(CGEventGetType(captured) == kCGEventOtherMouseUp);
    assert(CGEventGetIntegerValueField(captured, kCGMouseEventButtonNumber) == 6);
    assert(CGEventGetIntegerValueField(captured, kCGMouseEventPressure) == 0);
    CFRelease(captured); captured = NULL;
    _modeShiftRequestedAtStartup = YES;
    FakeDiverter *d = [FakeDiverter new]; MFLogiInterface *i = interface(d); MFLogiTarget *t = i.targets[0];
    [d activateTarget:t on:i quietly:YES];
    assert(t.buttonForCID.count == 2 && [d.reporting[@0xD0] boolValue] && [d.reporting[@0xC4] boolValue]);
    assert(d.reporting[@0x53] == nil); // native Back is untouched
    uint8_t r[20] = {0x11,0xFF,9,0,0,0xD0,0,0xC4};
    [d handleDivertedButtons:r length:20 target:t]; assert(d.edges.count == 2 && t.pressedMask == 3);
    [d handleDivertedButtons:r length:20 target:t]; assert(d.edges.count == 2);
    [d handleDivertedButtons:r length:6 target:t]; assert(d.edges.count == 2 && t.pressedMask == 3);
    d.reporting[@0xC4] = @NO; // only the SECOND CID lost diversion
    [d verifyAll:NO]; assert([d.reporting[@0xC4] boolValue] && t.pressedMask == 0 && d.edges.count == 4);
    d.asleep = YES; [d handleDivertedButtons:r length:20 target:t]; [d verifyAll:NO]; assert(t.pressedMask == 0);
    d.asleep = NO; [d verifyAll:YES]; assert(t.buttonForCID.count == 2);
    d.stopped = YES; [d restoreAllOnWorker];
    assert(![d.reporting[@0xD0] boolValue] && ![d.reporting[@0xC4] boolValue] && !i.isOpen);
    int writes = d.writes; [d verifyAll:YES]; [d activateTarget:t on:i quietly:YES]; assert(d.writes == writes);
    [d restoreAllOnWorker]; assert(d.writes == writes); // idempotent shutdown
    FakeDiverter *other = [FakeDiverter new]; i = interface(other); t = i.targets[0];
    other.reporting[@0xD0] = @YES; [other activateTarget:t on:i quietly:YES];
    assert(t.buttonForCID[@0xD0] == nil); [other restoreAllOnWorker]; assert([other.reporting[@0xD0] boolValue]);
    FakeDiverter *lost = [FakeDiverter new]; i = interface(lost); t = i.targets[0]; lost.loseWriteReply = YES;
    [lost activateTarget:t on:i quietly:YES]; assert(t.buttonForCID.count == 0);
    assert(![lost.reporting[@0xD0] boolValue] && ![lost.reporting[@0xC4] boolValue]);
    [lost restoreAllOnWorker]; // lost ack did not orphan ownership
    FakeDiverter *sleeping = [FakeDiverter new]; i = interface(sleeping); t = i.targets[0]; sleeping.asleep = YES;
    [sleeping activateTarget:t on:i quietly:YES]; assert(t.reprogFeatureIndex == 0);
    sleeping.asleep = NO; [sleeping verifyAll:NO]; assert(t.buttonForCID.count == 2);
    _modeShiftRequestedAtStartup = NO; FakeDiverter *native = [FakeDiverter new]; i = interface(native); t = i.targets[0];
    [native activateTarget:t on:i quietly:YES]; assert(t.buttonForCID.count == 1 && native.reporting[@0xC4] == nil);
    // Effective binding lifecycle, including modifier-only and Add-mode maps.
    _modeShiftRequestedAtStartup = NO;
    FakeDiverter *dynamic = [FakeDiverter new]; i = interface(dynamic); t = i.targets[0];
    dynamic.reporting[@0xC4] = @0x10; // preserve unrelated reporting bits exactly
    [dynamic activateTarget:t on:i quietly:YES];
    assert(t.buttonForCID[@0xD0] && !t.buttonForCID[@0xC4]);
    _shared = dynamic;
    NSDictionary *bound = @{@{}: @{@7: @{@1: @{@"click": @[@{@"type": @"test"}]}}}};
    [LogitechButtonDiverter updateRemaps:bound];
    assert([dynamic.reporting[@0xC4] intValue] == 0x11 && t.buttonForCID[@0xC4]);
    int beforeReload = dynamic.writes;
    [LogitechButtonDiverter updateRemaps:bound]; // equal config reload is idempotent
    assert(dynamic.writes == beforeReload);
    t.pressedMask = 3;
    [LogitechButtonDiverter updateRemaps:@{}]; // delete binding / cancel Add mode
    assert([dynamic.reporting[@0xC4] intValue] == 0x10 && !t.buttonForCID[@0xC4]);
    assert(t.pressedMask == 1 && t.buttonForCID[@0xD0]); // Gesture hold preserved
    NSDictionary *modifier = @{@{@"buttonModifiers": @[@{@"button": @7, @"clickLevel": @1}]}: @{@"drag": @{@"type": @"test"}}};
    [LogitechButtonDiverter updateRemaps:modifier]; assert(t.buttonForCID[@0xC4]);
    [LogitechButtonDiverter updateRemaps:@{}]; assert(!t.buttonForCID[@0xC4]);
    [LogitechButtonDiverter updateRemaps:bound]; // temporary Add mode uses same effective button keys
    [LogitechButtonDiverter updateRemaps:@{}]; // leave without selecting an action
    assert([dynamic.reporting[@0xC4] intValue] == 0x10);
    [LogitechButtonDiverter updateRemaps:bound]; // add mode -> saved binding
    [LogitechButtonDiverter updateRemaps:bound]; assert(t.buttonForCID[@0xC4]);
    dynamic.stopped = YES; [dynamic restoreAllOnWorker]; // disable / normal quit
    assert([dynamic.reporting[@0xC4] intValue] == 0x10 && ![dynamic.reporting[@0xD0] boolValue]);
    int stoppedWrites = dynamic.writes;
    [LogitechButtonDiverter updateRemaps:bound]; assert(dynamic.writes == stoppedWrites);
    FakeDiverter *reenabled = [FakeDiverter new]; i = interface(reenabled); t = i.targets[0];
    [reenabled activateTarget:t on:i quietly:YES]; assert(t.buttonForCID[@0xC4]); // enable restores saved binding
    _shared = reenabled;
    reenabled.reporting[@0xC4] = @0x11; // another client changed our owned mode
    [LogitechButtonDiverter updateRemaps:@{}];
    assert([reenabled.reporting[@0xC4] intValue] == 0x11 && !t.buttonForCID[@0xC4]);
    FakeDiverter *foreignMode = [FakeDiverter new]; i = interface(foreignMode); t = i.targets[0];
    foreignMode.reporting[@0xC4] = @0x11; _shared = foreignMode;
    [LogitechButtonDiverter updateRemaps:bound];
    [foreignMode activateTarget:t on:i quietly:YES]; assert(!t.buttonForCID[@0xC4]);
    [LogitechButtonDiverter updateRemaps:@{}]; assert([foreignMode.reporting[@0xC4] intValue] == 0x11);
    FakeDiverter *shortReply = [FakeDiverter new]; i = interface(shortReply); t = i.targets[0];
    shortReply.shortReportingReply = YES;
    [shortReply activateTarget:t on:i quietly:YES];
    assert(t.buttonForCID.count == 0 && shortReply.writes == 0); // remap bytes must be present
    // A password field must pause transport without discarding an owned lease.
    FakeDiverter *secure = [FakeDiverter new]; i = interface(secure); t = i.targets[0];
    secure.modeShiftRequested = YES;
    [secure activateTarget:t on:i quietly:YES];
    NSData *originalMode = t.originalReporting[@0xC4];
    t.pressedMask = 3; secure.protectedInput = YES;
    int blockedRequests = secure.requests, blockedWrites = secure.writes;
    NSUInteger blockedEdges = secure.edges.count;
    [secure verifyAll:NO];
    assert(secure.requests == blockedRequests && secure.writes == blockedWrites);
    assert(t.buttonForCID.count == 2 && [t.originalReporting[@0xC4] isEqual:originalMode]);
    assert(t.pressedMask == 0 && t.pendingReleaseMask == 3 && secure.edges.count == blockedEdges);
    // No notification is delivered during pause.
    [secure handleDivertedButtons:r length:20 target:t]; assert(secure.edges.count == blockedEdges);
    // Delete Button7 binding while blocked: restoration must wait, not lose ownership.
    secure.modeShiftRequested = NO;
    [secure reconcileTarget:t on:i];
    assert(secure.requests == blockedRequests && t.buttonForCID[@0xC4]);
    secure.protectedInput = NO; i.accessDenied = YES; secure.failOpen = YES;
    [secure verifyAll:NO];
    assert(!i.isOpen && t.buttonForCID.count == 2); // failed reopen preserves claims
    secure.failOpen = NO;
    [secure verifyAll:NO];
    assert(i.isOpen && t.buttonForCID[@0xD0] && !t.buttonForCID[@0xC4]);
    assert(![secure.reporting[@0xC4] boolValue]); // native mode restored after exit
    assert(secure.opens == 2);
    // Same registry entry can recover our own claims; another entry cannot.
    i.registryID = 123; [secure rememberOwnership:i];
    MFLogiInterface *same = [MFLogiInterface new]; same.registryID = 123;
    [secure recoverOwnership:same]; assert(same.targets.firstObject == t && !t.deliveryReady);
    NSUInteger beforeValidation = secure.edges.count;
    [secure handleDivertedButtons:r length:20 target:t]; assert(secure.edges.count == beforeValidation);
    MFLogiInterface *different = [MFLogiInterface new]; different.registryID = 124;
    [secure recoverOwnership:different]; assert(different.targets.count == 0);
    // Reopening may reveal another client's reporting state: relinquish without writes.
    secure.reporting[@0xD0] = @0x11; int foreignWrites = secure.writes;
    [secure verifyAll:NO]; assert(!t.buttonForCID[@0xD0] && secure.writes == foreignWrites);
    _shared = nil;
    puts("PASS: protected input pauses HID and event delivery; owned claims survive failed reopen; same-registry recovery validates before delivery; different registry and foreign reporting never adopted");
    puts("PASS: production activation, ownership, lost ACK rollback, recovery, cleanup; dynamic Button7 add/remove/reload, Add-mode cancel, modifier binding, disable/quit/re-enable, exact reporting preservation and foreign diversion");
} }
