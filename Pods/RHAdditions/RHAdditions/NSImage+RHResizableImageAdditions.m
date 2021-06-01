//
//  NSImage+RHResizableImageAdditions.m
//
//  Created by Richard Heard on 15/04/13.
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


#import "NSImage+RHResizableImageAdditions.h"
#import "RHARCSupport.h"


//==========
#pragma mark - RHEdgeInsets

RHEdgeInsets RHEdgeInsetsMake(CGFloat top, CGFloat left, CGFloat bottom, CGFloat right){
    RHEdgeInsets insets = {top, left, bottom, right};
    return insets;
}

CGRect RHEdgeInsetsInsetRect(CGRect rect, RHEdgeInsets insets, BOOL flipped){
    rect.origin.x    += insets.left;
    rect.origin.y    += flipped ? insets.top : insets.bottom;
    rect.size.width  -= (insets.left + insets.right);
    rect.size.height -= (insets.top  + insets.bottom);
    return rect;
}

extern BOOL RHEdgeInsetsEqualToEdgeInsets(RHEdgeInsets insets1, RHEdgeInsets insets2){
    return insets1.left == insets2.left && insets1.top == insets2.top && insets1.right == insets2.right && insets1.bottom == insets2.bottom;
}

const RHEdgeInsets RHEdgeInsetsZero = {0.0f, 0.0f, 0.0f, 0.0f};

NSString *NSStringFromRHEdgeInsets(RHEdgeInsets insets){
    return [NSString stringWithFormat:@"{%lg,%lg,%lg,%lg}", insets.top, insets.left, insets.bottom, insets.right];
}

RHEdgeInsets RHEdgeInsetsFromString(NSString* string){
    RHEdgeInsets result = RHEdgeInsetsZero;
    if(string != nil && [string respondsToSelector:@selector(cStringUsingEncoding:)]){
        sscanf([string cStringUsingEncoding:NSUTF8StringEncoding], "{%lg,%lg,%lg,%lg}", &result.top, &result.left, &result.bottom, &result.right);
    }
    return result;
}



//==========
#pragma mark - NSImage+RHResizableImageAdditions


@implementation NSImage (RHResizableImageAdditions)

-(RHResizableImage*)resizableImageWithCapInsets:(RHEdgeInsets)capInsets{
    RHResizableImage *new = [[RHResizableImage alloc] initWithImage:self capInsets:capInsets];
    return arc_autorelease(new);
}

-(RHResizableImage*)resizableImageWithCapInsets:(RHEdgeInsets)capInsets resizingMode:(RHResizableImageResizingMode)resizingMode{
    RHResizableImage *new = [[RHResizableImage alloc] initWithImage:self capInsets:capInsets resizingMode:resizingMode];
    return arc_autorelease(new);
}

-(RHResizableImage*)stretchableImageWithLeftCapWidth:(CGFloat)leftCapWidth topCapHeight:(CGFloat)topCapHeight{
    RHResizableImage *new = [[RHResizableImage alloc] initWithImage:self leftCapWidth:leftCapWidth topCapHeight:topCapHeight];
    return arc_autorelease(new);
}

-(void)drawTiledInRect:(NSRect)rect operation:(NSCompositingOperation)op fraction:(CGFloat)delta{
    RHDrawTiledImageInRect(self, rect, op, delta);
}

-(void)drawStretchedInRect:(NSRect)rect operation:(NSCompositingOperation)op fraction:(CGFloat)delta{
    RHDrawStretchedImageInRect(self, rect, op, delta);
}

@end



//==========
#pragma mark - RHResizableImage


@implementation RHResizableImage

@synthesize capInsets=_capInsets;
@synthesize resizingMode=_resizingMode;

-(id)initWithImage:(NSImage*)image leftCapWidth:(CGFloat)leftCapWidth topCapHeight:(CGFloat)topCapHeight{
    CGFloat rightCapWidth = image.size.width - leftCapWidth - 1.0f;
    CGFloat bottomCapHeight = image.size.height - topCapHeight - 1.0f;
    return [self initWithImage:image capInsets:RHEdgeInsetsMake(topCapHeight, leftCapWidth, bottomCapHeight, rightCapWidth)];
}

