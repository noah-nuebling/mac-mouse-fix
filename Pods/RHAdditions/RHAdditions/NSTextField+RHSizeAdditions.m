//
//  NSTextField+RHSizeAdditions.m
//
//  Created by Richard Heard on 14/06/13.
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

#import "NSTextField+RHSizeAdditions.h"
#import "RHARCSupport.h"

@implementation NSTextField (RHSizeAdditions)

-(NSSize)sizeWithMaxWidth:(CGFloat)maxWidth{
    NSSize maxSize = NSMakeSize(maxWidth, CGFLOAT_MAX);
    return RHAttributedStringRequiredSizeWithMaxSize(self.attributedStringValue, maxSize);
}

-(NSSize)sizeWithMaxHeight:(CGFloat)maxHeight{
    NSSize maxSize = NSMakeSize(CGFLOAT_MAX, maxHeight);
    return RHAttributedStringRequiredSizeWithMaxSize(self.attributedStringValue, maxSize);    
}

-(CGFloat)heightForWidth:(CGFloat)width{
    return [self sizeWithMaxWidth:width].height;
}
-(CGFloat)widthForHeight:(CGFloat)height{
    return [self sizeWithMaxHeight:height].width;
}

@end

NSSize RHAttributedStringRequiredSizeWithMaxSize(NSAttributedString* attributedString, NSSize maxSize){
    NSSize result = NSZeroSize;
    
    NSTextContainer *textContainer = [[NSTextContainer alloc] initWithContainerSize:maxSize];
    NSTextStorage *textStorage = [[NSTextStorage alloc] initWithAttributedString:attributedString];
    NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
    [layoutManager addTextContainer:textContainer];
    [textStorage addLayoutManager:layoutManager];
    [layoutManager setHyphenationFactor:0.0];
    
    //force layout by querying glyphs for our text container
    [layoutManager glyphRangeForTextContainer:textContainer];
    
    //grab our result
    result = [layoutManager usedRectForTextContainer:textContainer].size;
    
    //take into account any extra height added for an empty line with cursor
    CGFloat extraLineHeight = [layoutManager extraLineFragmentRect].size.height;
    result.height -= extraLineHeight;
    
    //cleanup
    arc_release(layoutManager);
    arc_release(textStorage);
    arc_release(textContainer);
    
    //return
    return result;
}

//include an implementation in this file so we don't have to use -load_all for this category to be included in a static lib
@interface RHFixCategoryBugClassNSTFRHSA : NSObject @end @implementation RHFixCategoryBugClassNSTFRHSA @end

