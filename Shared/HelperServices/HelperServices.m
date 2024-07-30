//
// --------------------------------------------------------------------------
// HelperServices.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// This class is primarily used to activate, deactivate and check activation state of the helper as a 'launchAgent'. (A process that always runs in the background)
///     - It achieves this primarily  by wrapping the `launchctl` command line tool and the `SMAppService` API for macOS 13.0 and later.
///     - Later we also added some methods for restarting the helper and for starting a new instance of the helper in a special mode. We should maybe split the functionality up into different classes.

/// Notes on availability
///     HelperServices uses a new API for registering the Helper as launchAgent under macOS 13.0 Ventura. It's called `SMAppService`. It's not available pre-Ventura. To handle this we use Apple's availability APIs.
///     Unfortunately there have been problems with the availability APIs. See https://github.com/noah-nuebling/mac-mouse-fix/issues/241.
///     Below you can find my notes / stream of consciousness on trying to figure this out.
///
///     __General confusion__: Apple uses `API_AVAILABLE()` on ObjC and Swift interfaces . But we want to mark a static C function implementation for availability. This isn't documented anywhere I could find. But it does successfully give a warning when you try to call the C function outside an `if @available` block, and it let's you use `SMAppService` inside the marked function without an `if @available` block. So it really lets you think that it's not running the code pre Ventura and that everything is fine. Yet, apparently it tries to link the unavailable code on older versions and then crashes.
///     Sidenote: Not sure where the underscore variant `__API_AVAILABLE` comes from.
///     __Summary of Problem__: Users that don't use Ventura have experienced crashes that happen while trying to link `SMAppService`. (Which isn't available pre-Ventura).
///     __Ideas for what's the problem__: 1. `__` underscores variant of the macro shouldn't be used and breaks things. 2. Availability macro doesn't work properly on C functions. 3. We STILL need to wrap code inside the `API_AVAILABLE`d function with `if @available` blocks. (Even though Xcode gives no warning against this)
///     -> It's hard to know because I can't test older versions right now.
///     Edit: Looked at `__API_AVAILABLE` and `API_AVAILABLE`, and I think they are probably identical.
///     __Game plan__: Fix all the possible reasons we could come up with: 1. Use non-underscore variant. 2. Make all the unavailable function into objc methods (and make sure they are marked in the header too, if they appear there) 3. wrap everything in `if @available` blocks. Bing bam boom.

///     Upate 14.08.2022 Still crashes for the dude. Made another change: All mentions of macOS 11, 12, 13 have been replaced with 11.0, 12.0, 13.0. Because all the examples on the internet write it like that. Let's see if that helps. Edit: That fixed it! See https://github.com/noah-nuebling/mac-mouse-fix/issues/241


/**
 
 Example output of the `launchctl list mouse.fix.helper` command
 
     {
         "StandardOutPath" = "/dev/null";
         "LimitLoadToSessionType" = "Aqua";
         "StandardErrorPath" = "/dev/null";
         "MachServices" = {
             "com.nuebling.mac-mouse-fix.helper" = mach-port-object;
         };
         "Label" = "mouse.fix.helper";
         "OnDemand" = false;
         "LastExitStatus" = 0;
         "PID" = 709;
         "Program" = "/Applications/Mac Mouse Fix.app/Contents/Library/LoginItems/Mac Mouse Fix Helper.app/Contents/MacOS/Mac Mouse Fix Helper";
         "PerJobMachServices" = {
             "com.apple.tsm.portname" = mach-port-object;
             "com.apple.axserver" = mach-port-object;
         };
     };
 
 Old stuff
 
    NSString *prefPaneSearchString = @"/PreferencePanes/Mouse Fix.prefPane/Contents/Library/LoginItems/Mouse Fix Helper.app/Contents/MacOS/Mouse Fix Helper";

 */

#import <AppKit/AppKit.h>
#import "HelperServices.h"
#import "Constants.h"
#import "Locator.h"
#import "SharedUtility.h"
#import "MFMessagePort.h"
#import <ServiceManagement/ServiceManagement.h>
#import <sys/sysctl.h>
#import <sys/types.h>
#import "MFMessagePort.h"

#import "NSString+Additions.h"

#if IS_MAIN_APP
#import "Mac_Mouse_Fix-Swift.h"
#endif
#if IS_HELPER
#import "Mac_Mouse_Fix_Helper-Swift.h"
#endif

@implementation HelperServices

#pragma mark - Interface...
///
///
///
#pragma mark Check Helper is Active

+ (BOOL)helperIsActive {
    
    
    /// New method
    ///     Send method to helper to ask if it's active.
    ///     Also checks that the connected helper's bundle version matches the main app's bundle version and returns that the helper is inactive if not. This circumvents issues where the main app would think it's enabled when being started while an old incompatible helper instance is still running
    ///     TODO: If an old, incompatible helper is still running - disable it

    return [self helperIsActive_Message];

    /// Old method
    ///     Ask launchd apis whether helper is active.
    ///     Not as reliable, because sometimes there will be an old version of the helper still active (in that case we wan't to return that the helper is incactive but these APIs returned that it is active) or maybe the launchd APIs have registered the helper job but they're not actually starting anything. This happens under Ventura when trying to start the app from another location.

//    if (@available(macos 13.0, *)) {
//        return [self helperIsActive_SM];
//    } else {
//        return helperIsActive_PList();
//    }
}

