

// implement checkbox functionality, setup AddingField mouse tracking and other minor stuff

#import <PreferencePanes/PreferencePanes.h>
#import <ServiceManagement/SMLoginItem.h>
#import "PrefPaneDelegate.h"
#import "Updater.h"
#import "Config/ConfigFileInterfacePref.h"
#import "Helper/HelperInterface.h"
//#import "CGSInternal/CGSHotKeys.h"

@interface PrefPaneDelegate ()

@property (retain) NSBundle *helperBundle;

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
@property (weak) IBOutlet NSPopUpButton *sideHold;


@property (strong) IBOutlet NSPanel *sheetPanel;
@property (weak) IBOutlet NSTextField *versionLabel;
@property (weak) IBOutlet NSButton *checkForUpdateCheckBox;


@property (weak) IBOutlet NSButton *doneButton;

@end

@implementation PrefPaneDelegate

static NSDictionary *_scrollSmoothnessConfigurations;
static NSDictionary *actionsForPopupButtonTag_onlyForSideMouseButtons;

# pragma mark - IBActions

# pragma mark main screen

- (IBAction)enableCheckBox:(id)sender {
    
    //sendKeyUpForAllSymbolicHotKeysThatAMouseButtonMapsTo(self);
    
    BOOL checkboxState = [sender state];
    [HelperInterface enableHelperAsUserAgent: checkboxState];
    
}
- (IBAction)moreButton:(id)sender {
    
    [[[NSApplication sharedApplication] mainWindow] beginSheet:_sheetPanel completionHandler:nil];
}

# pragma mark more panel

- (IBAction)checkForUpdateCheckBox:(NSButton *)sender {
    
    if (sender.state == 1) {
        [Updater checkForUpdate];
    }
    [self UIChanged:NULL];
}
- (IBAction)milkshakeButton:(id)sender {
    NSLog(@"BUTTTON");
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=ARSTVR6KFB524&source=url"]];
}
- (IBAction)doneButton:(id)sender {
    [[[NSApplication sharedApplication] mainWindow] endSheet:_sheetPanel];
}

- (IBAction)UIChanged:(id)sender {
    [self setConfigToUI];
    [HelperInterface tellHelperToUpdateItsSettings];
}



# pragma mark - main

+ (void)initialize {
    if (self == [PrefPaneDelegate class]) {
        _scrollSmoothnessConfigurations = @{
                                            @"Normal"   :   @[ @[@20,@100],  @130, @1.5],
                                            @"Snappy"   :   @[ @[@10,@90],  @75,  @1.2],
                                            @"Smooth"   :   @[ @[@10,@90], @190, @1.5],
                                            
                                            };
        
        actionsForPopupButtonTag_onlyForSideMouseButtons = @{
                                                             @1          :   @[ @[@"symbolicHotKey", @79    ], @[@"symbolicHotKey", @81     ]],
                                                             @2          :   @[ @[@"swipeEvent"   , @"left"], @[@"swipeEvent"   , @"right"]] };
    }
    
}


- (void)mainViewDidLoad {
    NSLog(@"PREF PANEEE");
    
    [self initializeUI];
    
    [Updater checkForUpdate];
}


