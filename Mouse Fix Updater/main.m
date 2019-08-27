//
//  main.m
//  Mouse Fix Updater
//
//  Created by Noah Nübling on 27.08.19.
//  Copyright © 2019 Noah Nuebling. All rights reserved.
//

#import <Foundation/Foundation.h>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSDictionary *error = [NSDictionary new];
        
        
        
        NSString *script = [NSString stringWithFormat:@"do shell script \"cp -r %s %s\" with administrator privileges", argv[0], argv[1]];
        
        NSAppleScript *appleScript = [NSAppleScript alloc];
        appleScript = [appleScript initWithSource:script];
        if ([appleScript executeAndReturnError:&error]) {
            NSLog(@"success!");
        } else {
            NSLog(@"failure!");
            NSLog(@"%@", error);
        }
    }
    return 0;
}