#pragma mark Enable / Disable Helper

+ (void)disableHelperFromHelper {
    
    /// Validate
    assert(runningHelper());
    
    /// HACK (?)
    ///     Our original approach (below) doesn't work with the new SMAppService API under Ventura Beta, so we're disabling this for now. See below for more info.
    ///     Instead, we'll open the mainApp and have it disable the helper
    [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"macmousefix:disable"]];
    
    return;
    
    /// Notify mainApp
    [MFMessagePort sendMessage:@"helperDisabled" withPayload:nil waitForReply:NO];
    
    /// Disable helper
    ///     We can't just do `[self removeHelperFromLaunchd]`, because
    ///     - On macOS 13.0 and above, SMAppService will still show the helper as enabled
    ///     - On macOS 12.0 and below the launchd.plist will still be in the library and restart the helper on the next login
    ///     So instead we need to use `enableHelperAsUserAgent:`. The problem is, that, using SMAppService, it doesn't seem possible to make the method work when it's called from somewhere other than the mainApp.
    ///     I just tried to create a separate launchd.plist file for embedding inside the helper, but it's not picked up as the same service.
    ///     Just filed a ticket Apple.
    ///     For now we'll just turn this functionality off. If it never gets resolved by Apple, we can use weird hacks. Basically, could set a disabledByHelper flag in the config.plist, and then use use `launchctl remove` now to kill the helper and whenever it tries to start up again. Then the next time we start the mainApp, we'll actually properly unregister the helper.
    
    [self enableHelperAsUserAgent:NO onComplete:nil];
}

+ (void)enableHelperAsUserAgent:(BOOL)enable onComplete:(void (^ _Nullable)(NSError * _Nullable error))onComplete {
    
    /// Register/unregister the helper as a User Agent with launchd so it runs in the background - also launches/terminates helper
    /// Not sure if we should use this directly. Using EnabledState.shared.enable() / disable() is probably better
    ///
    /// I refactored HelperServices, which is very dangerous. Haven't tested it properly at the time of writing, especially pre-Ventura.
    ///     I think 07e861de4504daad9996a40ce32c4aea5c87552a is the last commit before the changes.
    
    if (@available(macOS 13.0, *)) {
        
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
                
            ///
            /// Cleanup
            ///
            
            /// Edit: I'm not totally sure what the reason is for the differences between this and what we do pre macOS 13.
            /// - Why aren't we terminating other helper instance here?
            
            /// Remove __app__ launchd.plist
            removeLaunchdPlist();
            
            /// Remove __prefpane__ launchd.plist
            removePrefpaneLaunchdPlist();
            
            /// Unregister old helper from launchd
            removeServiceWithIdentifier(kMFLaunchdHelperIdentifier);
            
            /// Unregister strange helper
            /// Notes:
            /// - Under Ventura 13.0 we can't automatically fix it when a strange helper is registered. When we try to register the right helper, it will always register the strange one. The user has to uninstall the strange helper and then empty the trash and then restart to fix things
            /// - So removing the strange helper service won't help and leads to weird stuff where the helper seems to be started twice next time that it is registered.
            /// -> So we're disabling this for now. Hopefully Apple will fix this at some point.
            
//            if ([self strangeHelperIsRegisteredWithLaunchdIdentifier:kMFLaunchdHelperIdentifierSM]) {
//                removeServiceWithIdentifier(kMFLaunchdHelperIdentifierSM);
//            }
            
            /// Unregister if enabling
            /// - This is necessary for enabling to work after updating to new version in the same place while the old helper is still running
            /// - removeServiceWithIdentifier() also works for this, but it leads to the helper weirdly enabling twice which causes the `is-strange-helper-alert` message to be shown twice
            
            if (enable) {
                [self enableHelper_SM:NO];
            }
            
            ///
            /// Enable helper
            /// 
            
            /// Do this on some global queue. Xcode complains if you do this on mainThread because it can lead to unresponsive UI.
            
            NSError *error = [self enableHelper_SM:enable];
            
            ///
            /// Call onComplete
            ///
            if (onComplete != nil) onComplete(error);
        });
        
    } else {
        
        ///
        /// Generate / repair launchd.plist
        ///
        
        [HelperServices repairLaunchdPlist];
        
        ///
        /// Cleanup
        ///     Remove residue & prevent interference
        
        /// Remove old prefpane launchd.plist
        /// Notes:
        /// - We could only do this only if strangeHelperIsRegisteredWithLaunchd, but users have been having some weirdd issues after upgrading to the app version and I don't know why. I feel like this might make things slightly more robust.
        removePrefpaneLaunchdPlist();
        
        /// Unregister strange helper
        if ([self strangeHelperIsRegisteredWithLaunchdIdentifier:kMFLaunchdHelperIdentifier]) {
            removeServiceWithIdentifier(kMFLaunchdHelperIdentifier);
        }
        
        if (enable) {
            
            /// Kill & unregister if we're enabling
            ///
            /// Doing this because sometimes there's a weird bug where the main app won't recognize the helper as enabled even though it is. The code down below for enabling will then fail, when the user tries to check the enable checkbox.
            /// So we're removing the helper from launchd before trying to enable to hopefully fix this. Edit: seems to fix it!
            /// I'm pretty sure that if we didn't check for `launchdPathIsBundlePath` in `strangeHelperIsRegisteredWithLaunchd` this issue whave occured and we wouldn't need this workaround. But I'm not sure anymore why we do that so it's not smart to remove it.
            /// Edit: I think the specific issue I saw only happens when there are two instances of MMF open at the same time.
            
            removeServiceWithIdentifier(kMFLaunchdHelperIdentifier);
            
            /// Kill non-launchd helpers
            ///     Non-launchd helpers can only normally happen during debugging I think
            [HelperServices terminateAllHelperInstances];
            
        }
        
        ///
        /// Enable helper
        ///
        enableHelper_PList(enable);
        
        ///
        /// Call onComplete
        ///
        if (onComplete != nil) onComplete(nil);
    }
}