-(id)initWithImage:(NSImage*)image capInsets:(RHEdgeInsets)capInsets{
    return [self initWithImage:image capInsets:capInsets resizingMode:RHResizableImageResizingModeTile];
}
-(id)initWithImage:(NSImage*)image capInsets:(RHEdgeInsets)capInsets resizingMode:(RHResizableImageResizingMode)resizingMode{
    self = [super initWithData:[image TIFFRepresentation]];
    
    if (self){
        _capInsets = capInsets;
        _resizingMode = resizingMode;
        
        _imagePieces = arc_retain(RHNinePartPiecesFromImageWithInsets(self, _capInsets));
    }
    return self;
}



-(void)dealloc{
    arc_release_nil(_imagePieces);
    arc_release_nil(_cachedImageRep);

    arc_super_dealloc();
}

#pragma mark - drawing
-(void)drawInRect:(NSRect)rect{
    [self drawInRect:rect operation:NSCompositeSourceOver fraction:1.0f];
}

-(void)drawInRect:(NSRect)rect operation:(NSCompositingOperation)op fraction:(CGFloat)requestedAlpha{
    [self drawInRect:rect operation:op fraction:requestedAlpha respectFlipped:YES hints:nil];
}
-(void)drawInRect:(NSRect)rect operation:(NSCompositingOperation)op fraction:(CGFloat)requestedAlpha respectFlipped:(BOOL)respectContextIsFlipped hints:(NSDictionary *)hints{
    [self drawInRect:rect fromRect:NSZeroRect operation:op fraction:requestedAlpha respectFlipped:YES hints:nil];
}

-(void)drawInRect:(NSRect)rect fromRect:(NSRect)fromRect operation:(NSCompositingOperation)op fraction:(CGFloat)requestedAlpha respectFlipped:(BOOL)respectContextIsFlipped hints:(NSDictionary *)hints{
    CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];

    //if our current cached image ref size does not match, throw away the cached image
    //we also treat the current contexts scale as an invalidator so we don't draw the old, cached result.
    if (!NSEqualSizes(rect.size, _cachedImageSize) || _cachedImageDeviceScale != RHContextGetDeviceScale(context)){
        arc_release_nil(_cachedImageRep);
        _cachedImageSize = NSZeroSize;
        _cachedImageDeviceScale = 0.0f;
    }
    
    
    //if we don't have a cached image rep, create one now
    if (!_cachedImageRep){

        //cache our cache invalidation flags
        _cachedImageSize = rect.size;
        _cachedImageDeviceScale = RHContextGetDeviceScale(context);
        
        //create our own NSBitmapImageRep directly because calling -[NSImage lockFocus] and then drawing an
        //image causes it to use the largest available (ie @2x) image representation, even though our current
        //contexts scale is 1 (on non HiDPI screens) meaning that we inadvertently would use @2x assets to draw for @1x contexts
        _cachedImageRep =  [[NSBitmapImageRep alloc]
                            initWithBitmapDataPlanes:NULL
                            pixelsWide:_cachedImageSize.width * _cachedImageDeviceScale
                            pixelsHigh:_cachedImageSize.height * _cachedImageDeviceScale
                            bitsPerSample:8
                            samplesPerPixel:4
                            hasAlpha:YES
                            isPlanar:NO
                            colorSpaceName:[[[self representations] lastObject] colorSpaceName]
                            bytesPerRow:0
                            bitsPerPixel:32];
        [_cachedImageRep setSize:rect.size];

        if (!_cachedImageRep){
            NSLog(@"Error: failed to create NSBitmapImageRep from rep: %@", [[self representations] lastObject]);
            return;
        }
        
        NSGraphicsContext *newContext = [NSGraphicsContext graphicsContextWithBitmapImageRep:_cachedImageRep];
        if (!newContext){
            NSLog(@"Error: failed to create NSGraphicsContext from rep: %@", _cachedImageRep);
            arc_release_nil(_cachedImageRep);
            return;
        }
        
        [NSGraphicsContext saveGraphicsState];
        [NSGraphicsContext setCurrentContext:newContext];

        NSRect drawRect = NSMakeRect(0.0f, 0.0f, _cachedImageSize.width, _cachedImageSize.height);

        [[NSColor clearColor] setFill];
        NSRectFill(drawRect);
        
        
#if USE_RH_NINE_PART_IMAGE
        BOOL shouldTile = (_resizingMode == RHResizableImageResizingModeTile);
        RHDrawNinePartImage(drawRect,
                            [_imagePieces objectAtIndex:0], [_imagePieces objectAtIndex:1], [_imagePieces objectAtIndex:2],
                            [_imagePieces objectAtIndex:3], [_imagePieces objectAtIndex:4], [_imagePieces objectAtIndex:5],
                            [_imagePieces objectAtIndex:6], [_imagePieces objectAtIndex:7], [_imagePieces objectAtIndex:8],
                            NSCompositeSourceOver, 1.0f, shouldTile);
#else
        NSDrawNinePartImage(drawRect,
                            [_imagePieces objectAtIndex:0], [_imagePieces objectAtIndex:1], [_imagePieces objectAtIndex:2],
                            [_imagePieces objectAtIndex:3], [_imagePieces objectAtIndex:4], [_imagePieces objectAtIndex:5],
                            [_imagePieces objectAtIndex:6], [_imagePieces objectAtIndex:7], [_imagePieces objectAtIndex:8],
                            NSCompositeSourceOver, 1.0f, NO);
        
        //if we want a center stretch, we need to draw this separately, clearing center first
        //also note that this only stretches the center, if you also want all sides stretched,
        // you should use RHDrawNinePartImage() via USE_RH_NINE_PART_IMAGE = 1
        BOOL shouldStretch = (_resizingMode == RHResizableImageResizingModeStretch);
        if (shouldStretch){
            NSImage *centerImage = [_imagePieces objectAtIndex:4];
            NSRect centerRect = NSRectFromCGRect(RHEdgeInsetsInsetRect(NSRectToCGRect(drawRect), _capInsets, NO));
            CGContextClearRect([[NSGraphicsContext currentContext] graphicsPort], NSRectToCGRect(centerRect));
            RHDrawStretchedImageInRect(centerImage, centerRect, NSCompositeSourceOver, 1.0f);
        }

#endif
         [NSGraphicsContext restoreGraphicsState];
     }
    
    //finally draw the cached image rep
    fromRect = NSMakeRect(0.0f, 0.0f, _cachedImageSize.width, _cachedImageSize.height);
    [_cachedImageRep drawInRect:rect fromRect:fromRect operation:op fraction:requestedAlpha respectFlipped:respectContextIsFlipped hints:hints];
    
}

