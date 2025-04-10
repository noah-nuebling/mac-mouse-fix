//
// --------------------------------------------------------------------------
// UNIXSignals.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "UNIXSignals_Old.h"
#import <signal.h>
#import "DeviceManager.h"

@implementation UNIXSignals_Old


+ (void)load_Manual {
    
    /// Setup termination handler
    ///     Notes:
    ///     - `SA_RESTART` flag auto-restarts certain system calls such as file reads after the signal handler returns. Otherwise those might calls return an error and we have to restart them manually.
    ///     - `SA_SIGINFO` flag makes the system pass additional info into the signal handler.
    ///     - `sigemptyset()` initializes the signal mask to empty. (If the signal mask contains signal codes, those signals will be deferred until after the signal handler returns afaik. Otherwise signals can interrupt the signal handler.)
    ///     - We're not setting up the handler for stop signals such as `SIGSTOP` - Those merely temporarily pause the program, instead of terminating it.
    ///
    ///     Discussion:
    ///     - The reason we're doing this is that `-[AppDelegate applicationWillTerminate:]` is not called when the Helper is terminated through `launchd` (which happens when the "Enable Mac Mouse Fix" toggle in the UI is switched off)
    ///          - Handling`SIGTERM` is the only way I'm aware of to do cleanup before the helper is terminated by `launchd`.
    
    int termination_signals[] = { /// See `man signal` for explanations of the signals
        SIGHUP,
        SIGINT,
        SIGQUIT,
        SIGILL,
        SIGTRAP,
        SIGABRT,
        SIGEMT,
        SIGFPE,
        //SIGKILL, <- SIGKILL can't be caught by a signal handler. See `man sigaction`.
        SIGBUS,
        SIGSEGV,
        SIGSYS,
        SIGPIPE,
        SIGALRM,
        SIGTERM,
        SIGXCPU,
        SIGXFSZ,
        SIGVTALRM,
        SIGPROF,
    };
    int termination_signal_count = sizeof termination_signals / sizeof termination_signals[0];
    
    for (int i = 0; i < termination_signal_count; i++) {
        
        /// Construct args for sigaction
        struct sigaction old_action;
        struct sigaction new_action = {
            .sa_sigaction = termination_signal_handler,
            .sa_flags = SA_SIGINFO | SA_RESTART,
            .sa_mask = 0,
        };
        
        /// Add the signal to the block-list of its handler
        ///     That way, the signal can't interrupt the handler. I think this is necessary to avoid race-conditions when we restore the default action from withing the handler.
        sigemptyset(&new_action.sa_mask);
        sigaddset(&new_action.sa_mask, termination_signals[i]);
        
        /// Install the new handler for all termination signals.
        int rt = sigaction(termination_signals[i], &new_action, &old_action);
        if (rt == -1) {
            perror("Accessibility Check - Error setting up sigterm handler. "); /// perror prints out the `errno` global var, which sigaction sets to the error code. || Can't use CocoaLumberjack here, since it's not set up, yet
            assert(false);
        }
        /// Validate: no previous signal handler installed
        ///     Previously we thought that `NSApplicationMain(argc, argv)` (found in main.m) sets up its own SIGTERM handler which we're overriding here, but this validates that that's not true.
        bool signal_handler_did_exist = (old_action.sa_handler != SIG_DFL) && (old_action.sa_handler != SIG_IGN);
        assert(!signal_handler_did_exist);
    }
}

static void termination_signal_handler(int signal_number, siginfo_t *signal_info, void *context) {
    
    /// Handle Unix termination signals
        
    /// Notes:
    ///     - The SIGKILL termination signal cannot be caught says ChatGPT
    ///     - The signalHandler can run on any thread says ChatGPT
    ///     - I think when the helper crashes, that sends a 'SIGSEGV' signal which we can also catch here. (This seems to happen somewhat regularly under MMF 3.0.3.)
    ///         But either way, launchd should immediately restart the helper so we don't need to 'clean up' after the helper crashes anyways. (Maybe we should explicitly not do the cleanup after receiving a crash-signal like SIGSEGV?)
    ///
    /// How to debug:
    ///     - When LLDB is attached, signal handlers are usually not called. Run this in lldb to enable our signal hander to run:
    ///         `process handle SIGTERM --pass true --stop false`
    
    /// Deconfigure
    ///     Discussion:
    ///     - **This is not async-signal-safe!**
    ///         - See `man sigaction` for list of async-signal-safe function (very small list)
    ///         - async-signal-safe explanation in this [linux man page](https://man7.org/linux/man-pages/man7/signal-safety.7.html)
    ///         - The entire objc and swift runtimes are not async signal safe, and you should use a dispatch source instead of a signal handler according to Quinn "The Eskimo": https://forums.developer.apple.com/forums/thread/746610
    ///     - Sep 2024: Right now, this resets tweaks to the IOKitDriver. Later, this might also reset the onboard memory of the attached mice.
    ///         -> We tweak Apple's mouse IOKitDriver to adjust the pointer acceleration curve, we plan to at some point tweak the onboard memory to make buttons behave properly on Logitech mice.
    ///     - If we can't reliably "deconfigure" before exiting (e.g. because we sometimes receive SIGKILL and SIGSTOP, which we can't catch),
    ///         we might wanna - instead of trying to automaticallly deconfigure - make it apparent to MMF users when they are permanently changing the configuration [of their mouse hardware or the IOKit driver (IOKitDriver configuration is not really permanent though - only lasts until computer restart)]
    [DeviceManager deconfigureDevices];
    
    /// Restore default action of the signal
    ///     Notes:
    ///     - `sigaction()` and `sigemptyset()` are async-signal-safe, so this should be safe to do.
    struct sigaction action = {
        .sa_handler = SIG_DFL,
        .sa_flags = 0,
        .sa_mask = 0,
    };
    sigemptyset(&action.sa_mask);
    int ret = sigaction(signal_number, &action, NULL);
    if (ret == -1) {
        /// We used to use here: `perror("sigaction() returned error while trying to restore default action inside the termination_signal_handler.");`
        ///     -> But it's not async-signal-safe
        ///         (Might be able to use `write()` which is safe, but i don't care.)
        assert(false); /// assert() is not safe, but it's only for debug builds, so should be fine.
    }
    
    /// Re-send the signal to invoke the default action
    ///     (... which is terminating the process and stuff.)
    ///     Notes:
    ///     - We could also use `kill(getpid(), signal_number)` to send the signal - not sure which is better.
    ///     - We could call `_exit(0)`  (not `exit(0)` since that's not async-signal-safe), to terminate the process. But that might not behave exactly like the default action, e.g. SIGSEGV creates a 'core image' (debug crash report stuff afaik.)
    ///     - `kill()` and `raise()` are **async-signal-safe**.
    ///         - However, I think if a this handler is interrupted between the `sigaction()` and the `raise()` calls, and inside the interrupt,
    ///             the signal_handler is overriden by another call to `sigaction()` - that could still be a race-condition - since `raise()` might not trigger the handler we installed through `sigaction()`
    ///             I think we can avoid this issue by blocking interrupts from signal x interrupting the handler for signal x.
    ///             -> We do that with the `sigaddset()` call where we install the signal handers (as of 28.09.2024)
    ///                 Alternatively, we could use `pthread_sigmask()` to temporarily block interrupts right inside this handler function.
    ret = raise(signal_number);
    if (ret == -1) {
        /// We used to use here: `perror("raise() returned an error inside the termination_signal_handler.");`
        ///     -> But it's not async-signal-safe
        assert(false);
    }
}


@end