#pragma mark Killall Helpers

+ (void)killAllHelpers {
    
    /// The updated helper application will subsequently be launched by launchd due to the keepAlive attribute in Mac Mouse Fix Helper's launchd.plist
    /// This is untested but it's copied over from the old Updating mechanism, so I trust that it works in this context, too.
    /// At time of writing, this is only used by Sparkle update mechanism. We have a separate killAllHelpers method we use internally. Kind of weird. Should probably unify.
    
    BOOL helperNeutralized = NO;
    for (NSRunningApplication *app in [NSRunningApplication runningApplicationsWithBundleIdentifier:kMFBundleIDHelper]) {
        if ([app.bundleURL isEqualTo: Locator.helperOriginalBundle.bundleURL]) {
            [app terminate];
            helperNeutralized = YES;
            break;
        }
    }
    
    if (helperNeutralized) {
        NSLog(@"Helper has been neutralized");
    } else {
        NSLog(@"No helper found to neutralize");
    }
}

#pragma mark Restart Helper

+ (void)restartHelperWithDelay:(double)delay {
    
    /// Specify the`delay` between closing and restarting the helper
    
    /// 2. Approach
    ///     Disable and re-enable. This seems to circumvent the 1 launch per 10 seconds restriction. (See possibleRestartTime)
    
    if (runningMainApp()) {
        
//        assert([self helperIsActive]);
        
        [self enableHelperAsUserAgent:NO onComplete:^(NSError * _Nullable error) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                
                [self enableHelperAsUserAgent:YES onComplete:nil];
            });
        }];
        
    } else if (runningHelper()) {
        
        /// Open the mainApp and then have it call this function
        
        [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:stringf(@"macmousefix:restarthelper?delay=%@", @(delay))]];
        
    } else {
        abort();
    }
    
    /// 1. Approach
    /// If this function is called before `possibleRestartTime` it will freeze until that time
    
//    NSString *serviceTarget = stringf(@"gui/%u/%@", geteuid(), [self launchdID]);
//    [SharedUtility launchCLT:[NSURL fileURLWithPath:kMFLaunchctlPath] withArguments:@[@"kickstart", @"-k", serviceTarget] error:nil];
    
    
    
}

#pragma mark - Special Mode Helper

+ (NSString *)launchHelperInstanceWithMessage:(NSString *)message {
    
    /// Launches a new instance of helper in special mode where it processes the `message` and then quits immediately.
    ///     This function will wait until the helper has quit
    
    /// Define args for the `open` CLT
    ///     `-W` waits until the app has quit, `-n` spawns a new instance of the app, `-a` specifies the application to open, `--args` specifies the args to pass to the application.
    NSArray *args = @[@"-W", @"-n", @"-a", Locator.helperBundle.bundlePath, @"--args", message];
    
    /// Launch the tool
    ///     And wait
    ///     Should probably do some error handing here
    NSString *response = [SharedUtility launchCLT:[NSURL fileURLWithPath:kMFOpenCLTPath] withArguments:args error:nil];
    
    /// Return
    return response;
}

#pragma mark - End of interface
///
///
///
#pragma mark Check Helper Is Active

+ (BOOL)helperIsActive_Message {

    if (runningMainApp()) {
                NSNumber *response = (NSNumber *)[MFMessagePort sendMessage:@"getBundleVersion" withPayload:nil waitForReply:YES];
        return response != nil && response.integerValue == Locator.bundleVersion;
        
    } else {
        /// Crash
        assert(false);
        abort();
    }
}

/// helperIsActive_SM from version-3. Merge updates from version-2 and git said that "both modified". Doesn't look like both modified. But I'll leave this here for reference in case something breaks.
// static BOOL helperIsActive_SM() __API_AVAILABLE(macos(13.0)) {
    // SMAppService *service = [SMAppService agentServiceWithPlistName:@"sm_launchd.plist"];
    // BOOL result = service.status == SMAppServiceStatusEnabled;
    // if (result) {
    //     DDLogDebug(@"Helper found to be active");
    // } else {
    //     DDLogDebug(@"Helper found to be inactive. Status: %ld", (long)service.status);
    // }
    // return result;

