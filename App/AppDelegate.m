//
// --------------------------------------------------------------------------
// AppDelegate.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

/// implement checkbox functionality, setup AddingField mouse tracking and other minor stuff

#import <PreferencePanes/PreferencePanes.h>
#import "AppDelegate.h"
#import "ConfigInterface_App.h"
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

@interface AppDelegate ()

@property (strong) IBOutlet NSWindow *window;

@property (weak) IBOutlet NSButton *enableMouseFixCheckBox;

@property (weak) IBOutlet NSButton *scrollEnableCheckBox;

@property (weak) IBOutlet NSSlider *scrollStepSizeSlider;
@property (weak) IBOutlet NSButton *invertScrollCheckBox;

@property (weak) IBOutlet NSBox *preferenceBox;


@end

@implementation AppDelegate

# pragma mark - IBActions

- (IBAction)enableCheckBox:(NSButton *)sender {
    
    BOOL beingEnabled = sender.state;
    sender.state = !sender.state; /// Prevent user from changing checkbox state directly. Instead, we'll do that through the `enableUI` method.
    
    if (beingEnabled) {
        /// We won't enable the UI here directly. Instead, we'll do that from the `handleHelperEnabledMessage` method
    } else { /// Being disabled
        [self enableUI:NO];
    }
    
    NSError *error;
    [HelperServices enableHelperAsUserAgent:beingEnabled error:&error];
    /// ^ We enable/disable the helper.
    ///  After enabling, the helper will send a message to the main app confirming that it has been enabled (received by `AppDelegate + handleHelperEnabledMessage`). Only when that message is received, will we change the state of the checkbox and the rest of the UI to enabled.
    ///  This should make the checkbox state more accurately reflect what's going on when something goes wrong with enabling the helper, making things less confusing to users who experience issues enabling MMF.
    ///  We only do this for enabling and not for disabling, because disabling always seems to work. Another reason we're not applying this for disabling is that it could lead to issues if the helper just crashes and doesn't send an "I'm being disabled" message before quitting. In that case the checkbox would just stay enabled.
    
    
    /// Give user feedback if MMF is disabled in settings
    if (@available(macOS 13, *)) {
        if (error.code == 1) { /// Operation not permitted error
            NSAttributedString *message = [NSAttributedString attributedStringWithMarkdown:@"Mac Mouse Fix was **disabled** in System Settings.\nTo enable Mac Mouse Fix:\n\n1. Go to [Login Items Settings](x-apple.systempreferences:com.apple.LoginItems-Settings.extension)\n2. Switch on \'Mac Mouse Fix.app\'"];
            [MFNotificationController attachNotificationWithMessage:message toWindow:self.window forDuration:0.0];
            
        }
    }
}
+ (void)handleHelperEnabledMessage {
    
    if (self.instance.UIDisabled) {
        /// Enable UI
        [self.instance enableUI:YES];
        /// Flash Notification
//        NSAttributedString *message = [[NSAttributedString alloc] initWithString:@"Mac Mouse Fix will stay enabled after you restart your Mac"];
//        message = [message attributedStringBySettingFontSize:NSFont.smallSystemFontSize];
//        [Toast
//        NotificationController attachNotificationWithMessage:message toWindow:AppDelegate.mainWindow forDuration:-1 alignment:kToastNotificationAlignmentBottomMiddle];
    }
}

- (IBAction)openMoreSheet:(id)sender {
    [MoreSheet.instance begin];
}
- (IBAction)scrollEnableCheckBox:(id)sender {
    [self disableScrollSettings:@(_scrollEnableCheckBox.state)];
    [self UIChanged:NULL];
}
- (IBAction)UIChanged:(id)sender { // TODO: consider removing
    [self setConfigFileToUI];
}

#pragma mark - Interface funcs

+ (AppDelegate *)instance {
    return (AppDelegate *)NSApp.delegate;
}
+ (NSWindow *)mainWindow {
    return self.instance.window;
}
- (RemapTableController *)remapTableController {
    RemapTableController *controller = (RemapTableController *)self.remapsTable.delegate;
    return controller;
}

#pragma mark - Init and Lifecycle

/// Define Globals
static NSDictionary *_scrollConfigurations;
static NSDictionary *sideButtonActions;

