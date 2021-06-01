//
//  NSImage+RHImageRepresentationAdditions.m
//
//  Created by Richard Heard on 2/07/12.
//  Copyright (c) 2012 Richard Heard. All rights reserved.
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

#import "NSImage+RHImageRepresentationAdditions.h"
#import "RHARCSupport.h"

@implementation NSImage (RHImageRepresentationAdditions)

-(NSData*)PNGRepresentation{
    return RHImagePNGRepresentationForImage(self);
}

-(NSData*)JPEGRepresentationWithCompressionFactor:(float)compressionFactor{
    return RHImageJPEGRepresentationForImage(self, compressionFactor);
}

-(NSData*)GIFRepresentation{
    return RHImageGIFRepresentationForImage(self);
}
-(NSData*)bestRepresentation{
    return RHImageBestRepresentationForImage(self);
}

@end



NSData* RHImagePNGRepresentationForImage(NSImage* image){

    //bail if its a crazy size.
    if (image.size.width > 5000 || image.size.height > 5000) return nil;

    //check to make sure we have a bitmap image rep
    NSBitmapImageRep *imageRep = [[image representations] lastObject];
    if (! [imageRep isKindOfClass:[NSBitmapImageRep class]]){
    
        [image lockFocus];

        NSRect rect = NSMakeRect(0, 0, image.size.width, image.size.height);
        imageRep = arc_autorelease([[NSBitmapImageRep alloc] initWithFocusedViewRect:rect]);
        
        [image unlockFocus];
    }
    
    return [imageRep representationUsingType:NSPNGFileType properties:nil];
}


NSData* RHImageJPEGRepresentationForImage(NSImage* image, float compressionFactor){
    
    
    //check to make sure we have a bitmap image rep
    NSBitmapImageRep *imageRep = [[image representations] lastObject];
    if (! [imageRep isKindOfClass:[NSBitmapImageRep class]]){
        
        [image lockFocus];
        
        NSRect rect = NSMakeRect(0, 0, image.size.width, image.size.height);
        imageRep = arc_autorelease([[NSBitmapImageRep alloc] initWithFocusedViewRect:rect]);
        
        [image unlockFocus];
    }
    
    NSDictionary *options = [NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:compressionFactor] forKey:NSImageCompressionFactor];

    return [imageRep representationUsingType:NSJPEGFileType properties:options];
    
}

NSData* RHImageGIFRepresentationForImage(NSImage* image){
    
    //check to make sure we have a bitmap image rep
    NSBitmapImageRep *imageRep = [[image representations] lastObject];
    if (! [imageRep isKindOfClass:[NSBitmapImageRep class]]){
        
        [image lockFocus];
        
        NSRect rect = NSMakeRect(0, 0, image.size.width, image.size.height);
        imageRep = arc_autorelease([[NSBitmapImageRep alloc] initWithFocusedViewRect:rect]);
        
        [image unlockFocus];
    }
    
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], NSImageDitherTransparency,
                             [imageRep valueForProperty:NSImageRGBColorTable], NSImageRGBColorTable, nil];

    return [imageRep representationUsingType:NSGIFFileType properties:options];
    
    
    //prototype animated GIF support. 
#if 0
    
    // new imp

    //NSImageFrameCount
    int frameCount = [[imageRep valueForProperty:NSImageFrameCount] intValue];
    //NSImageLoopCount
    int loopCount = [[imageRep valueForProperty:NSImageLoopCount] intValue];
    //NSImageDitherTransparency
    BOOL ditherTransparency = [[imageRep valueForProperty:NSImageDitherTransparency] boolValue];
    
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithInt:loopCount] ,(NSString *) kCGImagePropertyGIFLoopCount,
                             nil];
    options = [NSDictionary dictionaryWithObject:options forKey:(NSString *)kCGImagePropertyGIFDictionary];

    
    NSMutableData *mutableImageData = [NSMutableData data];
    
    
    //TODO: this shit is getting washed out compared to the original GIF
    CGImageDestinationRef destRef = CGImageDestinationCreateWithData((CFMutableDataRef)mutableImageData, kUTTypeGIF, frameCount, (CFDictionaryRef)options);
    
    for (int i = 0; i < frameCount; i++) {

        [imageRep setProperty:NSImageCurrentFrame withValue:[NSNumber numberWithInt:i]];

        //NSImageCurrentFrame
        int currentFrame = [[imageRep valueForProperty:NSImageCurrentFrame] intValue];
        //NSImageCurrentFrameDuration
        float currentFrameDuration = [[imageRep valueForProperty:NSImageCurrentFrameDuration] floatValue];
        

        NSDictionary *frameOptions = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:currentFrameDuration] forKey:(NSString *) kCGImagePropertyGIFDelayTime];
        frameOptions = [NSDictionary dictionaryWithObject:frameOptions forKey:(NSString *)kCGImagePropertyGIFDictionary];
        
        
        
        CGImageDestinationAddImage(destRef, [imageRep CGImage], (CFDictionaryRef)frameOptions);
        
    }
    

    CGImageDestinationSetProperties(destRef, (CFDictionaryRef) options);
    CGImageDestinationFinalize(destRef);
    CFRelease(destRef);
    
    return  mutableImageData;
    
#endif
    
}


NSData* RHImageBestRepresentationForImage(NSImage* image){
        
    //if we have a GIF frame count, save as a GIF, otherwise save as PNG
    NSBitmapImageRep *imageRep = [[image representations] lastObject];
    int frameCount = [[imageRep valueForProperty:NSImageFrameCount] intValue];
    
    if (frameCount > 1){
        return RHImageGIFRepresentationForImage(image);
    }

    return RHImagePNGRepresentationForImage(image);
        
}

//include an implementation in this file so we don't have to use -load_all for this category to be included in a static lib
@interface RHFixCategoryBugClassNSIRHIRA : NSObject @end @implementation RHFixCategoryBugClassNSIRHIRA @end

