//
// --------------------------------------------------------------------------
// AppDelegate.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

// implement checkbox functionality, setup AddingField mouse tracking and other minor stuff

#import <PreferencePanes/PreferencePanes.h>
#import "AppDelegate.h"
#import "ConfigFileInterface_App.h"
#import "SharedMessagePort.h"
#import "Utility_App.h"
#import "AuthorizeAccessibilityView.h"
#import "HelperServices.h"
#import "SharedUtility.h"
#import "MFNotificationController.h"
#import "NSView+Additions.h"
#import "AppTranslocationManager.h"
#import "MessagePort_App.h"
#import <Sparkle/Sparkle.h>

@interface AppDelegate ()

@property (strong) IBOutlet NSWindow *window;

@property (weak) IBOutlet NSButton *enableMouseFixCheckBox;

@property (weak) IBOutlet NSButton *scrollEnableCheckBox;

@property (weak) IBOutlet NSSlider *scrollStepSizeSlider;
@property (weak) IBOutlet NSButton *invertScrollCheckBox;

@end

@implementation AppDelegate

# pragma mark - IBActions

- (IBAction)enableCheckBox:(id)sender {
    
    BOOL checkboxState = [sender state];
    [HelperServices enableHelperAsUserAgent: checkboxState];
    [self performSelector:@selector(disableUI:) withObject:@(_enableMouseFixCheckBox.state) afterDelay:0.0];
}
- (IBAction)moreButton:(id)sender {
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
+ (void)handleHelperEnabledMessage {
    NSButton *checkBox = self.instance.enableMouseFixCheckBox;
    if (checkBox.state == 0) {
        checkBox.state = 1;
        [self.instance disableUI:@(1)];
    }
}
- (RemapTableController *)remapTableController {
    RemapTableController *controller = (RemapTableController *)self.remapsTable.delegate;
    return controller;
}

#pragma mark - Init and Lifecycle

// Define Globals
static NSDictionary *_scrollConfigurations;
static NSDictionary *sideButtonActions;

+ (void)initialize {
    
    if (self == [AppDelegate class]) {
        
        [AppTranslocationManager removeTranslocation]; // Need to call this before MessagePort_App is initialized, otherwise stuff breaks if app is translocated
        [MessagePort_App load_Manual];
        
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
        
        //
    }
    
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification {

}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    
    NSLog(@"Mac Mouse Fix finished launching");
    
    // Load UI
    
    [self setUIToConfigFile];
    
    // Update app-launch counters
    
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
    
    
    BOOL firstAppLaunch = launchesOverall == 1; // App is launched for the first time
    BOOL firstVersionLaunch = launchesOfCurrentBundleVersion == 1; // Last time that the app was launched was a different bundle version
    
    // Configure Sparkle Updater
    //  (See https://sparkle-project.org/documentation/customization/)
    
    SUUpdater *up = SUUpdater.sharedUpdater;
    
    up.automaticallyChecksForUpdates = NO;
    up.sendsSystemProfile = NO;
    up.automaticallyDownloadsUpdates = NO;
    
    BOOL checkForUpdates = [config(@"Other.checkForUpdates") boolValue];
    
    BOOL checkForPrereleases = [config(@"Other.checkForPrereleases") boolValue];
    
    if (firstVersionLaunch && !appState().updaterDidRelaunchApplication) {
        // TODO: Test if updaterDidRelaunchApplication works.
        //  It will only work if `SparkleUpdaterDelegate - updaterDidRelaunchApplication:` is called before this
        // The app (or this version of it) has probably been downloaded from the internet and is running for the first time.
        //  -> Override check-for-prereleases setting
        if (SharedUtility.runningPreRelease) {
            // If this is a pre-release version itself, we activate updates to pre-releases
            checkForPrereleases = YES;
        } else {
            // If this is not a pre-release, then we'll *deactivate* updates to pre-releases
            checkForPrereleases = NO;
        }
        setConfig(@"Other.checkForPrereleases", @(checkForPrereleases));
    }
    
    // Write changes to we made to config through setConfig() to file. Also notifies helper app, which is probably unnecessary.
    commitConfig();
    
    // Check for udates
    
    if (checkForUpdates) {
        
        NSString *feedURLString;
        
        if (checkForPrereleases) {
            feedURLString = fstring(@"%@/%@", kMFRawRepoAddress, kSUFeedURLSubBeta);
        } else {
            feedURLString = fstring(@"%@/%@", kMFRawRepoAddress, kSUFeedURLSub);
        }
        
        up.feedURL = [NSURL URLWithString:feedURLString];
        
        [up checkForUpdatesInBackground];
    }
    
}
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    NSLog(@"Mac Mouse Fix should terminate");
    [OverridePanel.instance end];
    [MoreSheet.instance end]; // Doesn't help quitting while more sheet is up 
    return NSTerminateNow;
}

// Use a delay to prevent jankyness when window becomes key while app is requesting accessibility. Use timer so it can be stopped once Helper sends "I still have no accessibility" message
NSTimer *removeAccOverlayTimer;
- (void)removeAccOverlayTimerCallback {
    [AuthorizeAccessibilityView remove];
}
- (void)stopRemoveAccOverlayTimer {
    [removeAccOverlayTimer invalidate];
}
- (void)windowDidBecomeKey:(NSNotification *)notification {
    [SharedMessagePort sendMessage:@"checkAccessibility" withPayload:nil expectingReply:NO];
    if (@available(macOS 10.12, *)) {
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

- (void)disableUI:(NSNumber *)enable {
    
    BOOL enb = enable.boolValue;
    
    NSView *baseView = [self.window.contentView subviewsWithIdentifier:@"baseView"][0];
    NSBox *preferenceBox = (NSBox *)[baseView subviewsWithIdentifier:@"preferenceBox"][0]; // Should use outlets instead of this
    
    
    NSArray<NSView *> *recursiveSubviews = [preferenceBox.contentView nestedSubviews];
    for (NSObject *v in recursiveSubviews) {
        if ([[v class] isSubclassOfClass:[NSControl class]]) {
            [(NSControl *)v setEnabled:enb];
        }
    }
    if (enb) {
        [self disableScrollSettings:@(_scrollEnableCheckBox.state)];
    }
}
- (void)disableScrollSettings:(NSNumber *)enable {
    _scrollStepSizeSlider.enabled = enable.boolValue;
}

/// TODO: Rename to loadUIFromConfigFile - this is confusing
- (void)setUIToConfigFile {
    
    NSLog(@"Setting Enable Mac Mouse Fix checkbox to: %hhd", [HelperServices helperIsActive]);
    
#pragma mark other
    // enableCheckbox
    if (HelperServices.helperIsActive) {
        _enableMouseFixCheckBox.state = 1;
    } else {
        _enableMouseFixCheckBox.state = 0;
    }
    
    [ConfigFileInterface_App loadConfigFromFile];
    
# pragma mark scrollSettings
    
    NSDictionary *scrollConfigFromFile = ConfigFileInterface_App.config[kMFConfigKeyScroll];
    
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
    
    [self performSelector:@selector(disableUI:) withObject:@(_enableMouseFixCheckBox.state) afterDelay:0.0];
    
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
    
    
    ConfigFileInterface_App.config = [[SharedUtility dictionaryWithOverridesAppliedFrom:scrollParametersFromUI to:ConfigFileInterface_App.config] mutableCopy];
    
    [ConfigFileInterface_App writeConfigToFileAndNotifyHelper];
}

@end
