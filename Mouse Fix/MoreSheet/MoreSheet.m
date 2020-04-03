//
// --------------------------------------------------------------------------
// MoreSheet.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "MoreSheet.h"
#import "ConfigFileInterface_PrefPane.h"
#import "../Update/Updater.h"
#import "../MessagePort/MessagePort_PrefPane.h"
#import "../PrefPaneDelegate.h"


@interface MoreSheet ()
    @property (strong) IBOutlet NSPanel *sheetPanel; // TODO: Remove. This should be the same as the automatically generated _window property.
    @property (weak) IBOutlet NSTextField *versionLabel;
    @property (weak) IBOutlet NSButton *checkForUpdateCheckBox;
    @property (weak) IBOutlet NSButton *doneButton;
@end

@implementation MoreSheet

# pragma mark - IBActions and Delegate
- (IBAction)checkForUpdateCheckBox:(NSButton *)sender {
    NSLog(@"CHECK");
    [ConfigFileInterface_PrefPane.config setValue:@"0" forKeyPath:@"Other.skippedBundleVersion"];
    [self UIChanged:NULL];
    if (sender.state == 1) {
        [Updater checkForUpdate];
        
    }
}
- (IBAction)smoothScrollBlacklistButton:(id)sender {
    [PrefPaneDelegate.scrollOverridePanelController display];
}
- (IBAction)milkshakeButton:(id)sender {
    NSLog(@"BUTTTON");
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=ARSTVR6KFB524&source=url&lc=en_US"]];
}
- (IBAction)doneButton:(id)sender {
    [self end];
}
- (IBAction)UIChanged:(id)sender {
    [self setConfigFileToUI];
    [MessagePort_PrefPane sendMessageToHelper:@"configFileChanged"];
}

//- (void)mouseDown:(NSEvent *)event {
//    NSLog(@"mousduunsn");
//    
//    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
//    [PrefPaneDelegate.mainView.window makeFirstResponder:NULL];
//    [_sheetPanel makeKeyWindow];
//    [_sheetPanel makeFirstResponder:NULL];
//}

#pragma mark - Class methods - Public

+ (void)endMoreSheetAttachedToMainWindow {
    NSWindow *sheet = NSApplication.sharedApplication.mainWindow.attachedSheet;
    if ([sheet.delegate.class isEqual:self.class]) {
        MoreSheet *moreSheetDelegate = (MoreSheet *)sheet.delegate;
        [moreSheetDelegate end];
    }
}

#pragma mark - Instance methods - Public

- (void)begin {
    [[[NSApplication sharedApplication] mainWindow] beginSheet:self.window completionHandler:nil];
}
- (void)end {
    [[[NSApplication sharedApplication] mainWindow] endSheet:self.window];
}

#pragma mark - Instance methods - Private

- (void)windowDidLoad {
    [super windowDidLoad];
    [self initializeUI];
}

- (void)initializeUI {
    NSString *versionString = [NSString stringWithFormat:@"Version %@ (%@)",
                               [[NSBundle bundleForClass:[self class]] objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
                               [[NSBundle bundleForClass:[self class]] objectForInfoDictionaryKey:@"CFBundleVersion"]];
    [_versionLabel setStringValue:versionString];
    
    _checkForUpdateCheckBox.state = [[ConfigFileInterface_PrefPane.config valueForKeyPath:@"Other.checkForUpdates"] boolValue];
}

- (void)setConfigFileToUI {
    [ConfigFileInterface_PrefPane.config setValue:[NSNumber numberWithBool:_checkForUpdateCheckBox.state] forKeyPath:@"Other.checkForUpdates"];
    [ConfigFileInterface_PrefPane writeConfigToFile];
}

@end
