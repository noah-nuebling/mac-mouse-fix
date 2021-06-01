//
//  NSThread+RHBlockAdditions.m
//
//  Created by Richard Heard on 22/8/11.
//  Copyright (c) 2011 Richard Heard. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions
//  are met:
//  1. Redistributions of source code must retain the above copyright
//  notice, this list of conditions and the following disclaimer.
//  2. Redistributions in binary form must reproduce the above copyright
//  notice, this list of conditions and the following disclaimer in the
//  documentation and/or other materials provided with the distribution.
//  3. The name of the author may not be used to endorse or promote products
//  derived from this software without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
//  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
//  OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
//  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
//  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
//  NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
//  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
//  THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import "NSThread+RHBlockAdditions.h"
#import "RHARCSupport.h"

@implementation NSThread (RHBlockAdditions)

#pragma mark - public
-(void)rh_performBlock:(VoidBlock)block{
    [self rh_performBlock:block waitUntilDone:YES];
}

-(void)rh_performBlock:(VoidBlock)block waitUntilDone:(BOOL)wait{
    //if current thread and wait (run directly)
    if ([[NSThread currentThread] isEqual:self] && wait){
        block(); return;
    }
	[self performSelector:@selector(_rh_runBlock:) onThread:self withObject:arc_autorelease([block copy]) waitUntilDone:wait];
}

-(void)rh_performBlock:(VoidBlock)block afterDelay:(NSTimeInterval)delay{
    [self performSelector:@selector(rh_performBlock:) withObject:arc_autorelease([block copy]) afterDelay:delay];
}


#pragma mark - helpers
+(void)rh_performBlockOnMainThread:(VoidBlock)block{
    [[NSThread mainThread] rh_performBlock:block];
}

+(void)rh_performBlockOnMainThread:(VoidBlock)block waitUntilDone:(BOOL)wait{
    [[NSThread mainThread] rh_performBlock:block waitUntilDone:wait];
}

+(void)rh_performBlockInBackground:(VoidBlock)block{
    [NSThread performSelectorInBackground:@selector(_rh_runBlock:) withObject:arc_autorelease([block copy])];
}

-(void)_rh_runBlock:(void (^)())block{
    if (block) block();
}

@end


//include an implementation in this file so we don't have to use -load_all for this category to be included in a static lib
@interface RHFixCategoryBugClassRHBA : NSObject  @end @implementation RHFixCategoryBugClassRHBA @end

