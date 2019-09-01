//
//  MoreSheet.m
//  Mouse Fix
//
//  Created by Noah Nübling on 31.08.19.
//  Copyright © 2019 Noah Nuebling. All rights reserved.
//

#import "MoreSheet.h"
#import "ConfigFileInterface_PrefPane.h"
#import "../Update/Updater.h"
#import "../MessagePort/MessagePort_PrefPane.h"


@interface MoreSheet ()
    @property (strong) IBOutlet NSPanel *sheetPanel;
    @property (weak) IBOutlet NSTextField *versionLabel;
    @property (weak) IBOutlet NSButton *checkForUpdateCheckBox;
    @property (weak) IBOutlet NSButton *doneButton;
@end

@implementation MoreSheet

# pragma mark - IBActions
- (IBAction)checkForUpdateCheckBox:(NSButton *)sender {
    NSLog(@"CHECK");
    [ConfigFileInterface_PrefPane.config setValue:@"0" forKeyPath:@"other.skippedBundleVersion"];
    [self UIChanged:NULL];
    if (sender.state == 1) {
        [Updater checkForUpdate];
        
    }
}
- (IBAction)milkshakeButton:(id)sender {
    NSLog(@"BUTTTON");
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=ARSTVR6KFB524&source=url"]];
}
- (IBAction)doneButton:(id)sender {
    [self end];
}
- (IBAction)UIChanged:(id)sender {
    [self setConfigFileToUI];
    [MessagePort_PrefPane sendMessageToHelper:@"configFileChanged"];
}

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
    
    _checkForUpdateCheckBox.state = [[ConfigFileInterface_PrefPane.config valueForKeyPath:@"other.checkForUpdates"] boolValue];
}

- (void)setConfigFileToUI {
    [ConfigFileInterface_PrefPane.config setValue:[NSNumber numberWithBool:_checkForUpdateCheckBox.state] forKeyPath:@"other.checkForUpdates"];
    [ConfigFileInterface_PrefPane writeConfigToFile];
}

@end
