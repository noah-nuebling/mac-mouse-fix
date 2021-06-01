//
// --------------------------------------------------------------------------
// WannabePrefixHeader.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#ifndef WannabePrefixHeader_h
#define WannabePrefixHeader_h

// I tried to use a prefix header but it didn't work for some reason. (see PrefixHeader.pch)
// So now this is the place for stuff I want to import/define everywhere. (Since it's not a prefix header I'll also have to import this everywhere)
// Remove this if you can ever get PrefixHeader.pch to work

// Setup Cocoalumberjack

#define LOG_LEVEL_DEF ddLogLevel
#import <CocoaLumberjack/CocoaLumberjack.h>

// Set default CocoaLumberjack loglevel for the project (can be overriden)
//  More on loglevels here: https://github.com/CocoaLumberjack/CocoaLumberjack/blob/master/Documentation/GettingStarted.md
//      General note on my use of CocoaLumberjack: I plan on not using the verbose channel for logging at all because it doesn't make sense for me to differentiate it from the debug channel. I probably won't use Error and Warn either because it's too much work to migrate all my old DDLogInfoStatements into all these different categories. So I'll just use Info and Debug channels. At least for now.
//      And therefore the only interesting log _levels_ are also Info and Debug

#if DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelDebug;
#else
static const DDLogLevel ddLogLevel = DDLogLevelInfo;
#endif

#endif /* WannabePrefixHeader_h */
