//
// --------------------------------------------------------------------------
// PrefPaneDelegate.m
// Created for: Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by: Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

// implement checkbox functionality, setup AddingField mouse tracking and other minor stuff

#import <PreferencePanes/PreferencePanes.h>
#import <ServiceManagement/SMLoginItem.h>
#import "PrefPaneDelegate.h"
#import "Updater.h"
#import "Config/ConfigFileInterface_PrefPane.h"
#import "HelperServices/HelperServices.h"
#import "MessagePort/MessagePort_PrefPane.h"
#import "MoreSheet/MoreSheet.h"
#import "Update/UpdateWindow.h"
#import "Utility/Utility_PrefPane.h"
//#import "CGSInternal/CGSHotKeys.h"

#import "Accessibility/AuthorizeAccessibilityView.h"

@interface PrefPaneDelegate ()

@property (strong) IBOutlet NSView *mainView;

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
@property (weak) IBOutlet NSButton *sideInvertedCheckBox;
//@property (weak) IBOutlet NSPopUpButton *sideHold;

@property (strong) MoreSheet *moreSheetDelegate;


@end

@implementation PrefPaneDelegate

@dynamic mainView;
static PrefPaneDelegate *_mainView;
+ (PrefPaneDelegate *)mainView {
    return _mainView;
}
+ (void)setMainView:(PrefPaneDelegate *)new {
    _mainView = new;
}

static NSDictionary *_scrollSmoothnessConfigurations;
static NSDictionary *actionsForPopupButtonTag_onlyForSideMouseButtons;


# pragma mark - IBActions

# pragma mark main screen

- (IBAction)enableCheckBox:(id)sender {
    
    //sendKeyUpForAllSymbolicHotKeysThatAMouseButtonMapsTo(self);
    BOOL checkboxState = [sender state];
    [HelperServices enableHelperAsUserAgent: checkboxState];
    [self performSelector:@selector(disableUI:) withObject:[NSNumber numberWithBool:_enableCheckBox.state] afterDelay:0.0];
    
}
- (IBAction)moreButton:(id)sender {
    [_moreSheetDelegate begin];
}
- (IBAction)scrollEnableCheckBox:(id)sender {
    [self disableScrollSettings:@(_scrollEnableCheckBox.state)];
    [self UIChanged:NULL];
}

- (IBAction)UIChanged:(id)sender {
    [self setConfigFileToUI];
    [MessagePort_PrefPane sendMessageToHelper:@"configFileChanged"];
}


# pragma mark - main



- (NSView *)loadMainView {
    
    [[NSBundle bundleForClass:self.class] loadNibNamed:@"MouseFix" owner:self topLevelObjects:NULL];
    PrefPaneDelegate.mainView = self.mainView;
    
    [self mainViewDidLoad];
    
    return self.mainView;
}


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
    
    
    _moreSheetDelegate = [[MoreSheet alloc] initWithWindowNibName:@"MoreSheet"];
    
    [self initializeUI];
    
    BOOL checkForUpdates = [[ConfigFileInterface_PrefPane.config valueForKeyPath:@"Other.checkForUpdates"] boolValue];
    if (checkForUpdates == YES) {
        [Updater checkForUpdate];
    }
}

- (void)willSelect {
    [AuthorizeAccessibilityView remove];
    [MessagePort_PrefPane performSelector:@selector(sendMessageToHelper:) withObject:@"checkAccessibility" afterDelay:0.0];
}

- (void)willUnselect {

    [UpdateWindow.instance close];
}