+ (BOOL)helperIsActive_SM API_AVAILABLE(macos(13.0)) {
    
    if (@available(macOS 13.0, *)) {
        
        SMAppService *service = [SMAppService agentServiceWithPlistName:@"sm_launchd.plist"];
        BOOL result = service.status == SMAppServiceStatusEnabled;
        
        if (result) {
            DDLogDebug(@"Helper found to be active");
        } else {
            DDLogDebug(@"Helper found to be inactive. Status: %ld", (long)service.status);
        }
        return result;
    } else {
        /// Not running macOS 13.0
        ///     This can never happen. Just crashing here so the compiler doesn't complain about missing returns.
        abort();
    }
}

static BOOL helperIsActive_PList(void) {
    
    /// Get info from launchd
    NSString *launchctlOutput = launchctl_list(kMFLaunchdHelperIdentifier);
    
    /// Analyze info
    
    /// Check if label exists. This should always be found if the helper is registered with launchd. Or equavalently, if the output isn't "Could not find service "mouse.fix.helper" in domain for port"
    NSString *labelSearchString = stringf(@"\"Label\" = \"%@\";", kMFLaunchdHelperIdentifier);
    BOOL labelFound = [launchctlOutput rangeOfString: labelSearchString].location != NSNotFound;
    
    /// Check exit status. Not sure if useful
    BOOL exitStatusIsZero = [launchctlOutput rangeOfString: @"\"LastExitStatus\" = 0;"].location != NSNotFound;
    
    if ([HelperServices strangeHelperIsRegisteredWithLaunchdIdentifier:kMFLaunchdHelperIdentifier]) {
        DDLogInfo(@"Found helper running somewhere else.");
        return NO;
    }
    
    if (labelFound && exitStatusIsZero) { /// Why check for exit status here?
        DDLogInfo(@"MOUSE REMAPOR FOUNDD AND ACTIVE");
        return YES;
    } else {
        DDLogInfo(@"Helper is not active");
        return NO;
    }
}

#pragma mark Enable/Disable helper

+ (NSError *_Nullable)enableHelper_SM:(BOOL)enable API_AVAILABLE(macos(13.0)) {
    
    /// TODO: Dispatch this stuff to another thread. Xcode analysis on `registerAndReturnError:` says "This method should not be called on the main thread as it may lead to UI unresponsiveness"

    if (@available(macOS 13.0, *)) {
            
        /// Guard running main app
        ///     Before using the SM APIs we could call this from anywhere, but the SM stuff will only work from the mainApp afaik.
        if (runningHelper()) {
            DDLogWarn(@"Calling enableHelper_SM from Helper under Ventura or later. This is does not work.");
            return [NSError errorWithDomain:MFHelperServicesErrorDomain code:kMFHelperServicesErrorEnableFromHelper userInfo:nil];
        }
        
        /// Create error
        
        NSError *error = nil;

        /// Do the core (un)registering
        /// Notes:
        /// - `loginItemServiceWithIdentifier:` would be easiest but it breaks with multiple copies of the app installed. Also, it doesn't allow for setting niceness and other stuff. So using an agent is better.
        /// - Udpate: Currently using `agentServiceWithPlistName:` and that breaks too with multiple copies installed. It's actually super broken and leads to lots of people not being able to enable MMF. See `checkHelperStrangenessReact(payload:` for more info on the issues.
        ///     - I just did some testing under macOS 14.2 for most of the ways that this breaks, and it never returned any error and always returned success=YES even though it didn't actually work.
        ///         The ways that it breaks that I tested are:
        ///         1. Have a second copy of MMF installed and registered with SMAppService - in this case, the second copy's helper will be started instead of the helper of the current bundle.
        ///         2. Move the second, registered copy of MMF to the trash - in this case nothing happens when you try to enable this copy of MMF.
        ///         3. Empty the trash - after that, also nothing happens when you try to this copy of MMF
        ///         (When you restart the computer after emptying the trash that usually fixes things, so we didn't check that case for errors. Also when you restart the computer while the copy is still in the trash then the restart doesn't seem to change anything, so we also didn't test that case.)
        
        SMAppService *service = [SMAppService agentServiceWithPlistName:@"sm_launchd.plist"];
        if (enable) {
            BOOL success = [service registerAndReturnError:&error];
            if (!success){
                NSLog(@"Failed to register Helper with error: %@", error);
            } else {
                NSLog(@"Registered Helper!");
            }
        } else {
            BOOL success = [service unregisterAndReturnError:&error];
            if (!success){
                NSLog(@"Failed to UNregister Helper with error: %@", error);
            } else {
                NSLog(@"Unregistered Helper.");
            }
            
            
        }
        
        return error;
    } /// End `if @available`
    
    abort();
}

static void enableHelper_PList(BOOL enable) {
    
    /// This is the main function for the 'old method' where we were manually managing a plist file. Under Ventura we switched to a new framework
    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath: kMFLaunchctlPath];
    NSString *GUIDomainArgument = [NSString stringWithFormat:@"gui/%d", geteuid()];
    NSString *OnOffArgument = (enable) ? @"bootstrap": @"bootout";
    NSString *launchdPlistPathArgument = Locator.launchdPlistURL.path;
    task.arguments = @[OnOffArgument, GUIDomainArgument, launchdPlistPathArgument];
    NSPipe *pipe = NSPipe.pipe;
    task.standardError = pipe;
    task.standardOutput = pipe;
    NSError *error;
    task.terminationHandler = ^(NSTask *task) {
        if (enable == NO) { /// Cleanup (delete launchdPlist) file after were done // We can't clean up immediately cause then launchctl will fail
            removeLaunchdPlist();
        }
        DDLogInfo(@"launchctl terminated with stdout/stderr: %@, error: %@", [NSString.alloc initWithData:pipe.fileHandleForReading.readDataToEndOfFile encoding:NSUTF8StringEncoding], error);
    };
    [task launchAndReturnError:&error];
}

