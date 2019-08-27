

// implement checkbox functionality, setup AddingField mouse tracking and other minor stuff

#import <PreferencePanes/PreferencePanes.h>
#import <ServiceManagement/SMLoginItem.h>
#import "PrefPaneDelegate.h"
#import "Updater.h"
//#import "CGSInternal/CGSHotKeys.h"

@interface PrefPaneDelegate ()

@property (retain) NSMutableDictionary *configDictFromFile;
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
@property (weak) IBOutlet NSButton *doneButton;

@end

@implementation PrefPaneDelegate

static NSDictionary *_scrollSmoothnessConfigurations;
static NSDictionary *actionsForPopupButtonTag_onlyForSideMouseButtons;

# pragma mark - IBActions

- (IBAction)enableCheckBox:(id)sender {
    
    //sendKeyUpForAllSymbolicHotKeysThatAMouseButtonMapsTo(self);
    
    BOOL checkboxState = [sender state];
    [self enableHelperAsUserAgent: checkboxState];
    
    // TODO: only update after the user confirmed
    [Updater update];
}
- (IBAction)moreButton:(id)sender {
    
    [[[NSApplication sharedApplication] mainWindow] beginSheet:_sheetPanel completionHandler:nil];
}
- (IBAction)milkshakeButton:(id)sender {
    NSLog(@"BUTTTON");
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=ARSTVR6KFB524&source=url"]];
}
- (IBAction)doneButton:(id)sender {
    [[[NSApplication sharedApplication] mainWindow] endSheet:_sheetPanel];
}



- (IBAction)UIChanged:(id)sender {
    [self setConfigDictToUI];
    tellHelperToUpdateItsSettings();
}



# pragma mark - initialization

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
    
    
    [self loadHelperBundle];
    [self loadConfigDictFromFile];
    
    [self initializeUI];
    
    
    // enableCheckbox
    if (self.helperIsActive) {
        [_enableCheckBox setState: 1];
    } else {
        [_enableCheckBox setState: 0];
     }
    
    //sheetPanel
    NSString *versionString = [NSString stringWithFormat:@"Version %@ (%@)",
                               [[NSBundle bundleForClass:[self class]] objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
                               [[NSBundle bundleForClass:[self class]] objectForInfoDictionaryKey:@"CFBundleVersion"]];
    [_versionLabel setStringValue:versionString];
    
    [Updater checkForUpdate];
}


# pragma mark - Helper Functions

/* registering/unregistering the helper as a User Agent with launchd - also launches/terminates helper */
- (void)enableHelperAsUserAgent:(BOOL)enable {

    // repair config file if checkbox state is changed
    [self repairUserAgentConfigFile];

    /* preparing strings for NSTask and then construct(we'll use NSTask for loading/unloading the helper as a User Agent) */

    /* path for the executable of the launchctl command-line-tool (which can interface with launchd) */
    NSString *launchctlPath = @"/bin/launchctl";
    
    /* preparing arguments for the command-line-tool */
    
    // path to user library
    NSArray *libraryPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    if ([libraryPaths count] == 1) {
        // argument: path to launch-agent-config-file
        NSString *launchAgentPlistPath = [[libraryPaths objectAtIndex:0] stringByAppendingPathComponent: @"LaunchAgents/mouse.fix.helper.plist"];
        
        // if macOS version 10.13+
        if (@available(macOS 10.13, *)) {
            // argument: specifies that the target domain is the current users "gui" domain
            NSString *GUIDomainArgument = [NSString stringWithFormat:@"gui/%d", geteuid()];
            // argument: specifies whether we want to load/unload the helper app
            NSString *OnOffArgument = (enable) ? @"bootstrap": @"bootout";
            // convert launchctlPath to URL
            NSURL *launchctlURL = [NSURL fileURLWithPath: launchctlPath];
            
            //NSLog(@"arguments: %@ %@ %@", OnOffArgument, GUIDomainArgument, launchAgentPlistPath);
            
            // start the cmd line tool which can enable/disable the helper
            [NSTask launchedTaskWithExecutableURL: launchctlURL arguments:@[OnOffArgument, GUIDomainArgument, launchAgentPlistPath] error: nil terminationHandler: nil];
        } else {
            // Fallback on earlier versions
            NSString *OnOffArgumentOld = (enable) ? @"load": @"unload";
            [NSTask launchedTaskWithLaunchPath: launchctlPath arguments: @[OnOffArgumentOld, launchAgentPlistPath] ];
        }
    }
    else {
        NSLog(@"To this program, it looks like the number of user libraries != 1. Your computer is weird...");
    }
}

