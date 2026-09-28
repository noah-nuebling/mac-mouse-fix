//
// --------------------------------------------------------------------------
// UNIXSignals.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "UNIXSignals.h"
//#import <signal.h>
//#import "DeviceManager.h"

@implementation UNIXSignals

+ (void)load_Manual {
    
    /**
        Overview: [Sep 2026]
            Once we implement `[DeviceManager deconfigureDevices]` we'll want to run that whenever the helper quits.
            Catching the `SIGTERM``UNIXSignal` is the only way I'm aware of to get reliable callback before the helper quits.
                (`-[AppDelegate applicationWillTerminate:]` is not called when the "Mac Mouse Fix Helper" agent is terminated through `launchd` (which happens when the "Enable Mac Mouse Fix" toggle in the UI is switched off))

        Plan: [Sep 2026]. (Once `[DeviceManager deconfigureDevices]` does something) Opus 5.5 says to use kqueue's `EVFILT_SIGNAL` to deliver `SIGTERM` directly to `GlobalEventTapThread.runLoop`, from where we can then call `[DeviceManager deconfigureDevices]`

        History: [Sep 2026] Had old `dispatch_source_set_event_handler`-based implementation which we didn't actually use. Deleted [Sep 2026] as part of 'No more dispatch queues' refactor

        Old notes about `[DeviceManager deconfigureDevices]` and alternatives:
            ```
            /// Deconfigure Devices
            ///     Discussion:
            ///     - Sep 2024: Right now, this resets tweaks to the IOKitDriver. Later, this might also reset the onboard memory of the attached mice.
            ///         -> We tweak Apple's mouse IOKitDriver to adjust the pointer acceleration curve, we plan to at some point tweak the onboard memory to make buttons behave properly on Logitech mice.
            ///     - If we can't reliably "deconfigure" before exiting (e.g. because we sometimes receive SIGKILL and SIGSTOP, which we can't catch),
            ///         we might wanna - instead of trying to automaticallly deconfigure - make it apparent to MMF users when they are permanently changing the configuration [of their mouse hardware or the IOKit driver (IOKitDriver configuration is not really permanent though - only lasts until computer restart)]

            [DeviceManager deconfigureDevices];
            ```
    */
}

@end