#pragma mark - Remove launchctl service

static void removeServiceWithIdentifier(NSString *identifier) {
    
    /// Remove service from launchd
    /// Notes:
    /// - From my testing this does the same as the `bootout` command, but it doesn't rely on a valid launchd.plist file to exist in the library, so it should be more robust.
    /// - The removed service will be quit immediately but will be restarted on the next boot. Pre-SMAppService you can prevent start on next boot by deleting the launchd.plist file. Post-SMAppService you need to unregister the service. Not sure if there are other ways.
    
    DDLogInfo(@"Removing service %@ from launchd", identifier);
    
    NSURL *launchctlURL = [NSURL fileURLWithPath:kMFLaunchctlPath];
    NSError *err;
    [SharedUtility launchCLT:launchctlURL withArguments:@[@"remove", identifier] error:&err];
    if (err != nil) {
        DDLogError(@"Error removing service %@ from launchd: %@", identifier, err);
    }
    
    /// Wait until service is actually removed
    /// Notes:
    /// - Otherwise enabling while old helper is still enabled won't work under Mojave
    /// - TODO: We also brought this improvement to MMF 2 but was hacky since it's missing some previous improvements made to HelperServices. That's bad, we shouldn't have let HelperServices diverge like that between MMF 2 and 3! We should unify them again.
    
    int maxWaitCycles = 25;
    int i = 0;
    while (true) {
        
        NSString *launchctlOutput = launchctl_list(identifier);
        
        if ([launchctlOutput isEqual:@""]) break;
        if (i >= maxWaitCycles) break;
        
        i += 1;
    }
}

#pragma mark - Get info from launchctl

NSString *launchctl_list(NSString *identifier) {
    
    /// Using NSTask to ask launchd about helper status
    
    NSURL *launchctlURL = [NSURL fileURLWithPath:kMFLaunchctlPath];
    NSString *launchctlOutput = [SharedUtility launchCLT:launchctlURL withArguments:@[@"list", identifier] error:nil];
    return launchctlOutput;
}

NSString *launchctl_print(NSString *identifier) {
    
    /// Using NSTask to ask launchd about helper status. 
    /// We meant to use for for `executablePathForLaunchdIdentifier:` but never did. So currently this is unused and untested.
    
    NSURL *launchctlURL = [NSURL fileURLWithPath:kMFLaunchctlPath];
    NSString *serviceTarget = [NSString stringWithFormat:@"gui/%d/%@", getuid(), identifier];
    
    NSString *launchctlOutput = [SharedUtility launchCLT:launchctlURL withArguments:@[@"print", serviceTarget] error:nil];
    return launchctlOutput;
}

+ (NSString *)launchdID {
    if (@available(macOS 13.0, *)) {
        return kMFLaunchdHelperIdentifierSM;
    } else {
        return kMFLaunchdHelperIdentifier;
    }
}

+ (BOOL)strangeHelperIsRegisteredWithLaunchdIdentifier:(NSString *)identifier {
    
    /// Check if helper is registered with launchd from some other location
    
    NSString *launchdPath = [self executablePathForLaunchdIdentifier:identifier];
    BOOL launchdPathExists = launchdPath.length != 0;
    
    if (launchdPathExists) {
        
        BOOL isStrange = ![Locator.helperBundle.executablePath isEqual:launchdPath];
        
        if (isStrange) {
            
            DDLogWarn(@"Strange helper: found at: %@ \nbundleExecutable at: %@", launchdPath, Locator.helperBundle.executablePath);
            return YES;
        }
    }
    
    DDLogInfo(@"Strange Helper: not found");
    return NO;
}

