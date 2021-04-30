//
// --------------------------------------------------------------------------
// MoreSheet.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "MoreSheet.h"
#import "ConfigFileInterface_App.h"
#import "MessagePort_App.h"
#import "AppDelegate.h"
#import "Utility_App.h"
#import <Sparkle/Sparkle.h>
#import "SparkleUpdaterController.h"


@interface MoreSheet ()
@property (strong) IBOutlet NSPanel *sheetPanel; // TODO: Remove. This should be the same as the automatically generated _window property.
@property (weak) IBOutlet NSTextField *versionLabel;
@property (weak) IBOutlet NSButton *checkForUpdateCheckBox;
@property (weak) IBOutlet NSButton *prereleaseCheckBox;
@property (weak) IBOutlet NSButton *doneButton;
@end

@implementation MoreSheet

#pragma mark - Constants

#pragma mark - Static stuff

+ (void)load {
    _instance = [[MoreSheet alloc] initWithWindowNibName:@"MoreSheet"];
}
static MoreSheet *_instance;
+ (MoreSheet *)instance {
    return _instance;
}

# pragma mark - IBActions

- (IBAction)checkForUpdateCheckBox:(NSButton *)sender {
    setConfig(@"Other.skippedBundleVersion", @"0");
    [self updateConfigFileToUIState];
    [self updateUI]; // So that prereleaseCheckBox gets disabled/enabled
    if (sender.state == 1) {
        [SUUpdater.sharedUpdater checkForUpdatesInBackground];
        
    }
}
- (IBAction)prereleaseCheckBox:(NSButton *)sender {
    [self updateConfigFileToUIState];
    [SparkleUpdaterController enablePrereleaseChannel:sender.state];
    if (sender.state == 1) {  
        [SUUpdater.sharedUpdater checkForUpdatesInBackground];
    }
}

- (IBAction)appOverrideButton:(id)sender {
    [OverridePanel.instance begin];
}
- (IBAction)milkshakeButton:(id)sender {
    NSLog(@"BUTTTON");
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=ARSTVR6KFB524&source=url&lc=en_US"]];
}
- (IBAction)doneButton:(id)sender {
    [self end];
}

//- (void)mouseDown:(NSEvent *)event {
//    NSLog(@"mousduunsn");
//    
//    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
//    [AppDelegate.mainView.window makeFirstResponder:NULL];
//    [_sheetPanel makeKeyWindow];
//    [_sheetPanel makeFirstResponder:NULL];
//}

#pragma mark - Class methods - Public


#pragma mark - Instance methods - Public

- (void)begin {
    [AppDelegate.mainWindow beginSheet:self.window completionHandler:nil];
    [self.window makeKeyWindow]; // Doesn't work
    
}
- (void)end {
    [AppDelegate.mainWindow endSheet:self.window];
//    [[[NSApplication sharedApplication] mainWindow] endSheet:self.window]; // There is no main window when the app isn't frontmost...
//    [ScrollOverridePanel.instance close];
}

#pragma mark - Instance methods - Private

- (void)windowDidLoad {
    [super windowDidLoad];
    [self updateUI];
}

- (void)updateUI {
    
    // Load version label
    NSString *versionString = [NSString stringWithFormat:@"Version %ld (%ld)",
                               (long)Utility_App.bundleVersionShort,
                               (long)Utility_App.bundleVersion];
    [self.versionLabel setStringValue:versionString];
    
    // Load checkbox state
    self.checkForUpdateCheckBox.state = [config(@"Other.checkForUpdates") boolValue];
    self.prereleaseCheckBox.state = [config(@"Other.checkForPrereleases") boolValue];
    
    self.prereleaseCheckBox.enabled = self.checkForUpdateCheckBox.state;
}

- (void)updateConfigFileToUIState {
    
    setConfig(@"Other.checkForPrereleases", @(self.prereleaseCheckBox.state));
    setConfig(@"Other.checkForUpdates", @(self.checkForUpdateCheckBox.state));
    
    commitConfig();
}

@end

#pragma mark - Unused

//- (IBAction)bugReportButton:(id)sender {
//
//    // Create email composing sharing service
//    NSSharingService *service = [NSSharingService sharingServiceNamed:NSSharingServiceNameComposeEmail];
//
//    // Set service attributes
//
//    [service setRecipients:@[_feedbackMailAddress]];
//    [service setSubject:@"Mac Mouse Fix - Bug Report"];
//
//    // Create message body
//
//    NSMutableAttributedString *messageBody = [[NSMutableAttributedString alloc] init];
//
//    // Create fonts
//    NSFont *defaultFont = [NSFont systemFontOfSize:NSFont.smallSystemFontSize];
//    NSFont *headerFont = [NSFontManager.sharedFontManager convertFont:defaultFont toHaveTrait:NSBoldFontMask];
//    NSFont *italicFont = [NSFontManager.sharedFontManager convertFont:defaultFont toHaveTrait:NSItalicFontMask];
//
//    // Create string attributes
//    NSDictionary *headerAttributes = @{
//        NSFontAttributeName : headerFont,
//    };
//    NSDictionary *italicAttributes = @{
//        NSFontAttributeName : italicFont,
//    };
//
//
//
//    // Create attributed strings
//
//    NSAttributedString *header1 = [[NSAttributedString alloc] initWithString:@"Description of the bug"
//                                                                  attributes:headerAttributes];
//    NSAttributedString *header2 = [[NSAttributedString alloc] initWithString:@"Steps to reproduce"
//                                                                  attributes:headerAttributes];
//    NSAttributedString *header3 = [[NSAttributedString alloc] initWithString:@"Diagnostic data"
//                                                                  attributes:headerAttributes];
//
//    NSAttributedString *subtitle1 = [[NSAttributedString alloc] initWithString:@"Fill in here"
//                                                                    attributes:italicAttributes];
//    NSAttributedString *subtitle2 = [[NSAttributedString alloc] initWithString:@"This might contain personal data. Delete this if you don't want to share it."
//                                                                    attributes:italicAttributes];
//
//    NSAttributedString *lineBreak = [[NSAttributedString alloc] initWithString:@"\n"];
//
//
//    // Merge strings to create full body string
//    [messageBody appendAttributedString:header1];
//    [messageBody appendAttributedString:lineBreak];
//    [messageBody appendAttributedString:lineBreak];
//    [messageBody appendAttributedString:subtitle1];
//    [messageBody appendAttributedString:lineBreak];
//    [messageBody appendAttributedString:lineBreak];
//
//    [messageBody appendAttributedString:header2];
//    [messageBody appendAttributedString:lineBreak];
//    [messageBody appendAttributedString:lineBreak];
//    [messageBody appendAttributedString:subtitle1];
//    [messageBody appendAttributedString:lineBreak];
//    [messageBody appendAttributedString:lineBreak];
//
//    [messageBody appendAttributedString:header3];
//    [messageBody appendAttributedString:lineBreak];
//    [messageBody appendAttributedString:subtitle2];
//    [messageBody appendAttributedString:lineBreak];
//    [messageBody appendAttributedString:lineBreak];
//
////    NSString* htmlText = [NSString stringWithContentsOfFile:@"/Users/Noah/Desktop/test.html" encoding:NSUTF8StringEncoding error:NULL];
//
//
//    // Compose email
//
//    [service performWithItems:@[messageBody]];
//
//
//}