- (void)disableUI:(NSNumber *)enable {
    
    BOOL enb = enable.boolValue;
    
    NSArray *baseArray = [Utility_PrefPane subviewsForView:self.mainView withIdentifier:@"baseView"];
    NSView *baseView = baseArray[0];
    NSBox *preferenceBox = (NSBox *)[Utility_PrefPane subviewsForView:baseView withIdentifier:@"preferenceBox"][0];
    
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

- (void)initializeUI {
    
    NSLog(@"helperactiveEEEEEE: %hhd", HelperServices.helperIsActive);
    
#pragma mark other
    // enableCheckbox
    if (HelperServices.helperIsActive) {
        _enableCheckBox.state = 1;
    } else {
        _enableCheckBox.state = 0;
    }
    
# pragma mark Popup Buttons
    
    NSDictionary *buttonRemaps = ConfigFileInterface_PrefPane.config[@"ButtonRemaps"];
    
    // mouse button 4 and 5
    
    // enabled checkbox
    if ([buttonRemaps[@"sideButtonsInverted"] boolValue] == 1) {
        _sideInvertedCheckBox.state = 1;
    }
    else {
        _sideInvertedCheckBox.state = 0;
    }
    
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
    
    NSDictionary *scrollConfigFromFile = ConfigFileInterface_PrefPane.config[@"ScrollSettings"];
    
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
    
    [self performSelector:@selector(disableUI:) withObject:[NSNumber numberWithBool:_enableCheckBox.state] afterDelay:0.0];
    
}



- (void)setConfigFileToUI {
    
    // middle button        // tag equals symbolicHotKey
    
    // click
    
    
    NSArray *middleButtonClickAction;
    if (_middleClick.selectedTag != 0) {
        middleButtonClickAction= @[@"symbolicHotKey", @(_middleClick.selectedTag)];
    }
    [ConfigFileInterface_PrefPane.config setValue:middleButtonClickAction forKeyPath:@"ButtonRemaps.3.single.click"];
    
    // hold
    NSArray *middleButtonHoldAction;
    if (_middleHold.selectedTag != 0) {
        middleButtonHoldAction = @[@"symbolicHotKey", @(_middleHold.selectedTag)];
    }
    [ConfigFileInterface_PrefPane.config setValue:middleButtonHoldAction forKeyPath:@"ButtonRemaps.3.single.hold"];
    
    
    // side buttons         // tag = 1 -> Switch Spaces, tag = 2 -> Switch Pages
    
    [ConfigFileInterface_PrefPane.config setValue:[NSNumber numberWithBool: _sideInvertedCheckBox.state] forKeyPath:@"ButtonRemaps.sideButtonsInverted"];
    
    // click
    NSArray *sideButtonClickAction = [actionsForPopupButtonTag_onlyForSideMouseButtons objectForKey:@(_sideClick.selectedTag)];
    if (_sideInvertedCheckBox.state == 1) {
        [ConfigFileInterface_PrefPane.config setValue:sideButtonClickAction[0] forKeyPath:@"ButtonRemaps.5.single.click"];
        [ConfigFileInterface_PrefPane.config setValue:sideButtonClickAction[1] forKeyPath:@"ButtonRemaps.4.single.click"];
    } else {
        [ConfigFileInterface_PrefPane.config setValue:sideButtonClickAction[0] forKeyPath:@"ButtonRemaps.4.single.click"];
        [ConfigFileInterface_PrefPane.config setValue:sideButtonClickAction[1] forKeyPath:@"ButtonRemaps.5.single.click"];
    }
    
    // hold
//    NSArray *sideButtonHoldAction = [actionsForPopupButtonTag_onlyForSideMouseButtons objectForKey:@(_sideHold.selectedTag)];
//    [ConfigFileInterface_PrefPane.config setValue:sideButtonHoldAction[0] forKeyPath:@"ButtonRemaps.4.hold"];
//    [ConfigFileInterface_PrefPane.config setValue:sideButtonHoldAction[1] forKeyPath:@"ButtonRemaps.5.hold"];
    
    
    
    // scroll Settings
    
    // checkbox
    [ConfigFileInterface_PrefPane.config setValue: [NSNumber numberWithBool: _scrollEnableCheckBox.state] forKeyPath:@"ScrollSettings.enabled"];
    
    
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
    
    [ConfigFileInterface_PrefPane.config setValue:scrollValuesFromUI forKeyPath:@"ScrollSettings.values"];
    
    
    [ConfigFileInterface_PrefPane writeConfigToFile];
}

@end