+ (void)initialize {
    
    if (self == [AppDelegate class]) {
        
        // I think this is the entrypoint of the app
        
        // Setup CocoaLumberjack
        [SharedUtility setupBasicCocoaLumberjackLogging];
        DDLogInfo(@"Main App starting up...");     
        
        // Remove restart the app untranslocated if it's currently translocated
        [AppTranslocationManager removeTranslocation]; // Need to call this before MessagePort_App is initialized, otherwise stuff breaks if app is translocated
        // Start parts of the app that depend on the initialization we just did
        [MessagePort_App load_Manual];
        
        // Do unnecessary stuff
        // TODO: Remove the unused stuff below
        
        _scrollConfigurations = @{ // This is unused
            @"Normal"   :   @[ @[@20,@80],  @130, @1.5],
        };
        
        sideButtonActions =
        @{
            @1 :
                @[
                    @[@"symbolicHotKey", @79],
                    @[@"symbolicHotKey", @81]
                ],
            @2  :
                @[
                    @[@"swipeEvent", @"left"],
                    @[@"swipeEvent", @"right"]
                ]
        };
    }
    
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification {

}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    
    DDLogInfo(@"Mac Mouse Fix finished launching");
    
    /// Do weird tweaks for Ventura
    ///     It seems that NSBox adds horizontal padding of 1 px around its contentView in Ventura (Beta). Here we compensate for that.
    ///     Pre-big sur also looks weird but in a different way. See https://github.com/noah-nuebling/mac-mouse-fix/issues/269
    if (@available(macOS 13, *)) {
        self.preferenceBox.contentViewMargins = NSMakeSize(-1, 0);
    }
    
    /// Load UI
    
    [self updateUI];
    
    /// Update app-launch counters
    
    NSInteger launchesOverall;
    NSInteger launchesOfCurrentBundleVersion;
    
    launchesOverall = [config(@"Other.launchesOverall") integerValue];
    launchesOfCurrentBundleVersion = [config(@"Other.launchesOfCurrentBundleVersion") integerValue];
    NSInteger lastLaunchedBundleVersion = [config(@"Other.lastLaunchedBundleVersion") integerValue];
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
    
    BOOL checkForUpdates = [config(@"Other.checkForUpdates") boolValue];
    
    BOOL checkForPrereleases = [config(@"Other.checkForPrereleases") boolValue];
    
    if (firstVersionLaunch && !appState().updaterDidRelaunchApplication) {
        /// TODO: Test if updaterDidRelaunchApplication works.
        ///  It will only work if `SparkleUpdaterDelegate - updaterDidRelaunchApplication:` is called before this
        /// The app (or this version of it) has probably been downloaded from the internet and is running for the first time.
        ///  -> Override check-for-prereleases setting
        if (SharedUtility.runningPreRelease) {
            /// If this is a pre-release version itself, we activate updates to pre-releases
            checkForPrereleases = YES;
        } else {
            /// If this is not a pre-release, then we'll *deactivate* updates to pre-releases
            checkForPrereleases = NO;
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
    [OverridePanel.instance end];
    [MoreSheet.instance end]; // Doesn't help quitting while more sheet is up 
    return NSTerminateNow;
}

NSTimer *removeAccOverlayTimer;
- (void)removeAccOverlayTimerCallback {
    [AuthorizeAccessibilityView remove];
}
- (void)handleAccessibilityDisabledMessage {
    [AuthorizeAccessibilityView add];
    [removeAccOverlayTimer invalidate];
}
- (void)windowDidBecomeKey:(NSNotification *)notification {
    [SharedMessagePort sendMessage:@"checkAccessibility" withPayload:nil expectingReply:NO];
    if (@available(macOS 10.12, *)) { // Use a delay to prevent jankyness when window becomes key while app is requesting accessibility. Use timer so it can be stopped once Helper sends "I still have no accessibility" message
        removeAccOverlayTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:NO block:^(NSTimer * _Nonnull timer) {
            [self removeAccOverlayTimerCallback];
        }];
    } else { // Fallback on earlier versions
        removeAccOverlayTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(removeAccOverlayTimerCallback) userInfo:nil repeats:NO];
    }
}

- (void)windowWillClose:(NSNotification *)notification {
//    [UpdateWindow.instance close]; Can't find a way to close Sparkle Window
    [OverridePanel.instance close];
    [MoreSheet.instance end];
}

- (BOOL) applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app {
    return YES;
}

#pragma mark - UI Logic

