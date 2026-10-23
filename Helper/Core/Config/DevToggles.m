//
// --------------------------------------------------------------------------
// DevToggles.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2025
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

///
/// [May 2025] Interface for playing around with the app's behavior without recompiling
///     E.g. modifying animation curves
///
///     Update: [Jul 2025] We had the idea of just putting all the params into Config.plist again (like in older MMF versions) so we can play around with them by just editing config.plist. But in the short-term DevToggles.m should be useful.
///

#import "DevToggles.h"
#import "Logging.h"
#import <AppKit/NSEvent.h>
#import <Carbon/Carbon.h>
#import "Mac_Mouse_Fix_Helper-Swift.h"
#import "MFEventTap.h"

#pragma mark - State

double devToggles_C   = 0.85;
int    devToggles_Lo  = 160;
int    devToggles_Hi  = 6;

#pragma mark - Event listener

#define MF_TEST 0 /// Deactivate this before shipping the app!
#if MF_TEST

    @implementation NSObject (DevToggles_OnLoad)
        + (void) load {
            #define kListenerID @"DevToggles"
            [MFEventTap registerListener: kListenerID forEvents: kMFEventType_KeyPress callback: eventTapCallback context: NULL];
            [MFEventTap enable: true forListener: kListenerID];
        }
        void eventTapCallback(void *context, MFEventType eventType, CGEventRef *eventPtr) {
            
            #define evmatch(event, _type, vkc, modflags) (                                      \
                ((_type)    == type)                                                            && \
                ((modflags) == (CGEventGetFlags(event) & (modflags)))                           && \
                ((vkc)      == CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode))     )
            
            #define flg(x) (kCGEventFlagMask ## x)

            #define log(args...) DDLogDebug("DevToggles.m: " args);
 
            CGEventRef event = *eventPtr;
            CGEventType type = CGEventGetType(event);

            if ((1)) {
                
            
                bool is_up       = evmatch(event, kCGEventKeyDown, kVK_UpArrow,    flg(Command)|flg(Control)|flg(Alternate));
                bool is_down     = evmatch(event, kCGEventKeyDown, kVK_DownArrow,  flg(Command)|flg(Control)|flg(Alternate));
                bool is_left     = evmatch(event, kCGEventKeyDown, kVK_LeftArrow,  flg(Command)|flg(Control)|flg(Alternate));
                bool is_right    = evmatch(event, kCGEventKeyDown, kVK_RightArrow, flg(Command)|flg(Control)|flg(Alternate));
                bool is_anything = is_up || is_down || is_left || is_right;
                bool has_shift   = CGEventGetFlags(event) & flg(Shift);
                bool has_rctrl   = CGEventGetFlags(event) & NX_DEVICERCTLKEYMASK;
                
                int inc = has_rctrl ? 10 : 1;
                
                if (is_left)
                    devToggles_C += inc;
                else if (is_right)
                    devToggles_C -= inc;
                else if (is_down) {
                    if (!has_shift)  devToggles_Lo  -= inc;
                    else            devToggles_Hi  -= inc;
                }
                else if (is_up) {
                    if (!has_shift)  devToggles_Lo  += inc;
                    else            devToggles_Hi  += inc;
                }
                    
                if (is_anything) {
                    [ScrollConfig devToggles_deleteCache];
                    log("C: %.2f Lo: %d, Hi: %d", devToggles_C, devToggles_Lo, devToggles_Hi);
                    *eventPtr = NULL;
               }
            }
            
            #undef evmatch
            #undef flg
            #undef log
        };
    @end
#endif
