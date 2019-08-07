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




// InputParser.h - Global variables

// - clickAndHoldGlobal
@property (retain) NSTimer* clickAndHoldTimer;
// - FakeSwipe Globals (Sensible Side Buttons)
@property (retain) NSMutableDictionary<NSNumber*, NSArray<NSDictionary*>*>* swipeInfo;
@property (retain) NSArray* nullArray;



@end