-(void)originalDrawInRect:(NSRect)rect fromRect:(NSRect)fromRect operation:(NSCompositingOperation)op fraction:(CGFloat)requestedAlpha respectFlipped:(BOOL)respectContextIsFlipped hints:(NSDictionary *)hints{
    return [super drawInRect:rect fromRect:fromRect operation:op fraction:requestedAlpha respectFlipped:respectContextIsFlipped hints:hints];
}

@end



//==========
#pragma mark - utilities




NSImage* RHImageByReferencingRectOfExistingImage(NSImage *image, NSRect rect){
    NSImage *newImage = [[NSImage alloc] initWithSize:rect.size];
    if (!NSIsEmptyRect(rect)){
        //we operate on all of our NSBitmapImageRep representations; otherwise we loose either @1x or @2x representation
        for (NSBitmapImageRep *rep in image.representations) {
            //skip and non bitmap image reps
            if (![rep isKindOfClass:[NSBitmapImageRep class]]) continue;
            
            //scale the captureRect for the current representation because CGImage only works in pixels
            CGFloat scaleFactor =  rep.pixelsHigh / rep.size.height;
            CGRect captureRect = CGRectMake(scaleFactor * rect.origin.x, scaleFactor * rect.origin.y, scaleFactor * rect.size.width, scaleFactor * rect.size.height);
            
            //flip our y axis, because CGImage's origin is top-left
            captureRect.origin.y = rep.pixelsHigh - captureRect.origin.y - captureRect.size.height;
            
            CGImageRef cgImage = CGImageCreateWithImageInRect(rep.CGImage, captureRect);
            if (!cgImage){
                NSLog(@"RHImageByReferencingRectOfExistingImage: Error: Failed to create CGImage with CGImageCreateWithImageInRect() for imageRep:%@, rect:%@.", rep, NSStringFromRect(NSRectFromCGRect(captureRect)));
                continue;
            }
            
            //create a new BitmapImageRep for the new CGImage. The CGImage just points to the large image, so no pixels are copied by this operation
            NSBitmapImageRep *newRep = [[NSBitmapImageRep alloc] initWithCGImage:cgImage];
            [newRep setSize:rect.size];
            CGImageRelease(cgImage);
            [newImage addRepresentation:newRep];
            arc_release(newRep);
        }
    }
    
    [newImage recache];
    return arc_autorelease(newImage);
    
}


