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
#import <ServiceManagement/SMLoginItem.h>
#import "AppDelegate.h"
#import "Updater.h"
#import "Config/ConfigFileInterface_App.h"
#import "Helper/HelperServices.h"
#import "MessagePort/MessagePort_App.h"
#import "Update/UpdateWindow.h"
#import "Utility/Utility_App.h"
//#import "CGSInternal/CGSHotKeys.h"

#import "Accessibility/AuthorizeAccessibilityView.h"

@interface AppDelegate ()

@property (strong) IBOutlet NSWindow *window;

@property (weak) IBOutlet NSButton *enableCheckBox;


@property (weak) IBOutlet NSButton *scrollEnableCheckBox;

/*
@property (weak) IBOutlet NSButton *scrollRadioButtonNormal;
@property (weak) IBOutlet NSButton *scrollRadioButtonSnappy;
@property (weak) IBOutlet NSButton *scrollRadioButtonSmooth;
 */

@property (weak) IBOutlet NSSlider *scrollSliderStepSize;
@property (weak) IBOutlet NSButton *scrollCheckBoxInvert;

@property (weak) IBOutlet NSPopUpButton *middleClick;
@property (weak) IBOutlet NSPopUpButton *middleHold;
@property (weak) IBOutlet NSPopUpButton *sideClick;
//@property (weak) IBOutlet NSPopUpButton *sideHold;


@end

@implementation AppDelegate

# pragma mark - IBActions

