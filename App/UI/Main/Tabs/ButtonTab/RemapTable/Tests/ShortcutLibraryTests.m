//
// --------------------------------------------------------------------------
// ShortcutLibraryTests.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// Checks the data in ShortcutLibrary.m.
///     Run with `./run_tests.sh`. It compiles the real ShortcutLibrary.m. Not part of the Xcode project.
///     Checks: every entry (and every layout variant) has valid steps, no label looks destructive, and a single-key entry creates
///     exactly the effect dict that recording the shortcut in the table creates (`type`, `keycode`, `flags`).

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "Constants.h"
#import "ShortcutLibrary.h"

@interface ShortcutLibrary (Tests)
+ (NSArray *)apps;
+ (BOOL)stepsAreValid:(NSArray *)steps;
+ (NSArray *)effectsMenuEntriesForBundleID:(NSString *)bundleID layout:(NSString *)layout;
@end

int main(void) { @autoreleasepool {
    
    int failures = 0;
    NSUInteger nOfEntries = 0;
    NSRegularExpression *destructive = [NSRegularExpression regularExpressionWithPattern:@"\\b(delete|erase|quit|log ?out|sign ?out|force|empty trash|purchase|unsubscribe|uninstall)\\b" options:NSRegularExpressionCaseInsensitive error:nil];
    
    for (NSDictionary *app in [ShortcutLibrary apps]) {
        
        NSArray *bundleIDs = app[@"bundleIDs"];
        if (bundleIDs.count == 0) { failures++; printf("FAIL: %s has no bundle ID\n", [app[@"name"] UTF8String]); }
        
        for (NSDictionary *entry in app[@"entries"]) {
            nOfEntries++;
            NSString *label = entry[@"label"];
            if (![ShortcutLibrary stepsAreValid:entry[@"steps"]]) { failures++; printf("FAIL: invalid steps: %s\n", label.UTF8String); }
            for (NSString *layout in entry[@"variants"]) {
                if (![ShortcutLibrary stepsAreValid:entry[@"variants"][layout]]) { failures++; printf("FAIL: invalid %s steps: %s\n", layout.UTF8String, label.UTF8String); }
            }
            if ([destructive firstMatchInString:label options:0 range:NSMakeRange(0, label.length)]) { failures++; printf("FAIL: destructive label: %s\n", label.UTF8String); }
        }
        
        /// Every entry for the US layout makes it into the effect menu (nothing is dropped by the validation in `effectsMenuEntriesForBundleID:layout:`)
        NSUInteger nForUS = 0;
        for (NSDictionary *entry in app[@"entries"]) {
            if (!entry[@"layouts"] || [entry[@"layouts"] containsObject:@"us"]) nForUS++;
        }
        NSArray *menuEntries = [ShortcutLibrary effectsMenuEntriesForBundleID:bundleIDs.firstObject layout:@"us"];
        if (menuEntries.count != nForUS) { failures++; printf("FAIL: %s: %lu menu entries for %lu library entries\n", [app[@"name"] UTF8String], menuEntries.count, nForUS); }
        
        /// Single keys create the same effect dict as recording a shortcut
        for (NSDictionary *menuEntry in menuEntries) {
            NSDictionary *effect = menuEntry[@"dict"];
            if (![effect[kMFActionDictKeyType] isEqual:kMFActionDictTypeKeyboardShortcut]) continue;
            NSSet *keys = [NSSet setWithArray:effect.allKeys];
            NSSet *expected = [NSSet setWithArray:@[kMFActionDictKeyType, kMFActionDictKeyKeyboardShortcutVariantKeycode, kMFActionDictKeyKeyboardShortcutVariantModifierFlags]];
            if (![keys isEqual:expected]) { failures++; printf("FAIL: unexpected effect keys: %s\n", [menuEntry[@"ui"] UTF8String]); }
        }
    }
    
    if ([ShortcutLibrary effectsMenuEntriesForBundleID:@"com.example.not-in-library"].count != 0) { failures++; printf("FAIL: entries for an unknown app\n"); }
    
    /// The validation rejects what the helper rejects
    if ([ShortcutLibrary stepsAreValid:@[@[@128, @0]]]) { failures++; printf("FAIL: key code 128 accepted\n"); }
    if ([ShortcutLibrary stepsAreValid:@[@[@0, @(kCGEventFlagMaskSecondaryFn)]]]) { failures++; printf("FAIL: fn flag accepted\n"); }
    if ([ShortcutLibrary stepsAreValid:@[]]) { failures++; printf("FAIL: empty steps accepted\n"); }
    if (![ShortcutLibrary stepsAreValid:@[@[@46, @(kCGEventFlagMaskCommand | kCGEventFlagMaskShift)]]]) { failures++; printf("FAIL: Cmd-Shift-M rejected\n"); }

    /// Entries with `layouts` are left out on the other layouts. "Create new terminal" is US-only: on German and Austrian keyboards VS Code has no default for it.
    for (NSString *layout in @[@"us", @"de", @"at"]) {
        NSArray *menuEntries = [ShortcutLibrary effectsMenuEntriesForBundleID:@"com.microsoft.VSCode" layout:layout];
        BOOL hasTerminal = NO;
        for (NSDictionary *menuEntry in menuEntries) { if ([menuEntry[@"ui"] isEqualToString:@"Create new terminal"]) hasTerminal = YES; }
        BOOL shouldHave = [layout isEqualToString:@"us"];
        if (hasTerminal != shouldHave) { failures++; printf("FAIL: Create new terminal on %s: %s\n", layout.UTF8String, hasTerminal ? "shown" : "missing"); }
    }

    /// `layouts`, when present, is an array
    for (NSDictionary *app in [ShortcutLibrary apps]) {
        for (NSDictionary *entry in app[@"entries"]) {
            if (entry[@"layouts"] && ![entry[@"layouts"] isKindOfClass:NSArray.class]) { failures++; printf("FAIL: layouts is not an array: %s\n", [entry[@"label"] UTF8String]); }
        }
    }

    printf("%lu apps, %lu entries, %d failures\n", (unsigned long)[ShortcutLibrary apps].count, (unsigned long)nOfEntries, failures);
    return failures ? 1 : 0;
}}
