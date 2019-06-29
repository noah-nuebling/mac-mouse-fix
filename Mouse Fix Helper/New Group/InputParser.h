//
//  InputParser.h
//  Mouse Remap Helper
//
//  Created by Noah Nübling on 19.11.18.
//  Copyright © 2018 Noah Nuebling Enterprises Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CGSInternal/CGSHotKeys.h"
#import "SensibleSideButtons/TouchEvents.h"

NS_ASSUME_NONNULL_BEGIN

@interface InputParser : NSObject

+ (CGEventRef)parse:(int)mouseButton state:(int)state event:(CGEventRef)event;
+ (void)doSymbolicHotKeyAction: (CGSSymbolicHotKey)shk;
+ (void)handleActionArray:(NSArray *)actionArray;
@end

NS_ASSUME_NONNULL_END
