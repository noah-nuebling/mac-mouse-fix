//
// --------------------------------------------------------------------------
// UNIXSignals.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "UNIXSignals.h"
#import <signal.h>
#import "DeviceManager.h"
#import "Mac_Mouse_Fix_Helper-Swift.h"

static void termination_signal_handler(int theSignal);
static void restore_default_signal_action(int theSignal);

@implementation UNIXSignals

+ (void)load_Manual {
    if (NSProcessInfo.processInfo.environment[@"MMF_M720_UNIT_TESTING"] != nil) {
        return;
    }
    
    ///
    ///  Overview:
    ///     In this file, we install a cleanup routine that runs before the helper quits using UNIX Signals.
    ///     The simplest way to do termination-cleanup that I found is  `-[AppDelegate applicationWillTerminate:]`.
    ///     However, that is not called when the "Mac Mouse Fix Helper" agent is terminated through `launchd` (which happens when the "Enable Mac Mouse Fix" toggle in the UI is switched off)
    ///     Catching the `SIGTERM`UNIX Signal is the only way I'm aware of to do cleanup before the helper is terminated by `launchd`.
    ///
    /// On `Dispatch Source` and `sigaction()`
    ///     **sigaction()** is a more basic way to install UNIX Signals than using **Dispatch Source**. But it's very hard to use due to "async-signal-safety".
    ///      - See `UNIXSignals.m` in commit 3782cc18949fbd34cb6ef8aecde6d48523c5a8bc in the mmf repo for for an implementation using `sigaction()` handlers (which wasn't async-signal-safe.)
    ///      - See this post by Quinn "The Eskimo" for more info on sigaction() vs "Dispatch Source" https://forums.developer.apple.com/forums/thread/746610
    ///      - See the Apple "GCDWorkQueues Guide" -> "Monitoring Signals" for an example of how to catch UNIX signals using Dispatch Source: https://developer.apple.com/library/archive/documentation/General/Conceptual/ConcurrencyProgrammingGuide/GCDWorkQueues/GCDWorkQueues.html
    ///
    /// On **Signals**:
    ///
    ///     See an overview of all UNIX signals at `man signal`
    ///
    ///     Termination signals:
    ///         -> These are signals that are sent when the process is supposed to be permanently stopped. In that case, we want to run our cleanup routine.
    ///         -> gnu.org explanation/collection of Termination Signals: https://web.archive.org/web/20240729192135/https://www.gnu.org/software/libc/manual/html_node/Termination-Signals.html
    ///     - `SIGTERM`: Standard termination signal. IIRC, we observed launchd sending this to the 'Mac Mouse Fix Helper' agent when it's booted out. Also sent when quitting the agent from Activity Monitor IIRC.
    ///     - `SIGKILL`: Standard force-termination signal. Sent when force-quitting the agent from Activity Monitor. Possibly also sent by launchd at some points. Not catchable at all.
    ///     - `SIGINT`: Sent when pressing CTRL+C while a process is running in the Terminal. Not sure this is relevant for us.
    ///     - `SIGHUP`: Sent to running processes when the controlling terminal closes. Not sure this is relevant for us. For daemons, this signal is sometimes used to make them reload configuration files and stuff (according to
    ///     Wikipedia iirc). Not sure this is relevant for us.
    ///     - `SIGQUIT`: Quits a process and creates a core image dump. Not sure we should clean up in this case, since this signal is for diagnosing the current state of the program.
    ///
    ///     On **crash signals**:
    ///         Certain signals, such as `SIGILL`, `SIGBUS`, and `SIGSEGV`, are sent to quit a process after there was an error inside of the process. I call them 'crash signals' or 'error signals'.
    ///         While these signals quit the agent, we don't need to do our cleanup routine then, since launchd should immediately restart our process after it crashes. So doing cleanup should make the user experience more disruptive if anything.
    ///
    ///     On **uncatchable signals**
    ///         When using "Dispatch Source", a few signals which *can* be handled through "sigaction()" are uncatchable: `SIGILL`, `SIGBUS` and `SIGSEGV`. (Src: Apple's GCDWorkQueues Guide: https://developer.apple.com/library/archive/documentation/General/Conceptual/ConcurrencyProgrammingGuide/GCDWorkQueues/GCDWorkQueues.html)
    ///             Luckily all these 3 signals are "crash signals" which we don't wanna catch anyways as explained above.
    ///         There are 2 signals which are generally uncatchable, through any method, even sigaction(): `SIGKILL` and `SIGSTOP`.
    ///
    ///     On **stop signals**
    ///         We're not setting up the handler for stop signals such as `SIGTSTP` or `SIGSTOP` - Those merely temporarily pause the program, instead of terminating it. I don't think this is relevant for us.
    ///
    ///  On debugging
    ///     - When LLDB is attached, standard sigaction() signal handlers are usually not called
    ///             (Not sure about "Dispatch Source" signal handlers, which we're using now instead of sigaction() handlers).
    ///         Run the following in lldb to enable our signal handers to run:
    ///         `process handle SIGTERM --pass true --stop false`
    ///         Then run the following in ther Terminal to test the signal:
    ///         `killall -SIGTERM "Mac Mouse Fix Helper"
    ///
    /// On async-signal-safety
    ///     We moved to using "Dispatch Source" since "sigaction()" handlers need to be async-signal-safe, which is hard to achieve.
    ///         - See `man sigaction` for list of async-signal-safe functions (very small list)
    ///         - See the async-signal-safe explanation in this [linux man page](https://man7.org/linux/man-pages/man7/signal-safety.7.html)
    ///         - The entire objc and swift runtimes are not async signal safe, according to Quinn "The Eskimo": https://forums.developer.apple.com/forums/thread/746610
    ///         - To do anything that's not async-signal-safe using sigaction(), you normally set an integer flag inside the sigaction() handler (which is one of the few things that is async-signal-safe to do), and then you monitor this flag from your runLoop.
    ///             However this is hard to do since our runLoops are normally controlled by CFRunLoop / NSRunLoop, which are not async-signal-safe to interact with AFAIK, so I think we'd have to create a separate thread for the purpose of running the unsafe stuff we wanna run in response to a UNIX Signal coming in. But I'm not sure.
    ///             -> Using Dispatch Source instead of sigaction() handlers is surely much easier.
    ///
    /// On thread-safety
    ///     I think this is thread safe (as of 03.10.2023), because:
    ///     - `load_Manual` is only called once from one place when the app starts up. It starts the signal-handling-callback as the very last thing it does. (so the signal-handling-callback won't run in parallel with the load function.)
    ///     - The signal-handling-callback is scheduled on a `dispatch_queue`, meaning that that code will never run in parallel.
    ///     - Those two functions are the only entry points to this file -> So I think overall, there's is no parallel code execution and therefore no race-conditions.
    
    static NSMutableArray *dispatchSources;
    static dispatch_queue_t signalHandlingQueue;
    static dispatch_once_t installOnce;
    dispatch_once(&installOnce, ^{
        int signals[] = { SIGTERM, SIGINT, SIGHUP };
        dispatchSources = [NSMutableArray array];
        signalHandlingQueue = dispatch_queue_create(
            "com.nuebling.mac-mouse-fix.termination-signals",
            DISPATCH_QUEUE_SERIAL
        );

        for (NSUInteger i = 0; i < sizeof(signals) / sizeof(signals[0]); i++) {
            int theSignal = signals[i];
            struct sigaction oldAction;
            struct sigaction ignoredAction = {
                .sa_handler = SIG_IGN,
                .sa_flags = 0,
                .sa_mask = 0,
            };
            sigemptyset(&ignoredAction.sa_mask);
            int result = sigaction(theSignal, &ignoredAction, &oldAction);
            if (result == -1) {
                perror("UNIXSignals: failed to install termination signal handler");
                assert(false);
                continue;
            }
            assert(oldAction.sa_handler == SIG_DFL);

            dispatch_source_t source = dispatch_source_create(
                DISPATCH_SOURCE_TYPE_SIGNAL,
                (uintptr_t)theSignal,
                0,
                signalHandlingQueue
            );
            if (source == nil) {
                perror("UNIXSignals: failed to create termination signal source");
                assert(false);
                continue;
            }
            [dispatchSources addObject:source];
            dispatch_source_set_event_handler(source, ^{
                termination_signal_handler(theSignal);
            });
            dispatch_activate(source);
        }
    });
}

