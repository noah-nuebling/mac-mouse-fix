//
//  AppDelegate.h
//  Mouse Remap Helper
//
//  Created by Noah Nübling on 25.07.18.
//  Copyright © 2018 Noah Nuebling Enterprises Ltd. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <IOKit/hid/IOHIDManager.h>


@interface AppDelegate : NSObject <NSApplicationDelegate>


// Store configFile for global access from all classes
@property (retain) NSMutableDictionary *configDictFromFile;
- (void) repairConfigFile:(NSString *)info;


- (void) setHorizontalScroll:(BOOL)B;


// InputParser.h - Global variables

// - clickAndHoldGlobals
@property (retain) NSTimer* clickAndHoldTimer;
// - FakeSwipe Globals (Sensible Side Buttons)
@property (retain) NSMutableDictionary<NSNumber*, NSArray<NSDictionary*>*>* swipeInfo;
@property (retain) NSArray* nullArray;



@end