NSArray* RHNinePartPiecesFromImageWithInsets(NSImage *image, RHEdgeInsets capInsets){
    
    CGFloat imageWidth = image.size.width;
    CGFloat imageHeight = image.size.height;
    
    CGFloat leftCapWidth = capInsets.left;
    CGFloat topCapHeight = capInsets.top;
    CGFloat rightCapWidth = capInsets.right;
    CGFloat bottomCapHeight = capInsets.bottom;
    
    NSSize centerSize = NSMakeSize(imageWidth - leftCapWidth - rightCapWidth, imageHeight - topCapHeight - bottomCapHeight);
    
    
    NSImage *topLeftCorner = RHImageByReferencingRectOfExistingImage(image, NSMakeRect(0.0f, imageHeight - topCapHeight, leftCapWidth, topCapHeight));
    NSImage *topEdgeFill = RHImageByReferencingRectOfExistingImage(image, NSMakeRect(leftCapWidth, imageHeight - topCapHeight, centerSize.width, topCapHeight));
    NSImage *topRightCorner = RHImageByReferencingRectOfExistingImage(image, NSMakeRect(imageWidth - rightCapWidth, imageHeight - topCapHeight, rightCapWidth, topCapHeight));
    
    NSImage *leftEdgeFill = RHImageByReferencingRectOfExistingImage(image, NSMakeRect(0.0f, bottomCapHeight, leftCapWidth, centerSize.height));
    NSImage *centerFill = RHImageByReferencingRectOfExistingImage(image, NSMakeRect(leftCapWidth, bottomCapHeight, centerSize.width, centerSize.height));
    NSImage *rightEdgeFill = RHImageByReferencingRectOfExistingImage(image, NSMakeRect(imageWidth - rightCapWidth, bottomCapHeight, rightCapWidth, centerSize.height));
    
    NSImage *bottomLeftCorner = RHImageByReferencingRectOfExistingImage(image, NSMakeRect(0.0f, 0.0f, leftCapWidth, bottomCapHeight));
    NSImage *bottomEdgeFill = RHImageByReferencingRectOfExistingImage(image, NSMakeRect(leftCapWidth, 0.0f, centerSize.width, bottomCapHeight));
    NSImage *bottomRightCorner = RHImageByReferencingRectOfExistingImage(image, NSMakeRect(imageWidth - rightCapWidth, 0.0f, rightCapWidth, bottomCapHeight));
    
    return [NSArray arrayWithObjects:topLeftCorner, topEdgeFill, topRightCorner, leftEdgeFill, centerFill, rightEdgeFill, bottomLeftCorner, bottomEdgeFill, bottomRightCorner, nil];
}


CGFloat RHContextGetDeviceScale(CGContextRef context){
    CGSize backingSize = CGContextConvertSizeToDeviceSpace(context, CGSizeMake(1.0f, 1.0f));
    return backingSize.width;
}

//==========
#pragma mark - nine part