- (void) repairUserAgentConfigFile {
    
    @autoreleasepool {
        
        NSLog(@"repairing User Agent Config File");
        // what this does:
        
        // get path of executable of helper app based on path of bundle of this class (prefpane bundle)
        // check if the "User/Library/LaunchAgents/mouse.fix.helper.plist" UserAgent Config file exists, if the Launch Agents Folder exists, and if the exectuable path within the plist file is correct
        // if not:
        // create correct file based on "default_mouse.fix.helper.plist" and helperExecutablePath
        // write correct file to "User/Library/LaunchAgents"
        
        // get helper executable path
        NSBundle *prefPaneBundle = [NSBundle bundleForClass: [PrefPaneDelegate class]];
        NSString *prefPaneBundlePath = [prefPaneBundle bundlePath];
        NSString *helperExecutablePath = [prefPaneBundlePath stringByAppendingPathComponent: @"Contents/Library/LoginItems/Mouse Fix Helper.app/Contents/MacOS/Mouse Fix Helper"];
        
        // get User Library path
        NSArray *libraryPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
        if ([libraryPaths count] == 1) {
            // create path to launch agent config file
            NSString *launchAgentPlistPath = [[libraryPaths objectAtIndex:0] stringByAppendingPathComponent: @"LaunchAgents/mouse.fix.helper.plist"];
            
            // check if file exists
            NSFileManager *fileManager = [[NSFileManager alloc] init];
            BOOL LAConfigFile_exists = [fileManager fileExistsAtPath: launchAgentPlistPath isDirectory: nil];
            BOOL LAConfigFile_executablePathIsCorrect = TRUE;
            if (LAConfigFile_exists == TRUE) {
                
                // load data from launch agent config file into a dictionary
                NSData *LAConfigFile_data = [NSData dataWithContentsOfFile:launchAgentPlistPath];
                NSDictionary *LAConfigFile_dict = [NSPropertyListSerialization propertyListWithData:LAConfigFile_data options:NSPropertyListImmutable format:0 error:nil];
                
                // check if the executable path inside the config file is correct, if not, set flag to false
                
                NSString *helperExecutablePathFromFile = [LAConfigFile_dict objectForKey: @"Program"];
                
                //NSLog(@"objectForKey: %@", OBJForKey);
                //NSLog(@"helperExecutablePath: %@", helperExecutablePath);
                //NSLog(@"OBJ == Path: %d", OBJForKey isEqualToString: helperExecutablePath);
                
                if ( [helperExecutablePath isEqualToString: helperExecutablePathFromFile] == FALSE ) {
                    LAConfigFile_executablePathIsCorrect = FALSE;
                    
                }
                
                
            }
            
            NSLog(@"LAConfigFileExists %hhd, LAConfigFileIsCorrect: %hhd", LAConfigFile_exists,LAConfigFile_executablePathIsCorrect);
            // the config file doesn't exist, or the executable path within it is not correct
            if ( (LAConfigFile_exists == FALSE) || (LAConfigFile_executablePathIsCorrect == FALSE) ) {
                NSLog(@"repairing file...");
                
                //check if "User/Library/LaunchAgents" folder exists, if not, create it
                NSString *launchAgentsFolderPath = [launchAgentPlistPath stringByDeletingLastPathComponent];
                BOOL launchAgentsFolderExists = [fileManager fileExistsAtPath: launchAgentsFolderPath isDirectory: nil];
                
                if (launchAgentsFolderExists == FALSE) {
                    NSLog(@"LaunchAgentsFolder doesn't exist");
                }
                if (launchAgentsFolderExists == FALSE) {
                    NSError *error;
                    [fileManager createDirectoryAtPath:launchAgentsFolderPath withIntermediateDirectories:FALSE attributes:nil error:&error];
                    if (error == nil) {
                        NSLog(@"LaunchAgents Folder Created");
                    } else {
                        NSLog(@"Error while creating LaunchAgents Folder: %@", error);
                    }
                }
                
                
                
                
                NSError *error;
                // read contents of default_mouse.fix.helper.plist (aka default-launch-agent-config-file or defaultLAConfigFile) into a dictionary
                NSString *defaultLAConfigFile_path = [prefPaneBundle pathForResource:@"default_mouse.fix.helper" ofType:@"plist"];
                NSData *defaultLAConfigFile_data = [NSData dataWithContentsOfFile:defaultLAConfigFile_path];
                NSMutableDictionary *newLAConfigFile_dict = [NSPropertyListSerialization propertyListWithData:defaultLAConfigFile_data options:NSPropertyListMutableContainersAndLeaves format:nil error:&error];
                
                // set the executable path to the correct value
                [newLAConfigFile_dict setValue: helperExecutablePath forKey:@"Program"];
                
                // write the dict to User/Library/LaunchAgents/mouse.fix.helper.plist
                NSData *newLAConfigFile_data = [NSPropertyListSerialization dataWithPropertyList:newLAConfigFile_dict format:NSPropertyListXMLFormat_v1_0 options:0 error:&error];
                NSAssert(error == nil, @"Should not have encountered an error");
                [newLAConfigFile_data writeToFile:launchAgentPlistPath atomically:YES];
                if (error != nil) {
                    NSLog(@"repairUserAgentConfigFile() -- Data Serialization Error: %@", error);
                }
            } else {
                NSLog(@"nothing to repair");
            }
        }
        else {
            // no library path found
            NSLog(@"To this program, it looks like the number of user libraries != 1. Your computer is weird...");
        }
    }
}