- (void)initializeUI {
    
#pragma mark other
    // enableCheckbox
    if (HelperInterface.helperIsActive) {
        [_enableCheckBox setState: 1];
    } else {
        [_enableCheckBox setState: 0];
    }
    
# pragma mark Popup Buttons
    
    NSDictionary *buttonRemaps = ConfigFileInterfacePref.config[@"ButtonRemaps"];
    
    // mouse button 4 and 5
    NSLog(@"buttonRemaps: %@", buttonRemaps);
    
    // click
    long i;
    NSString *eventTypeSideClick = buttonRemaps[@"4"][@"click"][0];
    
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
    NSString *eventTypeSideHold = buttonRemaps[@"4"][@"hold"][0];
    if ([eventTypeSideHold isEqualToString:@"swipeEvent"]) {
        j = 2;
    }
    else if ([eventTypeSideHold isEqualToString:@"symbolicHotKey"]) {
        j = 1;
    }
    else {
        j = 0;
    }
    [_sideHold selectItemWithTag: j];
    
    
    // middle mouse button
    
    NSDictionary *middleButtonRemap = buttonRemaps[@"3"];
    
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
    
    NSDictionary *scrollConfigFromFile = ConfigFileInterfacePref.config[@"ScrollSettings"];
    
    // enabled checkbox
    if ([scrollConfigFromFile[@"enabled"] boolValue] == 1) {
        _scrollEnableCheckBox.state = 1;
    }
    else {
        _scrollEnableCheckBox.state = 0;
    }
    
    NSArray *scrollValues = scrollConfigFromFile[@"values"];
    
    // invert checkbox
    if ([scrollValues[3] intValue] == -1) {
        _scrollCheckBoxInvert.state = 1;
    } else {
        _scrollCheckBoxInvert.state = 0;
    }
    
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
    NSArray *range = _scrollSmoothnessConfigurations[activeScrollSmoothnessConfiguration][0];
    double lowerLm = [range[0] floatValue];
    double upperLm = [range[1] floatValue];
    double pxStepSize = [scrollValues[0] floatValue];
    pxStepSizeRelativeToConfigRange = (pxStepSize - lowerLm) / (upperLm - lowerLm);
    
    _scrollSliderStepSize.doubleValue = pxStepSizeRelativeToConfigRange;
    
    
    
#pragma mark Sheet
    
    NSString *versionString = [NSString stringWithFormat:@"Version %@ (%@)",
                               [[NSBundle bundleForClass:[self class]] objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
                               [[NSBundle bundleForClass:[self class]] objectForInfoDictionaryKey:@"CFBundleVersion"]];
    [_versionLabel setStringValue:versionString];
    
    _checkForUpdateCheckBox.state = [[ConfigFileInterfacePref.config valueForKeyPath:@"other.checkForUpdates"] boolValue];
    
}


- (void)setConfigToUI {
    
    NSLog(@"SET CONFIG TO UI");
    
    // middle button        // tag equals symbolicHotKey
    
    // click
    
    
    NSArray *middleButtonClickAction;
    if (_middleClick.selectedTag != 0) {
        middleButtonClickAction= @[@"symbolicHotKey", @(_middleClick.selectedTag)];
    }
    [ConfigFileInterfacePref.config setValue:middleButtonClickAction forKeyPath:@"ButtonRemaps.3.click"];
    
    // hold
    NSArray *middleButtonHoldAction;
    if (_middleHold.selectedTag != 0) {
        middleButtonHoldAction = @[@"symbolicHotKey", @(_middleHold.selectedTag)];
    }
    [ConfigFileInterfacePref.config setValue:middleButtonHoldAction forKeyPath:@"ButtonRemaps.3.hold"];
    
    
    // side buttons         // tag = 1 -> Switch Spaces, tag = 2 -> Switch Pages
    
    // click
    NSArray *sideButtonClickAction = [actionsForPopupButtonTag_onlyForSideMouseButtons objectForKey:@(_sideClick.selectedTag)];
    [ConfigFileInterfacePref.config setValue:sideButtonClickAction[0] forKeyPath:@"ButtonRemaps.4.click"];
    [ConfigFileInterfacePref.config setValue:sideButtonClickAction[1] forKeyPath:@"ButtonRemaps.5.click"];
    
    // hold
    NSArray *sideButtonHoldAction = [actionsForPopupButtonTag_onlyForSideMouseButtons objectForKey:@(_sideHold.selectedTag)];
    [ConfigFileInterfacePref.config setValue:sideButtonHoldAction[0] forKeyPath:@"ButtonRemaps.4.hold"];
    [ConfigFileInterfacePref.config setValue:sideButtonHoldAction[1] forKeyPath:@"ButtonRemaps.5.hold"];
    
    
    
    // scroll Settings
    
    // checkbox
    [ConfigFileInterfacePref.config setValue: [NSNumber numberWithBool: _scrollEnableCheckBox.state] forKeyPath:@"ScrollSettings.enabled"];
    
    
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
    smoothnessConfiguration = _scrollSmoothnessConfigurations[@"Normal"];
    
    NSArray     *stepSizeRange  = smoothnessConfiguration[0];
    NSNumber    *msPerStep      = smoothnessConfiguration[1];
    NSNumber    *friction       = smoothnessConfiguration[2];
    int    		direction      = _scrollCheckBoxInvert.intValue ? -1 : 1;
    
    float scrollSliderValue = [_scrollSliderStepSize floatValue];
    int stepSizeMin = [stepSizeRange[0] intValue];
    int stepSizeMax = [stepSizeRange[1] intValue];
    
    int stepSizeActual = ( scrollSliderValue * (stepSizeMax - stepSizeMin) ) + stepSizeMin;
    
    NSArray *scrollValuesFromUI = @[@(stepSizeActual), msPerStep, friction, @(direction)];
    
    [ConfigFileInterfacePref.config setValue:scrollValuesFromUI forKeyPath:@"ScrollSettings.values"];
    
    
    // other
    [ConfigFileInterfacePref.config setValue:[NSNumber numberWithBool:_checkForUpdateCheckBox.state] forKeyPath:@"other.checkForUpdates"];
    
    
    
    
    [ConfigFileInterfacePref writeConfigToFile];
}

@end
