//
//  moreSheetController.m
//  Mouse Fix
//
//  Created by Noah Nübling on 20.08.19.
//  Copyright © 2019 Noah Nuebling. All rights reserved.
//

#import "moreSheetController.h"

@interface moreSheetController ()
@property (strong) IBOutlet NSPanel *moreSheetPanel;
@property (weak) IBOutlet NSTextField *versionLabel;

@end

@implementation moreSheetController

- (void)windowWillLoad {
    [super windowDidLoad];
    
    NSLog(@"CONTROLLINGGG");
    
    NSString *versionString = [NSString stringWithFormat:@"Version %@ (%@)", @"4.3", @"82434"];
    [_versionLabel setStringValue:versionString];
}

@end