- (BOOL) helperIsActive {
    
    // using NSTask to ask launchd about mouse.fix.helper status
    
    NSString *launchctlPath = @"/bin/launchctl";
    NSString *listArgument = @"list";
    NSString *launchdHelperIdentifier = @"mouse.fix.helper";
    
    NSPipe * launchctlOutput;
    
    // macOS version 10.13+
    
    if (@available(macOS 10.13, *)) {
        NSURL *launchctlURL = [NSURL fileURLWithPath: launchctlPath];
        
        NSTask *task = [[NSTask alloc] init];
        [task setExecutableURL: launchctlURL];
        [task setArguments: @[listArgument, launchdHelperIdentifier] ];
        launchctlOutput = [NSPipe pipe];
        [task setStandardOutput: launchctlOutput];
        
        [task launchAndReturnError:nil];
        
    } else {
     
        // Fallback on earlier versions
        
        NSTask *task = [[NSTask alloc] init];
        [task setLaunchPath: launchctlPath];
        [task setArguments: @[listArgument, launchdHelperIdentifier] ];
        launchctlOutput = [NSPipe pipe];
        [task setStandardOutput: launchctlOutput];
        
        [task launch];
        
    }
    
    
    NSFileHandle * launchctlOutput_fileHandle = [launchctlOutput fileHandleForReading];
    NSData * launchctlOutput_data = [launchctlOutput_fileHandle readDataToEndOfFile];
    NSString * launchctlOutput_string = [[NSString alloc] initWithData:launchctlOutput_data encoding:NSUTF8StringEncoding];
    if (
        [launchctlOutput_string rangeOfString: @"\"Label\" = \"mouse.fix.helper\";"].location != NSNotFound &&
        [launchctlOutput_string rangeOfString: @"\"LastExitStatus\" = 0;"].location != NSNotFound
        )
    {
        NSLog(@"MOUSE REMAPOR FOUNDD AND ACTIVE");
        return TRUE;
    }
    else {
        return FALSE;
    }
    
}

- (void)writeConfigDictToFile {
    NSError *serializeErr;
    NSData *configData = [NSPropertyListSerialization dataWithPropertyList:self.configDictFromFile format:NSPropertyListXMLFormat_v1_0 options:0 error:&serializeErr];
    if (serializeErr) {
        NSLog(@"ERROR serializing configDictFromFile: %@", serializeErr);
    }
    NSString *configPath = [[self helperBundle] pathForResource:@"config" ofType:@"plist"];
//    BOOL success = [configData writeToFile:configPath atomically:YES];
//    if (!success) {
//        NSLog(@"ERROR writing configDictFromFile to file");
//    }
    NSError *writeErr;
    [configData writeToFile:configPath options:NSDataWritingAtomic error:&writeErr];
    if (writeErr) {
        NSLog(@"ERROR writing configDictFromFile to file: %@", writeErr);
    }
    
    NSLog(@"FILE UPDATED");
}