- (IBAction)enableCheckBox:(id)sender {
    //sendKeyUpForAllSymbolicHotKeysThatAMouseButtonMapsTo(self);
    BOOL checkboxState = [sender state];
    [HelperServices enableHelperAsUserAgent: checkboxState];
    [self performSelector:@selector(disableUI:) withObject:[NSNumber numberWithBool:_enableCheckBox.state] afterDelay:0.0];
    
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

#pragma mark - Init and Lifecycle

// Define Globals
static NSDictionary *_scrollConfigurations;
static NSDictionary *actionsForPopupButtonTag_onlyForSideMouseButtons;

+ (void)initialize {
    
    if (self == [AppDelegate class]) {
        
        // TODO: Update this
        _scrollConfigurations = @{                                          // last two are unused now
            @"Normal"   :   @[ @[@20,@80],  @130, @1.5],
                                    // @"Normal"   :   @[ @[@20,@100],  @130, @1.5]
            @"Snappy"   :   @[ @[@10,@90],  @75,  @1.2],
            @"Smooth"   :   @[ @[@10,@90], @190, @1.5],
        };
        
        actionsForPopupButtonTag_onlyForSideMouseButtons =
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


- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    
    NSLog(@"PREF PANEEE");
    
    [self setUIToConfigFile];
    
    BOOL checkForUpdates = [[ConfigFileInterface_App.config valueForKeyPath:@"Other.checkForUpdates"] boolValue];
    if (checkForUpdates == YES) {
        [Updater checkForUpdate];
    }
}

// Use a delay to prevent jankyness when window becomes key while app is requesting accessibility. Use timer so it can be stopped once Helper sends "I still have no accessibility" message
NSTimer *removeAccOverlayTimer;
- (void)stopRemoveAccOverlayTimer {
    [removeAccOverlayTimer invalidate];
}
- (void)windowDidBecomeKey:(NSNotification *)notification {
    [MessagePort_App performSelector:@selector(sendMessageToHelper:) withObject:@"checkAccessibility" afterDelay:0.0];
    removeAccOverlayTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:NO block:^(NSTimer * _Nonnull timer) {
        [AuthorizeAccessibilityView remove];
    }];
}
- (void)windowDidResignKey:(NSNotification *)notification { // This made sense when using prefpane (used to be called when it was unselected)
//    [UpdateWindow.instance close];
//    [MoreSheet.instance end];
//    [ScrollOverridePanel.instance close];
}

-(BOOL) applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app {
    return YES;
}

#pragma mark - UI Logic

- (void)disableUI:(NSNumber *)enable {
    
    BOOL enb = enable.boolValue;
    
    NSArray *baseArray = [Utility_App subviewsForView:self.window.contentView withIdentifier:@"baseView"];
    NSView *baseView = baseArray[0];
    NSBox *preferenceBox = (NSBox *)[Utility_App subviewsForView:baseView withIdentifier:@"preferenceBox"][0];
    
    for (NSObject *v in preferenceBox.contentView.subviews) {
        if ([[v class] isSubclassOfClass:[NSControl class]]) {
            [(NSControl *)v setEnabled:enb];
        }
    }
    if (enb) {
        [self disableScrollSettings:@(_scrollEnableCheckBox.state)];
    }
}
- (void)disableScrollSettings:(NSNumber *)enable {
    _scrollSliderStepSize.enabled = enable.boolValue;
}

- (void)setUIToConfigFile {
    
    NSLog(@"helperactiveEEEEEE: %hhd", HelperServices.helperIsActive);
    
#pragma mark other
    // enableCheckbox
    if (HelperServices.helperIsActive) {
        _enableCheckBox.state = 1;
    } else {
        _enableCheckBox.state = 0;
    }
    
    [ConfigFileInterface_App loadConfigFromFile];
    
# pragma mark Popup Buttons
    
    NSDictionary *buttonRemaps = ConfigFileInterface_App.config[@"ButtonRemaps"];
    
    // mouse button 4 and 5
    
    // click
    long i;
    NSString *eventTypeSideClick = buttonRemaps[@"4"][@"single"][@"click"][0];
    
    if ([eventTypeSideClick isEqualToString:@"swipeEvent"]) {
        i = 2;
    }
    else if ([eventTypeSideClick isEqualToString:@"symbolicHotKey"]) {
        i = 1;
    }
    else {
        i = 0;
    }
    [_sideClick selectItemWithTag: i];
    
    // hold
    long j;
    NSString *eventTypeSideHold = buttonRemaps[@"4"][@"single"][@"hold"][0];
    if ([eventTypeSideHold isEqualToString:@"swipeEvent"]) {
        j = 2;
    }
    else if ([eventTypeSideHold isEqualToString:@"symbolicHotKey"]) {
        j = 1;
    }
    else {
        j = 0;
    }
    
    // middle mouse button
    
    NSDictionary *middleButtonRemap = buttonRemaps[@"3"][@"single"];
    
    // click
    NSInteger symbolicHotKeyMiddleClick = [middleButtonRemap[@"click"][1] integerValue];
    if (symbolicHotKeyMiddleClick) {
        [_middleClick selectItemWithTag: symbolicHotKeyMiddleClick];
    }
    else {
        [_middleClick selectItemWithTag: 0];
    }
    
    // hold
    NSInteger symbolicHotKeyMiddleHold = [middleButtonRemap[@"hold"][1] integerValue];
    if (symbolicHotKeyMiddleHold) {
        [_middleHold selectItemWithTag: symbolicHotKeyMiddleHold];
    }
    else {
        [_middleHold selectItemWithTag: 0];
    }
    
# pragma mark scrollSettings
    
    NSDictionary *scrollConfigFromFile = ConfigFileInterface_App.config[@"Scroll"];
    
    // enabled checkbox
    if ([scrollConfigFromFile[@"smooth"] boolValue] == 1) {
        _scrollEnableCheckBox.state = 1;
    }
    else {
        _scrollEnableCheckBox.state = 0;
    }
    
//    NSArray *scrollValues = scrollConfigFromFile[@"smoothSettings"];
    
    // invert checkbox
    _scrollCheckBoxInvert.state = [scrollConfigFromFile[@"direction"] integerValue];
    
    // radio buttons
    /*
     NSString *activeScrollSmoothnessConfiguration;
     if (([scrollValues[1] intValue] == [_scrollSmoothnessConfigurations[@"Smooth"][1] intValue]) &&           // msPerStep
     ([scrollValues[2] floatValue] == [_scrollSmoothnessConfigurations[@"Smooth"][2] floatValue] )) {           // friction
     _scrollRadioButtonSmooth.state = 1;
     activeScrollSmoothnessConfiguration = @"Smooth";
     }
     
     else if (([scrollValues[1] intValue] == [_scrollSmoothnessConfigurations[@"Snappy"][1] intValue]) &&
     ([scrollValues[2] floatValue] == [_scrollSmoothnessConfigurations[@"Snappy"][2] floatValue] )) {
     _scrollRadioButtonSnappy.state = 1;
     activeScrollSmoothnessConfiguration = @"Snappy";
     }
     else {
     _scrollRadioButtonNormal.state = 1;
     activeScrollSmoothnessConfiguration = @"Normal";
     }
     */
    NSString *activeScrollSmoothnessConfiguration = @"Normal";
    
    
    // slider
    double pxStepSizeRelativeToConfigRange;
    NSArray *range = _scrollConfigurations[activeScrollSmoothnessConfiguration][0];
    double lowerLm = [range[0] floatValue];
    double upperLm = [range[1] floatValue];
    NSDictionary *smoothSettings = scrollConfigFromFile[@"smoothParameters"];
    double pxStepSize = [smoothSettings[@"pxPerStep"] floatValue];
    pxStepSizeRelativeToConfigRange = (pxStepSize - lowerLm) / (upperLm - lowerLm);
    
    _scrollSliderStepSize.doubleValue = pxStepSizeRelativeToConfigRange;
    
    [self performSelector:@selector(disableUI:) withObject:[NSNumber numberWithBool:_enableCheckBox.state] afterDelay:0.0];
    
}

- (void)setConfigFileToUI {
    
    // middle button        // tag equals symbolicHotKey
    
    // click
    
    
    NSArray *middleButtonClickAction;
    if (_middleClick.selectedTag != 0) {
        middleButtonClickAction= @[@"symbolicHotKey", @(_middleClick.selectedTag)];
    }
    [ConfigFileInterface_App.config setValue:middleButtonClickAction forKeyPath:@"ButtonRemaps.3.single.click"];
    
    // hold
    NSArray *middleButtonHoldAction;
    if (_middleHold.selectedTag != 0) {
        middleButtonHoldAction = @[@"symbolicHotKey", @(_middleHold.selectedTag)];
    }
    [ConfigFileInterface_App.config setValue:middleButtonHoldAction forKeyPath:@"ButtonRemaps.3.single.hold"];
    
    
    // side buttons         // tag = 1 -> Switch Spaces, tag = 2 -> Switch Pages
    
    // click
    NSArray *sideButtonClickAction = [actionsForPopupButtonTag_onlyForSideMouseButtons objectForKey:@(_sideClick.selectedTag)];
    [ConfigFileInterface_App.config setValue:sideButtonClickAction[0] forKeyPath:@"ButtonRemaps.4.single.click"];
    [ConfigFileInterface_App.config setValue:sideButtonClickAction[1] forKeyPath:@"ButtonRemaps.5.single.click"];
    
    // scroll Settings
    
    // radio buttons and slider
    NSArray *smoothnessConfiguration;
    
    /*
    if (_scrollRadioButtonSmooth.state == 1) {
        smoothnessConfiguration = _scrollSmoothnessConfigurations[@"Smooth"];
    }
    else if (_scrollRadioButtonSnappy.state == 1) {
        smoothnessConfiguration = _scrollSmoothnessConfigurations[@"Snappy"];
    }
    else {
        smoothnessConfiguration = _scrollSmoothnessConfigurations[@"Normal"];
    }
     */
    smoothnessConfiguration = _scrollConfigurations[@"Normal"]; 
    
    NSArray     *stepSizeRange  = smoothnessConfiguration[0];
//    NSNumber    *msPerStep      = smoothnessConfiguration[1];
//    NSNumber    *friction       = smoothnessConfiguration[2];
    int    		direction      = _scrollCheckBoxInvert.intValue ? -1 : 1;
    
    float scrollSliderValue = [_scrollSliderStepSize floatValue];
    int stepSizeMin = [stepSizeRange[0] intValue];
    int stepSizeMax = [stepSizeRange[1] intValue];
    
    int stepSizeActual = ( scrollSliderValue * (stepSizeMax - stepSizeMin) ) + stepSizeMin;
    
    NSDictionary *scrollParametersFromUI = @{
        @"Scroll": @{
                @"smooth": @(_scrollEnableCheckBox.state),
                @"direction": @(direction),
                @"smoothParameters": @{
                        @"pxPerStep": @(stepSizeActual),
//                        @"msPerStep": msPerStep,
//                        @"friction": friction
            }
        }
    };
    
    
    ConfigFileInterface_App.config = [[Utility_App dictionaryWithOverridesAppliedFrom:scrollParametersFromUI to:ConfigFileInterface_App.config] mutableCopy];
    
    [ConfigFileInterface_App writeConfigToFileAndNotifyHelper];
}

@end