- (BOOL)UIDisabled {
    return !self.enableMouseFixCheckBox.state;
}
- (void)enableUI:(BOOL)enb {
    
    /// Get state
    self.enableMouseFixCheckBox.state = enb;
    
    /// Get superview of all the controls we want to disable
    NSView *baseView = [self.window.contentView subviewsWithIdentifier:@"baseView"][0];
    NSBox *preferenceBox = (NSBox *)[baseView subviewsWithIdentifier:@"preferenceBox"][0]; /// Should use outlets instead of this
    
    /// Iterate through and enable everything
    NSArray<NSView *> *recursiveSubviews = [preferenceBox.contentView nestedSubviews];
    for (NSObject *v in recursiveSubviews) {
        if ([[v class] isSubclassOfClass:[NSControl class]]) {
            [(NSControl *)v setEnabled:enb];
        }
    }
    /// Forgot what this does
    if (enb) {
        [self disableScrollSettings:@(_scrollEnableCheckBox.state)];
    }
}
- (void)disableScrollSettings:(NSNumber *)enable {
    _scrollStepSizeSlider.enabled = enable.boolValue;
}

- (void)updateUI {
    
    DDLogInfo(@"Setting Enable Mac Mouse Fix checkbox to: %hhd", [HelperServices helperIsActive]);
    
#pragma mark other
    /// enableCheckbox
    BOOL enable = HelperServices.helperIsActive;
//    _enableMouseFixCheckBox.state = enable ? 1 : 0;
    [self enableUI:enable];
    
    [ConfigInterface_App loadConfigFromFile];
    
# pragma mark scrollSettings
    
    NSDictionary *scrollConfigFromFile = ConfigInterface_App.config[kMFConfigKeyScroll];
    
    // Enabled checkbox
    if ([scrollConfigFromFile[@"smooth"] boolValue] == 1) {
        _scrollEnableCheckBox.state = 1;
    }
    else {
        _scrollEnableCheckBox.state = 0;
    }
    
    // Invert checkbox
    _invertScrollCheckBox.state = [scrollConfigFromFile[@"direction"] integerValue] == -1 ? 1 : 0;
    
    NSString *activeScrollSmoothnessConfiguration = @"Normal";
    
    // Slider
    double pxStepSizeRelativeToConfigRange;
    NSArray *range = _scrollConfigurations[activeScrollSmoothnessConfiguration][0];
    double lowerLm = [range[0] floatValue];
    double upperLm = [range[1] floatValue];
    NSDictionary *smoothSettings = scrollConfigFromFile[@"smoothParameters"];
    double pxStepSize = [smoothSettings[@"pxPerStep"] floatValue];
    pxStepSizeRelativeToConfigRange = (pxStepSize - lowerLm) / (upperLm - lowerLm);
    
    _scrollStepSizeSlider.doubleValue = pxStepSizeRelativeToConfigRange;
    
}

- (void)setConfigFileToUI {
    
    
    // Scroll Settings
    
    // radio buttons and slider
    NSArray *smoothnessConfiguration;
    
    smoothnessConfiguration = _scrollConfigurations[@"Normal"]; 
    
    NSArray     *stepSizeRange  = smoothnessConfiguration[0];
//    NSNumber    *msPerStep      = smoothnessConfiguration[1];
//    NSNumber    *friction       = smoothnessConfiguration[2];
    int    		direction      = _invertScrollCheckBox.intValue ? -1 : 1;
    
    float scrollSliderValue = [_scrollStepSizeSlider floatValue];
    int stepSizeMin = [stepSizeRange[0] intValue];
    int stepSizeMax = [stepSizeRange[1] intValue];
    
    int stepSizeActual = ( scrollSliderValue * (stepSizeMax - stepSizeMin) ) + stepSizeMin;
    
    NSDictionary *scrollParametersFromUI = @{
        kMFConfigKeyScroll: @{
                @"smooth": @(_scrollEnableCheckBox.state),
                @"direction": @(direction),
                @"smoothParameters": @{
                        @"pxPerStep": @(stepSizeActual),
//                        @"msPerStep": msPerStep,
//                        @"friction": friction
            }
        }
    };
    
    
    ConfigInterface_App.config = [[SharedUtility dictionaryWithOverridesAppliedFrom:scrollParametersFromUI to:ConfigInterface_App.config] mutableCopy];
    
    [ConfigInterface_App writeConfigToFileAndNotifyHelper];
}

@end
