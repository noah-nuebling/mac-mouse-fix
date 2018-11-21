//
//  AppDelegate.m
//  Mouse Remap Helper
//
//  Created by Noah Nübling on 25.07.18.
//  Copyright © 2018 Noah Nuebling Enterprises Ltd. All rights reserved.
//
#import "AppDelegate.h"
#import "InputReceiver.h"
#import "InputParser.h"
#import "ConfigFileMonitor.h"
#import "SmoothScroll.h"

#import "CGSInternal/CGSHotKeys.h"
#import "SensibleSideButtons/TouchEvents.h"


@interface AppDelegate ()

@end

@implementation AppDelegate


SmoothScroll *smoothScrollObject;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    NSLog(@"running Mouse Remap Helper");

    [InputReceiver start];
    
    [ConfigFileMonitor fillConfigDictFromFile];
    [ConfigFileMonitor setupFSEventStreamCallback];
    
    
    AnimationCurve *curve = [[AnimationCurve alloc] init];
    [curve UnitBezierForPoint1x:0.1 point1y:0.1 point2x:0.2 point2y:1.0];
    int pxPerStep   =   76;
    int msBase      =   250;
    int msMax       =   300;
    float msFactor  =   1.09;
    [SmoothScroll startWithAnimationCurve:curve
                                pxPerStep:pxPerStep
                                   msBase:msBase
                                    msMax:msMax
                                 msFactor:msFactor];
    
    
    
    // setup SSB globals
    _swipeInfo = [NSMutableDictionary dictionary];
    
    for (NSNumber* direction in @[ @(kTLInfoSwipeUp), @(kTLInfoSwipeDown), @(kTLInfoSwipeLeft), @(kTLInfoSwipeRight) ]) {
        NSDictionary* swipeInfo1 = [NSDictionary dictionaryWithObjectsAndKeys:
                                    @(kTLInfoSubtypeSwipe), kTLInfoKeyGestureSubtype,
                                    @(1), kTLInfoKeyGesturePhase,
                                    nil];
        
        NSDictionary* swipeInfo2 = [NSDictionary dictionaryWithObjectsAndKeys:
                                    @(kTLInfoSubtypeSwipe), kTLInfoKeyGestureSubtype,
                                    direction, kTLInfoKeySwipeDirection,
                                    @(4), kTLInfoKeyGesturePhase,
                                    nil];
        
        _swipeInfo[direction] = @[ swipeInfo1, swipeInfo2 ];
    }
    
    _nullArray = @[];
}

- (void) repairConfigFile:(NSString *)info {
    // TODO: actually repair config dict
    NSLog(@"repairing configDict....");
}


- (void) setHorizontalScroll:(BOOL)B {
    [SmoothScroll setHorizontalScroll: B];
}



// NSTimer Callbacks

// - InputParser.h
- (void) disableSHK: (NSTimer *)timer {
    CGSSymbolicHotKey shk = [[timer userInfo] intValue];
    CGSSetSymbolicHotKeyEnabled(shk, FALSE);
}
- (void) doClickAndHoldAction: (NSTimer *)timer {
    NSArray *holdAction = [timer userInfo];
    [InputParser handleActionArray:holdAction];
}

@end