- (void)loadConfigDictFromFile {
    NSString *configPath = [[self helperBundle] pathForResource:@"config" ofType:@"plist"];
    NSData *configData = [NSData dataWithContentsOfFile:configPath];
    NSError *readErr;
    NSMutableDictionary *configDict = [NSPropertyListSerialization propertyListWithData:configData options:NSPropertyListMutableContainersAndLeaves format:nil error:&readErr];
    if (readErr) {
        NSLog(@"ERROR Reading config File: %@", readErr);
    }
    
    self.configDictFromFile = configDict;
}

- (void)loadHelperBundle {
    NSBundle *prefPaneBundle = [NSBundle bundleForClass: [PrefPaneDelegate class]];
    NSString *prefPaneBundlePath = [prefPaneBundle bundlePath];
    NSString *helperBundlePath = [prefPaneBundlePath stringByAppendingPathComponent: @"Contents/Library/LoginItems/Mouse Fix Helper.app"];
    self.helperBundle = [NSBundle bundleWithPath:helperBundlePath];
}

- (void)setConfigDictToUI {
    
    NSLog(@"SET CONFIG TO UI");
    
    // middle button        // tag equals symbolicHotKey
    
    // click
    
    
    NSArray *middleButtonClickAction;
    if (_middleClick.selectedTag != 0) {
        middleButtonClickAction= @[@"symbolicHotKey", @(_middleClick.selectedTag)];
    }
    [_configDictFromFile setValue:middleButtonClickAction forKeyPath:@"ButtonRemaps.3.click"];
    
    // hold
    NSArray *middleButtonHoldAction;
    if (_middleHold.selectedTag != 0) {
        middleButtonHoldAction = @[@"symbolicHotKey", @(_middleHold.selectedTag)];
    }
    [_configDictFromFile setValue:middleButtonHoldAction forKeyPath:@"ButtonRemaps.3.hold"];
    
    
    // side buttons         // tag = 1 -> Switch Spaces, tag = 2 -> Switch Pages
    
    // click
    NSArray *sideButtonClickAction = [actionsForPopupButtonTag_onlyForSideMouseButtons objectForKey:@(_sideClick.selectedTag)];
    [_configDictFromFile setValue:sideButtonClickAction[0] forKeyPath:@"ButtonRemaps.4.click"];
    [_configDictFromFile setValue:sideButtonClickAction[1] forKeyPath:@"ButtonRemaps.5.click"];
    
    // hold
    NSArray *sideButtonHoldAction = [actionsForPopupButtonTag_onlyForSideMouseButtons objectForKey:@(_sideHold.selectedTag)];
    [_configDictFromFile setValue:sideButtonHoldAction[0] forKeyPath:@"ButtonRemaps.4.hold"];
    [_configDictFromFile setValue:sideButtonHoldAction[1] forKeyPath:@"ButtonRemaps.5.hold"];
    
    
    
    // scroll Settings
    
    // checkbox
    [_configDictFromFile setValue: [NSNumber numberWithBool: _scrollEnableCheckBox.state] forKeyPath:@"ScrollSettings.enabled"];
    
    
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
    
    [_configDictFromFile setValue:scrollValuesFromUI forKeyPath:@"ScrollSettings.values"];
    

    
    [self writeConfigDictToFile];
}



- (void)initializeUI {
    
    #pragma mark Sheet
    
    # pragma mark Popup Buttons
    
    NSDictionary *buttonRemaps = _configDictFromFile[@"ButtonRemaps"];
    
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
    
    NSDictionary *scrollConfigFromFile = _configDictFromFile[@"ScrollSettings"];
    
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
    
}


static void tellHelperToUpdateItsSettings() {
    CFMessagePortRef remotePort = CFMessagePortCreateRemote(kCFAllocatorDefault, CFSTR("com.uebler.nuebler.mouse.fix.port"));
    if (remotePort == NULL) {
        NSLog(@"there is no CFMessagePort");
        return;
    }
        
    SInt32 messageID = 0x420666; // Arbitrary
    CFDataRef data = nil;
    CFTimeInterval sendTimeout = 0.0;
    CFTimeInterval recieveTimeout = 0.0;
    CFStringRef replyMode = NULL;
    CFDataRef returnData = nil;
    SInt32 status = CFMessagePortSendRequest(remotePort, messageID, data, sendTimeout, recieveTimeout, replyMode, &returnData);
    if (status != 0) {
        NSLog(@"CFMessagePortSendRequest status: %d", status);
    }
}

@end
