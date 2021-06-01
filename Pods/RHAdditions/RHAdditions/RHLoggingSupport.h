//
//  RHLoggingSupport.h
//
//  Created by Richard Heard on 3/07/12.
//  Copyright (c) 2012 Richard Heard. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions
//  are met:
//  1. Redistributions of source code must retain the above copyright
//  notice, this list of conditions and the following disclaimer.
//  2. Redistributions in binary form must reproduce the above copyright
//  notice, this list of conditions and the following disclaimer in the
//  documentation and/or other materials provided with the distribution.
//  3. The name of the author may not be used to endorse or promote products
//  derived from this software without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
//  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
//  OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
//  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
//  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
//  NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
//  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
//  THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// logging macros
//
// To enable logging by default for debug builds use:
// #define RH_LOGGING_ALWAYS (defined(DEBUG) && DEBUG)
//
// To disable logging permanently use:
// #define RH_LOGGING_NEVER 1
//
// Otherwise set RHLoggingEnabled to YES in NSUserDefaults to selectively enable logging. "defaults write <domain> RHLoggingEnabled -bool yes"

#import <Foundation/Foundation.h>

#if (defined(RH_LOGGING_NEVER) && RH_LOGGING_NEVER)
    #define RHLog(format, ...)
#else
    extern BOOL _RHLoggingEnabled;
    extern void _RHLoggingInit();
    
    #define RHLog(format, ...) do{ _RHLoggingInit(); if (__builtin_expect(_RHLoggingEnabled, _RHLoggingEnabled)) NSLog( @"%s:%i %@ ", __PRETTY_FUNCTION__, __LINE__, [NSString stringWithFormat: format, ##__VA_ARGS__]); } while(0)
#endif

#define RHErrorLog(format, ...) do{ NSLog( @"%s:%i %@ ", __PRETTY_FUNCTION__, __LINE__, [NSString stringWithFormat: format, ##__VA_ARGS__]); } while (0)