static void termination_signal_handler(int theSignal) {
    
    ///
    /// Do cleanup
    ///
    
    /// Deconfigure Devices
    ///     Discussion:
    ///     - Sep 2024: Right now, this resets tweaks to the IOKitDriver. Later, this might also reset the onboard memory of the attached mice.
    ///         -> We tweak Apple's mouse IOKitDriver to adjust the pointer acceleration curve, we plan to at some point tweak the onboard memory to make buttons behave properly on Logitech mice.
    ///     - If we can't reliably "deconfigure" before exiting (e.g. because we sometimes receive SIGKILL and SIGSTOP, which we can't catch),
    ///         we might wanna - instead of trying to automaticallly deconfigure - make it apparent to MMF users when they are permanently changing the configuration [of their mouse hardware or the IOKit driver (IOKitDriver configuration is not really permanent though - only lasts until computer restart)]
    
    BOOL completedBeforeWaitDeadline = [M720SignalShutdownWaiter waitForCleanup:^(void (^completion)(BOOL)) {
        [DeviceManager deconfigureDevicesWithCompletion:completion];
    }];
    
    ///
    /// Log
    ///
    NSLog(
        @"UNIXSignals.m: Cleanup wait finished (completed=%@). About to exit.",
        completedBeforeWaitDeadline ? @"YES" : @"NO"
    );
    
    ///
    /// Trigger default action of signal.
    ///
    
    /// Notes:
    /// - We could also simply call `exit(0)`  to terminate the process. But that might not behave exactly like the default action, e.g. SIGSEGV creates a 'core image' (debug crash report stuff afaik.)
    ///     (Update 30.09.2024: Since we're only handling simple termination signals now (SIGTERM, SIGINT, SIGHUP), exit(0) might be enough now - But triggering the default action of the signal feels more robust I guess.
    
    restore_default_signal_action(theSignal);
    
    /// Re-send the signal to invoke the default action
    ///     (... which is terminating the process and stuff.)
    ///     Notes:
    ///     - We could also use `kill(getpid(), signal_number)` to send the signal - not sure which is better.
    ///     - `raise()` sends the signal to the current thread IIRC.
    int ret = raise(theSignal);
    if (ret == -1) {
        perror("raise() returned an error inside the termination_signal_handler.");
        assert(false);
        exit(0);
    }
}

static void restore_default_signal_action(int theSignal) {
    struct sigaction action = {
        .sa_handler = SIG_DFL,
        .sa_flags = 0,
        .sa_mask = 0,
    };
    sigemptyset(&action.sa_mask);
    int result = sigaction(theSignal, &action, NULL);
    if (result == -1) {
        perror("UNIXSignals: failed to restore default signal action");
        assert(false);
        exit(0);
    }
}

@end
