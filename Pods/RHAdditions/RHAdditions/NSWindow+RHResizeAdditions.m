//
//  NSWindow+RHResizeAdditions.m
//
//  Created by Richard Heard on 4/02/13.
//  Copyright (c) 2013 Richard Heard. All rights reserved.
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

#import "NSWindow+RHResizeAdditions.h"

@implementation NSWindow (RHResizeAdditions)

#pragma mark - View Controller Methods

-(void)resizeForContentSize:(NSSize)size duration:(CGFloat)duration{
    NSWindow *window = self;
    
    NSRect frame = [window contentRectForFrameRect:[window frame]];
    
    CGFloat newX = NSMinX(frame) + (0.5* (NSWidth(frame) - size.width));
    NSRect newFrame = [window frameRectForContentRect:NSMakeRect(newX, NSMaxY(frame) - size.height, size.width, size.height)];
    
    if (duration > 0.0f){
        [NSAnimationContext beginGrouping];
        [[NSAnimationContext currentContext] setDuration:duration];
        [[window animator] setFrame:newFrame display:YES];
        [NSAnimationContext endGrouping];
    } else {
        [window setFrame:newFrame display:YES];
    }
    
}

@end

//include an implementation in this file so we don't have to use -load_all for this category to be included in a static lib
@interface RHFixCategoryBugClassNSWRHRA : NSObject @end @implementation RHFixCategoryBugClassNSWRHRA @end

