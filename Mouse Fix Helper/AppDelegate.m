//
//  AppDelegate.m
//  Mouse Remap Helper
//
//  Created by Noah Nübling on 25.07.18.
//  Copyright © 2018 Noah Nuebling Enterprises Ltd. All rights reserved.
//
#import "AppDelegate.h"
#import "MouseInputReceiver.h"
#import "ModifierInputReceiver.h"
#import "InputParser.h"
#import "ConfigFileInterface.h"
#import "MessagePortReceiver.h"
#import "DeviceManager.h"

//#import "SmoothScroll.h"
#import "MomentumScroll.h"

#import "CGSInternal/CGSHotKeys.h"
#import "SensibleSideButtons/TouchEvents.h"


@interface AppDelegate ()

@end

@implementation AppDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    NSLog(@"running Mouse Fix Helper");
}
@end
