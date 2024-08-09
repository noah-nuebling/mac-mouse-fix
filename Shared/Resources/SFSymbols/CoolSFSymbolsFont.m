//
// --------------------------------------------------------------------------
// CoolSFSymbolsFont.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "CoolSFSymbolsFont.h"
#import "Logging.h"
#import "NSString+Steganography.h"
#import "SharedUtility.h"
@import CoreText;
@import AppKit.NSFontDescriptor;
@import AppKit.NSFont;

///
/// This filer offers wrapper methods for interacting with the CoolSFSymbols.otf font which we ship in the Mac Mouse Fix bundle to display SFSymbols inside tooltips.
///
/// CoolSFSymbols.otf is created by a python script in this repo, and then (manually) added as a build file for the Mac Mouse Fix target in Xcode (that means the font file ends up in the bundle after building the app)
///
/// At runtime, methods from this file are called from 2 places: (at the time of writing)
///  - Inside AppDelegate.m, when the app launches or closes the CoolSFSymbols.otf font is registered/unregistered
///  - Inside UIStrings.m, before it returns a unicode character for an SF Symbol, it asks this file whether the unicode character can be displayed - to validate correctness (only happens for debug builds.)
///
/// Also see:
/// - Discussion on this GitHub pull request by @groverlynn, which motivated and informed the new approach where we ship CoolSFSymbols.otf with the app: https://github.com/noah-nuebling/mac-mouse-fix/pull/385
/// - The notes in the python script that generates CoolSFSymbols.otf - explains some more of the ideas and stuff.

@implementation CoolSFSymbolsFont

/// Constants
#define coolFontPostScriptName @"SFProText-Regular-WithLargeFry-AndExtraSauce" /// Keep this in sync with the python script!
#define coolFontURL() [NSBundle.mainBundle URLForResource:@"CoolSFSymbols" withExtension:@"otf"]

+ (BOOL)symbolCharacterIsDisplayable:(NSString *)characterString {
    
    /// Meant for debugging / validation. Maybe not fast. Don't use in production.
    
    if (!runningPreRelease()) {
        DDLogWarn(@"symbolCharacterIsSupported called in a release build. I'm not sure how fast it is and it was just created for debugging/validation purposes.");
        return true;
    }
    
    /// Validate
    ///     Note: NSString uses 16 bit chars, and SF Symbols - defined in the private unicode area 0x100000 - 0x10FFFF occupy two 16 bit chars.
    assert(characterString.length == 2);
    
    /// Extract unicode character
    UTF32Char utf32Character;
    BOOL success = [characterString getBytes:&utf32Character maxLength:sizeof(UTF32Char) usedLength:nil encoding:NSUTF32LittleEndianStringEncoding options:0 range:NSMakeRange(0, characterString.length) remainingRange:nil];
    
    /// Validate
    assert(success);
    
    /// Get characterSet for our custom font
    ///     Maybe we could cache this? But we'll deactivate this in production anyways (Don't forget!)
    NSFontDescriptor *fontDescriptor = [[NSFontDescriptor alloc] initWithFontAttributes:@{
        NSFontNameAttribute: coolFontPostScriptName,
    }];
    NSFont *font = [NSFont fontWithDescriptor:fontDescriptor size:13.0];
    CFCharacterSetRef characterSet = CTFontCopyCharacterSet((__bridge CTFontRef)font);
    
    /// Validated
    if (font == nil || characterSet == nil) {
        DDLogError(@"Could not get a character set for coolFont with postScriptName: %@. URL for coolFont: %@. Make sure the coolFont has the right postScript name. If not, use the python script to generate a new coolFont with the right postscript name.", coolFontPostScriptName, coolFontURL());
        assert(false);
        return false;
    }

    /// Check if the character is displayable by our coolFont
    Boolean result = CFCharacterSetIsLongCharacterMember(characterSet, utf32Character);
    
    /// Release
    CFRelease(characterSet);
    
    /// Return
    return result;
    
}
+ (void)uninstallFont {
    installFont(false);
}

+ (void)installFont {
    installFont(true);
}

static void installFont(Boolean doInstall) {
    
    if (@available(macOS 10.15, *)) {
        
        /// Set scope of fontRegistration
        ///     Scope "session" will install the font on the whole system, until the users logs out.
        ///     > It's a little bad that we're affecting the state of the whole login session just to render SF Symbols in our tooltips.
        ///     > We want the scope to be as small as possible, but when we use the "process" scope instead of "session", it doesn't work, and the SF Symbols still show up as 􀃬 in the tooltips. Not sure why. (Might be a bug, running macOS 15.0 Beta (24A5298h))
        ///     > We should make sure all the internal names and ids of our font are unique so that it doesn't conflict with the real SF Pro fonts (from which it is derived, and which can be downloaded from Apple.com)
        ///         > If we can thoroughly test that, this should be ok to use:
        ///         > DONE: Tested by calling installFont() with false and true interspersed with activating /deactivating SF Pro Text in FontBook. Everything works as expected for every order of operations that I could think of - no conflicts! (I did see conflicts before we introduced renaming of the font in the python script, after the font is split off from SF Pro)
        ///
        CTFontManagerScope fontRegistrationScope = kCTFontManagerScopeSession;
        
        /// Get fontURL
        NSURL *fontURL = coolFontURL();
        if (fontURL == nil) {
            DDLogWarn(@"CoolSFSymbols font not found at %@", fontURL);
            assert(false);
            return;
        }
        
        if (!doInstall) {
            
            /// Log
            DDLogInfo(@"UNInstalling CoolSFSymbols font at %@ for scope: %d", fontURL, fontRegistrationScope);
            
            /// Unregister font
            CTFontManagerUnregisterFontURLs((__bridge CFArrayRef)@[fontURL], fontRegistrationScope, ^bool (CFArrayRef  _Nonnull errors, bool done) {
                DDLogInfo(@"CoolSFSymbols font UNregistration callback: errors: %@ done: %d", (CFArrayGetCount(errors) > 0 ? (__bridge id)errors : @""), done); return true;
            });
            
        } else {
            
            /// Log
            DDLogInfo(@"Installing CoolSFSymbols font at %@ for scope: %d fontDescriptor: %@", fontURL, fontRegistrationScope, CFBridgingRelease(CTFontManagerCreateFontDescriptorsFromURL((__bridge CFURLRef)fontURL)));
            
            /// Unregister font
            ///     Not totally sure what we're doing that for. I gues uninstalling the old version if there is one.
            CTFontManagerUnregisterFontURLs((__bridge CFArrayRef)@[fontURL], fontRegistrationScope, ^bool (CFArrayRef  _Nonnull errors, bool done) {
                DDLogInfo(@"CoolSFSymbols font UNregistration callback: errors: %@ done: %d", (CFArrayGetCount(errors) > 0 ? (__bridge id)errors : @""), done); return true;
            });
            
            /// Register font
            CTFontManagerRegisterFontURLs((__bridge CFArrayRef)@[fontURL], fontRegistrationScope, true, ^bool (CFArrayRef  _Nonnull errors, bool done) {
                DDLogInfo(@"CoolSFSymbols font registration callback: errors: %@ done: %d", (CFArrayGetCount(errors) > 0 ? (__bridge id)errors : @""), done); return true;
            });
        }
    }
}

@end
