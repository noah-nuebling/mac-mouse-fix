//
// --------------------------------------------------------------------------
// WannabePrefixHeader.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

#ifndef WannabePrefixHeader_h
#define WannabePrefixHeader_h

/// I tried to use a prefix header but it didn't work for some reason. (see PrefixHeader.pch)
/// So now this is the place for stuff I want to import/define everywhere. (Since it's not a prefix header I'll also have to import this everywhere for that to work)
/// Remove this if you can ever get PrefixHeader.pch to work

///
/// Hide ObjC methods from Swfit
///
/// `NS_SWIFT_UNAVIALBLE("")` doesn't completely hide stuff and sometimes leads to bad behviour where the compiler warnings don't tell you what's actually wrong.` NS_REFINED_FOR_SWIFT` is not intended for this but it works better.

#define MF_SWIFT_HIDDEN NS_REFINED_FOR_SWIFT

///
/// Setup Cocoalumberjack
///

#define LOG_LEVEL_DEF ddLogLevel
@import CocoaLumberjack;
//#import <CocoaLumberjack/CocoaLumberjack.h>

/// Set default CocoaLumberjack loglevel for the project (can be overriden)
///  More on loglevels here: https://github.com/CocoaLumberjack/CocoaLumberjack/blob/master/Documentation/GettingStarted.md
///      General note on my use of CocoaLumberjack: I plan on not using the verbose channel for logging at all because it doesn't make sense for me to differentiate it from the debug channel. I probably won't use Error and Warn either because it's too much work to migrate all my old NSLog Statements into all these different categories. So I'll just use Info and Debug channels. At least for now.
///      And therefore the only interesting log _levels_ are also Info and Debug
///      Edit: I've since started using Error and Warn in some places.



#if DEBUG
static DDLogLevel ddLogLevel = DDLogLevelDebug; /// These definitions might make more sense in Constants.h
#else
static DDLogLevel ddLogLevel = DDLogLevelInfo;
//static DDLogLevel ddLogLevel = DDLogLevelOff; /// Override log level for testing
#endif

#endif /* WannabePrefixHeader_h */
