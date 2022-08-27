//
// --------------------------------------------------------------------------
// AppDelegate.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <PreferencePanes/PreferencePanes.h>
#import "AppDelegate.h"
#import "Config.h"
#import "SharedMessagePort.h"
#import "Utility_App.h"
#import "AuthorizeAccessibilityView.h"
#import "HelperServices.h"
#import "SharedUtility.h"
#import "ToastNotificationController.h"
#import "NSView+Additions.h"
#import "AppTranslocationManager.h"
#import "MessagePort_App.h"
#import <Sparkle/Sparkle.h>
#import "SparkleUpdaterController.h"
#import "NSAttributedString+Additions.h"
#import "Mac_Mouse_Fix-Swift.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;

@end

@implementation AppDelegate

#pragma mark - IBActions

- (IBAction)openAboutTab:(id)sender {
}

- (IBAction)activateLicense:(id)sender {
    [LicenseSheetController add];
}

#pragma mark - Interface funcs

/// TODO: Remove these in favor of MainAppState.swift

+ (AppDelegate *)instance {
    return (AppDelegate *)NSApp.delegate;
}
+ (NSWindow *)mainWindow {
    return self.instance.window;
}

#pragma mark - Handle URLs

- (void)handleURLWithEvent:(NSAppleEventDescriptor *)event reply:(NSAppleEventDescriptor *)reply {
    
    DDLogDebug(@"Handling URL: %@", event.description);
    NSString *address = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
    NSURL *url = [NSURL URLWithString:address];
    
    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:YES];
    assert([components.scheme isEqual:@"macmousefix"]); /// Assert because we should only receive URLs with this scheme
    
    NSString *path = components.path;
    
    if ([path isEqual:@"activate"]) {
        
        [LicenseSheetController add];
        
    } else {
        DDLogWarn(@"Received URL with unknown path: %@", address);
    }
}

#pragma mark - Init and Lifecycle

/// Define Globals
static NSDictionary *_scrollConfigurations;
static NSDictionary *sideButtonActions;

+ (void)initialize {
    
    if (self == [AppDelegate class]) {
        
        /// Why don't we do these things in applicationDidFinishLaunching?
        ///     TODO: Try moving this to applicationDidFinishLaunching, so we have a unified entryPoint.
        
        /// Setup CocoaLumberjack
        [SharedUtility setupBasicCocoaLumberjackLogging];
        DDLogInfo(@"Main App starting up...");     
        
        /// Remove restart the app untranslocated if it's currently translocated
        /// Need to call this before `MessagePort_App` is initialized, otherwise stuff breaks if app is translocated
        [AppTranslocationManager removeTranslocation];
        
        /// Start parts of the app that depend on the initialization we just did
        [MessagePort_App load_Manual];
        
        /// Need to manually initConfig because it is shared with Helper, and helper uses `load_Manual`
        ///     Edit: What?? That doesn't make sense to me.
        [Config load_Manual];
    }
    
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        /// Init URL handling
        ///     Doesn't work if done in applicationDidFinishLaunching or + initialize
        [NSAppleEventManager.sharedAppleEventManager setEventHandler:self andSelector:@selector(handleURLWithEvent:reply:) forEventClass:kInternetEventClass andEventID:kAEGetURL];
    }
    return self;
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
    
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    
#pragma mark Entry point of MainApp
    
    /// Log
    
    DDLogInfo(@"Mac Mouse Fix finished launching");
    
    /// Test titlebarAccessory
    ///     Trying to add accessoryView to titlebar. We want this for app specific settings. Doesn't work so far
    ///     \note This *is* successfully added when we open the main app through the StatusBarItem (using NSWorkspace and the bundle URL)
    if ((NO)) {
        NSTitlebarAccessoryViewController *viewController = [[NSTitlebarAccessoryViewController alloc] initWithNibName:@"MyTitlebarAccessoryViewController" bundle:nil];
        viewController.layoutAttribute = NSLayoutAttributeRight;
        [NSApp.mainWindow addTitlebarAccessoryViewController:viewController];
    }
    
    /// Update licenseConfig
    ///     We only update once on startup and then use`[LicenseConfig getCached]` anywhere else in the main app. (Currrently only the about tab.)
    ///     Notes:
    ///     - If the user launches the app directly into the aboutTab, or switches to it super quickly, then the displayed info won't be up to date, but that's a very minor problem
    ///     - We don't need a similar mechanism in Helper, because it doesn't need to display licenseConfig immediately after user input
    ///     Edit: Turning this off for now because we don't need it.
    