+ (NSString *)executablePathForLaunchdIdentifier:(NSString *)identifier {
    
    if (@available(macOS 13.0, *)) {
        
        /// Notes on getting **executable path**:
        /// For SMAppService the only way to reliably get the executable path is the `sfltool dumpbtm` command. But it requires sudo permissions, so we can't do it in the background programmatically.
        /// Under 14.2.1 I saw that `launchctl print gui/501/com.nuebling.mac-mouse-fix.helper` sometimes contains the executable path, but only under these circumstances:
        ///     Sometimes launchd gets confused because you try to launch MMF after moving it, or you try to launch it while there's another copy of MMF present on the system.
        ///     If and only if you have the case where launchd is confused because you **moved** MMF and you THEN call `launchctl print`, then the output seems to contain the executable path. But in the successful case or in the case where launchd launches the wrong copy of MMF Helper, `print` doesn't contain the executable path.
        /// I would be somewhat useful to retrieve the executable path from `print` in this case to give the user instructions how to fix the issue. However, the instructions are just 'restart your computer', and that doesn't seem like it's worth implementing at the moment.
        /// Especially since we don't even know what causes [all these enabling issues](https://github.com/noah-nuebling/mac-mouse-fix/issues/648) and therefore don't know if this is would solve any real issues for users. I think it's better for now to just figure out what is causing these issues and then after that write a `Guide`, or write some automated fixes here.
        
        /// Notes on **launchd being confused**:
        /// (This is a general writeup on the launchd-is-confused issues. Maybe we should move it to some more centralized place.)
        /// - At the time of writing, when you use SMAppService to register the Helper, launchd sometimes gets confused if you: 1. Have several copies of the app installed. 2. Have moved the app (Although it does seem to track app-moves to some extent.)
        /// - To see where launchd thinks the app is, use `sfltool dumpbtm`
        /// - We handle some of the launchd confusion in MessagePortUtility.swift in the 'Strange Helper' detection stuff. If a helper from another copy of MMF is started and tries to connect with us, we shut it down and give the user instructions to deleted the other copy.
        /// - Despite this handling of the 'strange helper' situation, there are numerous reports of people not being able to open the app. See https://github.com/noah-nuebling/mac-mouse-fix/issues/648.
        /// - In all cases I observed, when launchd gets confused, SMAppService will say that it successfully launched the helper. (but really it will have launched a strange helper from another copy of MMF or it won't have launched anything at all) (I haven't studied the case where launchd doesn't launch anything at all much, so I'm not sure about that one.)
        
        return @"";
        
    } else {
        
        /// Note: This actually only works pre SMAppService. For services registered with SMAppService, it gets the executable path relative to the mainApp bundle which isn't that helpful.
        
        assert([identifier isEqual:kMFLaunchdHelperIdentifier]);
        
        NSString *launchctlOutput = launchctl_list(identifier);
        NSString *executablePath = [launchctlOutput substringWithRegex:@"(?<=\"Program\" = \").*(?=\";)"];
        
        return executablePath;
    }
}

#pragma mark - Killall Helpers

+ (void)terminateAllHelperInstances {
    
    /// Terminate any running instances of the helper app
    /// This only works to terminate instances of the Helper which weren't started by launchd.
    /// Launchd-started instances will immediately be restarted after they are terminated
    /// Mac Mouse Fix Accomplice does something similar to this in update()
    
    // TODO: This is very similar to `killAllHelpers`. Unify.
    
    DDLogInfo(@"Terminating other Helper instances");
    
    NSArray<NSRunningApplication *> *instances = [NSRunningApplication runningApplicationsWithBundleIdentifier:kMFBundleIDHelper];
    
    DDLogInfo(@"%lu other running Helper instances found", (unsigned long)instances.count);
        
    for (NSRunningApplication *instance in instances) {
        [instance terminate]; /// Consider using forceTerminate instead
    }
    
}

#pragma mark - Manage launchd.plist files

static void removeLaunchdPlist(void) {
    NSError *error;
    [NSFileManager.defaultManager removeItemAtURL:Locator.launchdPlistURL error:&error];
    if (error != nil) {
        DDLogError(@"Failed to delete launchd.plist file. This might be because the file doesn't exist. If the file still exists at \"%@\" the helper might be re-enabled on startup.", Locator.launchdPlistURL.path);
    }
}

