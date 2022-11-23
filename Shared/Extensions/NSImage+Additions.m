//
// --------------------------------------------------------------------------
// NSImage+Additions.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

#import "NSImage+Additions.h"

@implementation NSImage (Additions)

- (NSImage * )coolTintedImage:(NSImage *)inputImage color:(NSColor *)color {
    
    /// Create a copy of `inputImage` with tint of `color`
    /// - We're creating this because when we render fallback images for SFSymbols in we need to color those images like the surrounding text, and I haven't found API methods for this on older macOS versions. (`NSImageSymbolConfiguration` was only introduced in macOS 11.0)
    ///
    /// Sources:
    /// - https://stackoverflow.com/a/29041548/10601702
    /// - https://stackoverflow.com/a/12911400/10601702
    /// - https://stackoverflow.com/q/25655082/10601702
    
    /// Create empty resultImage
    ///     Copy and then remove representations so that other properties like alignmentRect are retained.
    
    NSImage *resultImage = [inputImage copy];
    for (NSImageRep *rep in resultImage.representations) {
        [resultImage removeRepresentation:rep];
    }
    
    ///
    /// Draw
    ///
    
    /// Push context
    ///     For drawing to the resultImage
    [resultImage lockFocus];
    
    /// Get shorthand for context
//    NSGraphicsContext *ctx = NSGraphicsContext.currentContext;
    
    /// Get frame for drawing
    NSRect drawingFrame = NSMakeRect(0.0, 0.0, inputImage.size.width, inputImage.size.height);
    
    /// Draw orginal image
    [inputImage drawInRect:drawingFrame];
    
    /// Draw `color` where `inputImage` is opaque
    [color setFill];
    NSRectFillUsingOperation(drawingFrame, NSCompositingOperationSourceIn);

    /// Pop drawing context
    [resultImage unlockFocus];
    
    /// Copy over representation size
    /// Notes:
    /// - Doesn't work
    /// - We we're trying to fix the vertical alignment when rendering the image in an NSAttributedString via NSTextAttachment. The v-alignment works when you use NSImages representing SFSymbols, but after we create a tinted copy, the v-alignment will be weird. We ended up fixing this by setting the NSTextAttachment bounds.
    /// - Setting resultImage.alignmentRect won't change the textRendering alignment, either.
    
//    NSImageRep *inputRep = inputImage.representations[0]; /// Not sure if just choosing the first rep is sufficient
//    NSImageRep *resultRep = resultImage.representations[0]; /// There should be only one rep - the one we just created
//
//    resultRep.size = inputRep.size;
//    resultRep.layoutDirection = inputRep.layoutDirection;
//    resultRep.pixelsHigh = inputRep.pixelsHigh;
//    resultRep.pixelsWide = inputRep.pixelsWide;
    
    /// Return
    return resultImage;
}

@end