//    [LicenseConfig getOnComplete:^(LicenseConfig * _Nonnull config) { }];
    
#pragma mark Init Sparkle
    
    /// Update app-launch counters
    
    NSInteger launchesOverall;
    NSInteger launchesOfCurrentBundleVersion;
    
    launchesOverall = [(id)config(@"Other.launchesOverall") integerValue];
    launchesOfCurrentBundleVersion = [(id)config(@"Other.launchesOfCurrentBundleVersion") integerValue];
    NSInteger lastLaunchedBundleVersion = [(id)config(@"Other.lastLaunchedBundleVersion") integerValue];
    NSInteger currentBundleVersion = Utility_App.bundleVersion;
    
    launchesOverall += 1;
    
    if (currentBundleVersion != lastLaunchedBundleVersion) {
        launchesOfCurrentBundleVersion = 0;
    }
    launchesOfCurrentBundleVersion += 1;
    
    setConfig(@"Other.launchesOfCurrentBundleVersion", @(launchesOfCurrentBundleVersion));
    setConfig(@"Other.launchesOverall", @(launchesOverall));
    setConfig(@"Other.lastLaunchedBundleVersion", @(currentBundleVersion));
    
    
    BOOL firstAppLaunch = launchesOverall == 1; /// App is launched for the first time
    BOOL firstVersionLaunch = launchesOfCurrentBundleVersion == 1; /// Last time that the app was launched was a different bundle version
    
    /// Configure Sparkle Updater
    ///  (See https://sparkle-project.org/documentation/customization/)
    
    /// Some configuration is done via Info.plist, and seemingly can't be done from code
    /// Some more configuration is done from SparkleUpdaterController.m
    
    SUUpdater *up = SUUpdater.sharedUpdater;
    
    up.automaticallyChecksForUpdates = NO;
    /// ^ We set this to NO because we just always check when the app starts. That's simpler and it's how the old non-Sparkle updater did it so it's a little easier to deal with.
    ///   We also use the `updaterShouldPromptForPermissionToCheckForUpdates:` delegate method to make sure no Sparkle prompt occurs asking the user if they want automatic checks.
    ///   You could also disable this from Info.plist using `SUEnableAutomaticChecks` but that's unnecessary
    
//    up.sendsSystemProfile = NO; /// This is no by default
    up.automaticallyDownloadsUpdates = NO;
    
    BOOL checkForUpdates = [(id)config(@"Other.checkForUpdates") boolValue];
    
    BOOL checkForPrereleases = [(id)config(@"Other.checkForPrereleases") boolValue];
    
    if (firstVersionLaunch && !appState().updaterDidRelaunchApplication) {
        /// TODO: Test if updaterDidRelaunchApplication works.
        ///     It will only work if `SparkleUpdaterDelegate - updaterDidRelaunchApplication:` is called before this
        /// The app (or this version of it) has probably been downloaded from the internet and is running for the first time.
        ///  -> Override check-for-prereleases setting
        if (SharedUtility.runningPreRelease) {
            /// If this is a pre-release version itself, we activate updates to pre-releases
            checkForPrereleases = YES;
        } else {
            /// If this is not a pre-release, then we'll *deactivate* updates to pre-releases
//            checkForPrereleases = NO;
        }
        setConfig(@"Other.checkForPrereleases", @(checkForPrereleases));
    }
    
    /// Write changes to we made to config through setConfig() to file. Also notifies helper app, which is probably unnecessary.
    commitConfig();
    
    /// Check for udates
    
    if (checkForUpdates) {
        
        NSString *feedURLString;
        
        [SparkleUpdaterController enablePrereleaseChannel:checkForPrereleases];
        
        [up checkForUpdatesInBackground];
    }
    
}
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    DDLogInfo(@"Mac Mouse Fix should terminate");


    return NSTerminateNow;
}

- (void)windowWillClose:(NSNotification *)notification {
//    [UpdateWindow.instance close]; Can't find a way to close Sparkle Window
}

- (BOOL) applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app {
    return YES;
}

@end
