//
//  NSImageView+RHImageRectAdditions.m
//
//  Created by Richard Heard on 6/10/2013.
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

#import "NSImageView+RHImageRectAdditions.h"

@implementation NSImageView (RHImageRectAdditions)

-(NSSize)imageScale{
    CGFloat imageW = self.image.size.width;
    CGFloat imageH = self.image.size.height;

    if (imageH < 1.0 || imageW < 1.0) return NSZeroSize;
    
    NSRect drawingBounds = [self.cell drawingRectForBounds:self.bounds];
    CGFloat width = drawingBounds.size.width;
    CGFloat height = drawingBounds.size.height;
    
    CGFloat scaleX = width / imageW;
    CGFloat scaleY = height / imageH;
    CGFloat scale = 1.0;
    
    switch (self.imageScaling) {
        case NSImageScaleProportionallyDown:
            scale = fminf(scaleX, scaleY);
            scale = MIN(scale, (CGFloat) 1.0); //max scale at 1.0 (ie scale down only)
            return CGSizeMake(scale, scale);
            
        case NSImageScaleProportionallyUpOrDown:
            scale = fminf(scaleX, scaleY);
            return CGSizeMake(scale, scale);
            
        case NSImageScaleAxesIndependently:
            return CGSizeMake(scaleX, scaleY);
            
        case NSImageScaleNone:
        default: return CGSizeMake(scale, scale);
    }
}


-(NSSize)scaledImageSize{
    NSSize scale = [self imageScale];
    
    CGFloat scaledW = self.image.size.width * scale.width;
    CGFloat scaledH = self.image.size.height * scale.height;

    return NSMakeSize(scaledW, scaledH);
}

-(NSRect)imageRect{
    
    NSRect drawingBounds = [self.cell drawingRectForBounds:self.bounds];

    CGFloat width = drawingBounds.size.width;
    CGFloat height = drawingBounds.size.height;
    
    NSSize scaled = [self scaledImageSize];
    CGFloat scaledW = scaled.width;
    CGFloat scaledH = scaled.height;
    
    CGFloat minX = (CGFloat) 0.0;
    CGFloat minY = (CGFloat) 0.0;
    CGFloat maxX = (CGFloat) width - scaledW;
    CGFloat maxY = (CGFloat) height - scaledH;
    CGFloat centeredX = (CGFloat) ceil((width - scaledW) * (CGFloat)0.5);
    CGFloat centeredY = (CGFloat) ceil((height - scaledH) * (CGFloat)0.5);
    
    NSRect result = NSZeroRect;
    
    switch (self.imageAlignment) {
        case NSImageAlignCenter:        result = NSMakeRect(centeredX, centeredY, scaledW, scaledH); break;
        case NSImageAlignTop:           result = NSMakeRect(centeredX, maxY, scaledW, scaledH); break;
        case NSImageAlignTopLeft:       result = NSMakeRect(minX, maxY, scaledW, scaledH); break;
        case NSImageAlignTopRight:      result = NSMakeRect(maxX, maxY, scaledW, scaledH); break;
        case NSImageAlignLeft:          result = NSMakeRect(minX, centeredY, scaledW, scaledH); break;
        case NSImageAlignBottom:        result = NSMakeRect(centeredX, minY, scaledW, scaledH); break;
        case NSImageAlignBottomLeft:    result = NSMakeRect(minX, minY, scaledW, scaledH); break;
        case NSImageAlignBottomRight:   result = NSMakeRect(maxX, minY, scaledW, scaledH); break;
        case NSImageAlignRight:         result = NSMakeRect(maxX, centeredY, scaledW, scaledH); break;
    }
  
    //offset by the origin of the cells drawingRect (we are working in imageview bounds atm)
    result = NSOffsetRect(result, drawingBounds.origin.x, drawingBounds.origin.y);
    
    return result;
    
}

@end

//include an implementation in this file so we don't have to use -load_all for this category to be included in a static lib
@interface RHFixCategoryBugClassNSIVRHIRA : NSObject @end @implementation RHFixCategoryBugClassNSIVRHIRA @end

