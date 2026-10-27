//
// --------------------------------------------------------------------------
// RemapSwizzlerTests.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// Checks how RemapSwizzler combines global and app-specific remaps.
///     Run with `./run_tests.sh`. It compiles the real RemapSwizzler.m against the stubs in `Stubs/`. Not part of the Xcode project.

#import <Foundation/Foundation.h>
#import "Constants.h"
#import "RemapSwizzler.h"

static int failures = 0, checks = 0;
#define CHECK(cond, name) do { checks++; if (!(cond)) { failures++; printf("FAIL: %s\n", name); } else { printf("ok:   %s\n", name); } } while (0)

static NSDictionary *btn(int b, NSString *effect) { return @{ @(b): @{ @1: @{ kMFButtonTriggerDurationClick: @[ @{ @"name": effect } ] } } }; }
static NSString *effectFor(NSDictionary *mods, int b) { return mods[@(b)][@1][kMFButtonTriggerDurationClick][0][@"name"]; }
static NSDictionary *merge(NSDictionary *a, NSDictionary *b) { NSMutableDictionary *m = a.mutableCopy; [m addEntriesFromDictionary:b]; return m; }
static NSArray *buttonMods(int b) { return @[ @{ kMFButtonModificationPreconditionKeyButtonNumber: @(b), kMFButtonModificationPreconditionKeyClickLevel: @1 } ]; }

int main(void) { @autoreleasepool {
    NSString *C = @"com.google.Chrome";
    NSDictionary *appC = @{ kMFModificationPreconditionKeyApp: C };

    /// 1. Global only: same as upstream
    NSDictionary *r1 = @{ @{}: merge(btn(4, @"A"), btn(5, @"G")),
                          @{ kMFModificationPreconditionKeyKeyboard: @(kCGEventFlagMaskCommand) }: btn(4, @"X") };
    NSDictionary *m = [RemapSwizzler swizzleRemaps:r1 activeModifiers:@{}];
    CHECK([effectFor(m, 4) isEqual:@"A"] && [effectFor(m, 5) isEqual:@"G"], "global only, no modifiers");
    m = [RemapSwizzler swizzleRemaps:r1 activeModifiers:@{ kMFModificationPreconditionKeyKeyboard: @(kCGEventFlagMaskCommand) }];
    CHECK([effectFor(m, 4) isEqual:@"X"] && effectFor(m, 5) == nil, "global only, Cmd row wins and disables plain rows (upstream rule)");

    /// 2. App row wins only while its app is active
    NSDictionary *r2 = @{ @{}: merge(btn(4, @"A"), btn(5, @"G")), appC: btn(4, @"B") };
    m = [RemapSwizzler swizzleRemaps:r2 activeModifiers:appC];
    CHECK([effectFor(m, 4) isEqual:@"B"], "app active: app row beats global row on the same button");
    CHECK([effectFor(m, 5) isEqual:@"G"], "app active: other global rows still apply");
    m = [RemapSwizzler swizzleRemaps:r2 activeModifiers:@{}];
    CHECK([effectFor(m, 4) isEqual:@"A"], "no app active: global row");
    m = [RemapSwizzler swizzleRemaps:r2 activeModifiers:@{ kMFModificationPreconditionKeyApp: @"com.apple.Safari" }];
    CHECK([effectFor(m, 4) isEqual:@"A"], "other app active: global row");

    /// 3. App plain row vs global chord: app wins (documented precedence)
    NSDictionary *r3 = @{ @{}: btn(4, @"A"), @{ kMFModificationPreconditionKeyButtons: buttonMods(3) }: btn(4, @"X"), appC: btn(4, @"B") };
    m = [RemapSwizzler swizzleRemaps:r3 activeModifiers:merge(appC, @{ kMFModificationPreconditionKeyButtons: buttonMods(3) })];
    CHECK([effectFor(m, 4) isEqual:@"B"], "app plain row beats a more specific global chord");
    m = [RemapSwizzler swizzleRemaps:r3 activeModifiers:@{ kMFModificationPreconditionKeyButtons: buttonMods(3) }];
    CHECK([effectFor(m, 4) isEqual:@"X"], "outside the app, the global chord applies");

    /// 4. Within the app, the upstream subset rule applies
    NSDictionary *appCmd = merge(appC, @{ kMFModificationPreconditionKeyKeyboard: @(kCGEventFlagMaskCommand) });
    NSDictionary *r4 = @{ @{}: btn(5, @"G"), appC: btn(4, @"B"), appCmd: btn(4, @"BC") };
    m = [RemapSwizzler swizzleRemaps:r4 activeModifiers:appCmd];
    CHECK([effectFor(m, 4) isEqual:@"BC"], "app Cmd row beats app plain row");
    CHECK([effectFor(m, 5) isEqual:@"G"], "global plain row is not disabled by an app Cmd row (layers filter separately)");

    /// 5. Drag and scroll
    NSDictionary *b3 = @{ kMFModificationPreconditionKeyButtons: buttonMods(3) };
    NSDictionary *r5 = @{ b3: @{ kMFTriggerDrag: @{ @"name": @"D1" } }, merge(appC, b3): @{ kMFTriggerDrag: @{ @"name": @"D2" } },
                          @{ kMFModificationPreconditionKeyKeyboard: @(kCGEventFlagMaskAlternate) }: @{ kMFTriggerScroll: @{ @"name": @"S1" } } };
    m = [RemapSwizzler swizzleRemaps:r5 activeModifiers:merge(appC, b3)];
    CHECK([m[kMFTriggerDrag][@"name"] isEqual:@"D2"], "app drag beats global drag");
    m = [RemapSwizzler swizzleRemaps:r5 activeModifiers:b3];
    CHECK([m[kMFTriggerDrag][@"name"] isEqual:@"D1"], "global drag outside the app");
    m = [RemapSwizzler swizzleRemaps:r5 activeModifiers:merge(appC, @{ kMFModificationPreconditionKeyKeyboard: @(kCGEventFlagMaskAlternate) })];
    CHECK([m[kMFTriggerScroll][@"name"] isEqual:@"S1"], "global scroll modifier still works inside the app");

    /// 6. Non-string app values don't crash
    NSDictionary *r6 = @{ @{}: btn(4, @"A"), @{ kMFModificationPreconditionKeyApp: @42 }: btn(4, @"N") };
    m = [RemapSwizzler swizzleRemaps:r6 activeModifiers:appC];
    CHECK([effectFor(m, 4) isEqual:@"A"], "non-string app precond is ignored without crashing");

    printf("%d checks, %d failures\n", checks, failures);
    return failures ? 1 : 0;
}}