+ (void)repairLaunchdPlist {
    /// What this does:
    
    /// Get path of executable of helper app
    /// Check
    /// - If the "User/Library/LaunchAgents/mouse.fix.helper.plist" useragent config file  (aka launchdPlist) exists
    ///     - This specific path is deprecated, since MMF is an app not a prefpane now
    /// - If the Launch Agents Folder exists
    /// - If the exectuable path within the plist file is correct
    /// If not:
    /// Create correct file based on "default_launchd.plist" and the helpers exectuablePath
    /// Write correct file to "User/Library/LaunchAgents"
    
    @autoreleasepool {
        /// Do we need an autoreleasepool here?
        /// -> No. Remove this.
        /// I just read up on it. You only need to manually use `autoreleasepool`s for optimization and some edge cases
        /// Here's my understanding. In normal scenarios, Cocoa objects are automatically sent autorelease messages when they go out of scope. Then, on the next iteration of the runloop, all objects that were sent autorelease messages will be sent release messges. Which will in turn cause their reference counts to drop, which will cause them to be deallocated when that reaches 0. When you use a manual autoreleasepool, then the autoreleased Cocoa objects will be sent release messages after the autoreleasepool block ends, and not only at the next runloop iteration. That's all it does in this scenario.
        /// When to use autoreleasepool: https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/MemoryMgmt/Articles/mmAutoreleasePools.html
        /// When autoreleased objects are sent release messages: https://stackoverflow.com/questions/673372/when-does-autorelease-actually-cause-a-release-in-cocoa-touch
        
        DDLogInfo(@"Repairing User Agent Config File");
        
        /// Declare error
        NSError *error;
        
        /// Get helper executable path
        NSBundle *helperBundle = Locator.helperBundle;
        NSBundle *mainAppBundle = Locator.mainAppBundle;
        NSString *helperExecutablePath = helperBundle.executablePath;
        
        /// Get path to launch agent config file (aka launchdPlist)
        NSString *launchdPlist_path = Locator.launchdPlistURL.path;
        
        /// Create file manager
        
        NSFileManager *fileManager = [[NSFileManager alloc] init];
        
        /// Check if launchPlist file exists
        
        BOOL launchdPlist_exists = [fileManager fileExistsAtPath: launchdPlist_path isDirectory: nil];
        
        /// Check if executable path is correct
        
        BOOL launchdPlist_executablePathIsCorrect = YES;
        
        if (launchdPlist_exists) {
            
            /// Load data from launch agent config file into a dictionary
            NSData *launchdPlist_data = [NSData dataWithContentsOfFile:launchdPlist_path];
            NSDictionary *launchdPlist_dict = [NSPropertyListSerialization propertyListWithData:launchdPlist_data options:NSPropertyListImmutable format:0 error:nil];
            
            /// Check if the executable path inside the config file is correct, if not, set flag to false
            NSString *helperExecutablePathFromFile = [launchdPlist_dict objectForKey: @"Program"];
            if ( [helperExecutablePath isEqualToString: helperExecutablePathFromFile] == NO ) {
                launchdPlist_executablePathIsCorrect = NO;
            }
            
            /// Debug
//            DDLogDebug(@"objectForKey: %@", OBJForKey);
//            DDLogDebug(@"helperExecutablePath: %@", helperExecutablePath);
//            DDLogDebug(@"OBJ == Path: %d", OBJForKey isEqualToString: helperExecutablePath);
        }
        
        /// Log
        
        DDLogInfo(@"launchdPlistExists %hhd, launchdPlistIsCorrect: %hhd", launchdPlist_exists,launchdPlist_executablePathIsCorrect);
        
        if ((launchdPlist_exists == FALSE) || (launchdPlist_executablePathIsCorrect == FALSE)) {
            /// The config file doesn't exist, or the executable path within it is not correct
            ///  -> Acutally repair stuff
            
            DDLogInfo(@"repairing file...");
            
            /// Check if "User/Library/LaunchAgents" folder exists, if not, create it
            
            NSString *launchAgentsFolderPath = [launchdPlist_path stringByDeletingLastPathComponent];
            
            BOOL launchAgentsFolderExists = [fileManager fileExistsAtPath:launchAgentsFolderPath isDirectory:nil];
            
            if (launchAgentsFolderExists == NO) {
                
                DDLogInfo(@"LaunchAgents folder doesn't exist");
                NSError *error;
                
                /// Create LaunchAgents folder
                
                error = nil;
                [fileManager createDirectoryAtPath:launchAgentsFolderPath withIntermediateDirectories:FALSE attributes:nil error:&error];
                if (error == nil) {
                    DDLogInfo(@"LaunchAgents Folder Created");
                } else if (error.code == NSFileWriteNoPermissionError) {
                    DDLogError(@"Lacking permission to create LaunchAgents folder. Error: %@", error);
                } else {
                    DDLogError(@"Error creating LaunchAgents Folder: %@", error);
                }
            }
            
            /// Repair permissions of LaunchAgents folder if it's not writable
            
            error = makeWritable(launchAgentsFolderPath);
            if (error) {
                DDLogError(@"Failed to make LaunchAgents folder writable. Error: %@", error);
            }
            
            /// Repair the contents of the launchdPlist file

            /// Read contents of default_launchd.plist (aka default-launch-agent-config-file or defaultLAConfigFile) into a dictionary
            
            error = nil;
            
            NSString *defaultLaunchdPlist_path = [mainAppBundle pathForResource:@"default_launchd" ofType:@"plist"];
            NSData *defaultlaunchdPlist_data = [NSData dataWithContentsOfFile:defaultLaunchdPlist_path];
            // TODO: This just crashed the app with "Exception: "data parameter is nil". It says that that launchdPlistExists = NO.
            // I was running Mac Mouse Fix Helper standalone for debugging, not embedded in the main app
            NSMutableDictionary *newlaunchdPlist_dict = [NSPropertyListSerialization propertyListWithData:defaultlaunchdPlist_data options:NSPropertyListMutableContainersAndLeaves format:nil error:&error];
            
            /// Set the executable path to the correct value
            [newlaunchdPlist_dict setValue: helperExecutablePath forKey:@"Program"];
            
            /// Get NSData from newLaunchdPlist dict
            NSData *newLaunchdPlist_data = [NSPropertyListSerialization dataWithPropertyList:newlaunchdPlist_dict format:NSPropertyListXMLFormat_v1_0 options:0 error:&error];
            NSAssert(error == nil, @"Failed to create NSData from new launchdPlist dict");
            
            /// Write new newLaunchdPlist data to file
            [newLaunchdPlist_data writeToFile:launchdPlist_path options:NSDataWritingAtomic error:&error];
            
            if (error != nil) {
                DDLogError(@"repairUserAgentConfigFile() -- Data Serialization Error: %@", error);
            }
        } else {
            DDLogInfo(@"Nothing to repair");
        }
    }
    
}

