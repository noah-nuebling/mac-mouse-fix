//
// --------------------------------------------------------------------------
// SymbolicHotKeys.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import "CGSHotKeys.h"
#import "MFDataClass.h"

MFDataClassInterface2(MFDataClassBase, MFVKCAndFlags, /// Belongs to `MFEmulateNSMenuItemRemapping()` [Aug 2025]
    readwrite, assign, , CGKeyCode, vkc,
    readwrite, assign, , CGEventFlags, modifierMask
)

/// Define MFKeyboardType stuff
///     TODO: (This is a dependency of searchVKCForStr) Delete this when copying over MFKeyboardSimulationData.h from EventLoggerForBrad
///         Update: [Aug 2025] Actually keep the `API_AVAILABLE` macOS availability guards for `MFKeyboardTypeCurrent()` when mergin with EventLoggerForBrad!
///     (Moved this into SymbolicHotKeys.h to make it available to Actions.m – pretty hacky! [Aug 2025])
#import <Carbon/Carbon.h>
typedef enum : CGEventSourceKeyboardType {
    kMFKeyboardTypeNull                                         = 0, /// The gestalt enum cases look like 0 is unused and can be used as NULL.
    kMFKeyboardTypeGenericANSI                                  = gestaltThirdPartyANSIKbd, /// In the 'Keyboard Setup Assistant', macOS lets me choose between, ANSI (40) , ISO (41), and JIS (42) for my 3rd party keyboard.
    kMFKeyboardTypeGenericISO                                   = gestaltThirdPartyISOKbd,
    kMFKeyboardTypeGenericJIS                                   = gestaltThirdPartyJISKbd,
    kMFKeyboardTypeM1MacBookAirANSI                             = 91, /// I see this value on my M1 MacBook Air with US Layout, not sure if it's also used for other keyboards.
    kMFKeyboardTypeMagicKeyboardwithTouchIDISO                  = 83, /// I see this on "Magic Keyboard with Touch ID" with German QWERTZ layout (wihout numpad). System settings shows it has 'version' 1.4.8.
} MFKeyboardType;
static inline MFKeyboardType MFKeyboardTypeCurrent(void) {
    API_AVAILABLE(macos(12.0)) extern MFKeyboardType SLSGetLastUsedKeyboardID(void); /// Not sure about sizeof(returnType). `LMGetKbdType()` is `UInt8`, but `CGEventSourceKeyboardType` is `uint32_t` - both seem to contain the same constants though.
    if (@available(macOS 12.0, *)) return SLSGetLastUsedKeyboardID(); /// [Aug 2025] Causes linker crashes on older macOS versions! Also – Not sure this has any advantages over `LMGetKbdType()`/`LMGetKbdLast()` – I started using this during EventLoggerForBrad development, but I don't remember why – maybe we should just abandon it?
    else                           return LMGetKbdType();               /// [Aug 2025] Should we use `LMGetKbdType()` or `LMGetKbdLast()`?
}

MFVKCAndFlags *_Nonnull MFEmulateNSMenuItemRemapping(CGKeyCode vkc, CGEventFlags modifierMask);

@interface SymbolicHotKeys : NSObject

+ (void) post: (CGSSymbolicHotKey)shk;

@end