void RHDrawNinePartImage(NSRect frame, NSImage *topLeftCorner, NSImage *topEdgeFill, NSImage *topRightCorner, NSImage *leftEdgeFill, NSImage *centerFill, NSImage *rightEdgeFill, NSImage *bottomLeftCorner, NSImage *bottomEdgeFill, NSImage *bottomRightCorner, NSCompositingOperation op, CGFloat alphaFraction, BOOL shouldTile){
    
    CGFloat imageWidth = frame.size.width;
    CGFloat imageHeight = frame.size.height;
    
    CGFloat leftCapWidth = topLeftCorner.size.width;
    CGFloat topCapHeight = topLeftCorner.size.height;
    CGFloat rightCapWidth = bottomRightCorner.size.width;
    CGFloat bottomCapHeight = bottomRightCorner.size.height;
    
    NSSize centerSize = NSMakeSize(imageWidth - leftCapWidth - rightCapWidth, imageHeight - topCapHeight - bottomCapHeight);
    
    NSRect topLeftCornerRect = NSMakeRect(0.0f, imageHeight - topCapHeight, leftCapWidth, topCapHeight);
    NSRect topEdgeFillRect = NSMakeRect(leftCapWidth, imageHeight - topCapHeight, centerSize.width, topCapHeight);
    NSRect topRightCornerRect = NSMakeRect(imageWidth - rightCapWidth, imageHeight - topCapHeight, rightCapWidth, topCapHeight);
    
    NSRect leftEdgeFillRect = NSMakeRect(0.0f, bottomCapHeight, leftCapWidth, centerSize.height);
    NSRect centerFillRect = NSMakeRect(leftCapWidth, bottomCapHeight, centerSize.width, centerSize.height);
    NSRect rightEdgeFillRect = NSMakeRect(imageWidth - rightCapWidth, bottomCapHeight, rightCapWidth, centerSize.height);
    
    NSRect bottomLeftCornerRect = NSMakeRect(0.0f, 0.0f, leftCapWidth, bottomCapHeight);
    NSRect bottomEdgeFillRect = NSMakeRect(leftCapWidth, 0.0f, centerSize.width, bottomCapHeight);
    NSRect bottomRightCornerRect = NSMakeRect(imageWidth - rightCapWidth, 0.0f, rightCapWidth, bottomCapHeight);
    
    
    RHDrawImageInRect(topLeftCorner, topLeftCornerRect, op, fraction, NO);
    RHDrawImageInRect(topEdgeFill, topEdgeFillRect, op, fraction, shouldTile);
    RHDrawImageInRect(topRightCorner, topRightCornerRect, op, fraction, NO);
    
    RHDrawImageInRect(leftEdgeFill, leftEdgeFillRect, op, fraction, shouldTile);
    RHDrawImageInRect(centerFill, centerFillRect, op, fraction, shouldTile);
    RHDrawImageInRect(rightEdgeFill, rightEdgeFillRect, op, fraction, shouldTile);
    
    RHDrawImageInRect(bottomLeftCorner, bottomLeftCornerRect, op, fraction, NO);
    RHDrawImageInRect(bottomEdgeFill, bottomEdgeFillRect, op, fraction, shouldTile);
    RHDrawImageInRect(bottomRightCorner, bottomRightCornerRect, op, fraction, NO);

}

void RHDrawImageInRect(NSImage* image, NSRect rect, NSCompositingOperation op, CGFloat fraction, BOOL tile){
    if (tile){
        RHDrawTiledImageInRect(image, rect, op, fraction);
    } else {
        RHDrawStretchedImageInRect(image, rect, op, fraction);
    }
}

void RHDrawTiledImageInRect(NSImage* image, NSRect rect, NSCompositingOperation op, CGFloat fraction){
    CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
    CGContextSaveGState(context);
    
    [[NSGraphicsContext currentContext] setCompositingOperation:op];
    CGContextSetAlpha(context, fraction);
    
    //pass in the images actual size in points rather than rect. This gives us the actual best representation for the current context. if we passed in rect directly, we would always get the @2x representation because NSImage assumes more pixels are always better.
    NSRect outRect = NSMakeRect(0.0f, 0.0f, image.size.width, image.size.height);
    CGImageRef imageRef = [image CGImageForProposedRect:&outRect context:[NSGraphicsContext currentContext] hints:NULL];
    
    CGContextClipToRect(context, NSRectToCGRect(rect));
    CGContextDrawTiledImage(context, CGRectMake(rect.origin.x, rect.origin.y, image.size.width, image.size.height), imageRef);
    
    CGContextRestoreGState(context);
}

void RHDrawStretchedImageInRect(NSImage* image, NSRect rect, NSCompositingOperation op, CGFloat fraction){
    CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
    CGContextSaveGState(context);
    
    [[NSGraphicsContext currentContext] setCompositingOperation:op];
    CGContextSetAlpha(context, fraction);
    
    //we pass in the images actual size rather than rect. if we passed in rect directly, we would always get the @2x ref. (10.8s workaround for single axis stretching was -[NSImage matchesOnlyOnBestFittingAxis], however this wont work for stretching in 2 dimensions)
    NSRect outRect = NSMakeRect(0.0f, 0.0f, image.size.width, image.size.height);
    CGImageRef imageRef = [image CGImageForProposedRect:&outRect context:[NSGraphicsContext currentContext] hints:NULL];
    
    CGContextClipToRect(context, NSRectToCGRect(rect));
    CGContextDrawImage(context, NSRectToCGRect(rect), imageRef);
    
    CGContextRestoreGState(context);
}