static NSError *makeWritable(NSString *itemPath) {
    /**
     
     Helper function for + repairLaunchdPlist
     Changes permissions of the item at filePath to allow writing by the user to that item
     
     __Motivation__
     - This is intended to be used by + repairLaunchdPlist to unlock the LaunchAgents folder so we can write our LaunchdPlist into it.
     - For some reason, many users have had troubles enabling Mac Mouse Fix recently. Many of these troubles turned out to be due to the LaunchAgents folder having it's permissions set to 'read only'. This function can be used to fix that.
        - See for example Issue [#54](https://github.com/noah-nuebling/mac-mouse-fix/issues/54)
        - There was also another GH issue where the user orignially figured out that permissions were the problem which prompted me to add better logging. But I'm writing this function much later. So I can't remember which GH Issue that was. Props to that user anyways.
    
     __Notes__
     - I really hope this doesn't break anything. Changing permissions in the file system feels somewhat dangerous.
     - Also it might be a good idea to ask the user if they want the permissions to be changed, but 99.9% of users won't even understand what they are deciding about, and it would be a lot of work to present this in a good way. So I think this should be fine.
     */
    
    /// Get fileManager
    
    NSFileManager *fileManager = NSFileManager.defaultManager;
    
    /// Check if file at filePath is writable
    
    if (![fileManager isWritableFileAtPath:itemPath]) {
        /// File is not writable
        
        /// Log
        
        DDLogWarn(@"File at %@ is not writable. Attempting to change permissions.", itemPath);
        
        /// Declare error
        
        NSError *error;
        
        /// Get file attributes
        
        error = nil;
        NSDictionary *attributes = [fileManager attributesOfItemAtPath:itemPath error:&error];
        if (error) return error;
        
        /// Get old permissions from file attributes
        
        NSUInteger oldPermissions = attributes.filePosixPermissions;
        
        /// Create new permissions
        
        NSUInteger newPermissions = oldPermissions | S_IWUSR;
        /// ^ Add write permission for user. See `man 2 chmod` for more info
            
        /// Set new permissions to file
            
        error = nil;
        [fileManager setAttributes:@{
            NSFilePosixPermissions: @(newPermissions)
        } ofItemAtPath:itemPath error:&error];
        
        if (error) {
            return error;
        }
        
        /// Debug
        
        DDLogInfo(@"Changed permissions of %@ from %@ to %@", itemPath,  [SharedUtility binaryRepresentation:(int)oldPermissions], [SharedUtility binaryRepresentation:(int)newPermissions]);
        /// ^ Binary representation doesn't really help. This is almost impossible to parse visually.
    }
    
    return nil;
}

static void removePrefpaneLaunchdPlist(void) {
        
    /// Remove legacy launchd plist file if it exists
    /// The launchd plist file used to be at `~/Library/LaunchAgents/com.nuebling.mousefix.helper.plist` when the app was still a prefpane. In the very early days it was at `mouse.fix.helper.plist`.
    /// The prefpane itself could be installed in the user library or the root library, but the launchd plist would always be in the user library.
    /// Now, with the app version, it's moved to `~/Library/LaunchAgents/com.nuebling.mac-mouse-fix.helper.plist`
    /// Having the old version still can lead to the old helper being started at startup, and I think other conflicts, too.
    
    DDLogInfo(@"Removing prefpane launchd plist");
    
    /// Find user library
    NSArray<NSString *> *libraryPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    assert(libraryPaths.count == 1);
    
    NSMutableString *libraryPath = libraryPaths.firstObject.mutableCopy;
    NSArray<NSString *> *legacyLaunchdPlistPaths = @[[libraryPath stringByAppendingPathComponent:@"LaunchAgents/com.nuebling.mousefix.helper.plist"],
                                                   [libraryPath stringByAppendingPathComponent:@"LaunchAgents/mouse.fix.helper.plist"]];
    NSError *err;
    
    
    for (NSString *path in legacyLaunchdPlistPaths) {
        
        /// Remove old file
        if ([NSFileManager.defaultManager fileExistsAtPath:path]) {
            
            [NSFileManager.defaultManager removeItemAtPath:path error:&err];
            
            if (err) {
                DDLogError(@"Error while removing prefpane launchd plist file at %@: %@", path, err);
            }
        } else  {
            DDLogDebug(@"No prefpane launchd.plist file found at: %@", path);
        }
    }
}

#pragma mark - Unused

+ (NSDate *)possibleRestartTime {
    
    /// Not sure what we used this for, but it seems we found a better solution.
    
    /// Launchd allows at most 1 launch per 10 seconds.
    ///     This method returns the earliest possible restart of the helper.
    
    /// Get helper startTime
    /// Src: https://stackoverflow.com/a/40677286/10601702
    
    NSRunningApplication *helper = [NSRunningApplication runningApplicationsWithBundleIdentifier:Locator.helperBundle.bundleIdentifier][0];
    pid_t pid = helper.processIdentifier;
    
    int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_PID, pid };
    struct kinfo_proc proc;
    size_t size = sizeof(proc);
    sysctl(mib, 4, &proc, &size, NULL, 0);
    
    NSDate *startTime = [NSDate dateWithTimeIntervalSince1970:proc.kp_proc.p_starttime.tv_sec];
    
    /// Get earliest possible restart time
    
    NSDate *tenSecs = [startTime dateByAddingTimeInterval:10];
    NSDate *now = [NSDate date];
    NSDate *possibleRestartTime = [now laterDate:tenSecs];
    
    /// Return
    
    return possibleRestartTime;
}

@end
