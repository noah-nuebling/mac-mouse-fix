//
// --------------------------------------------------------------------------
// NSImage+Additions.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "NSImage+Additions.h"
#import "Accelerate/Accelerate.h"
#import "MFDefer.h"

@implementation NSImage (Additions)

/// MARK: - Macros

#define loopc(i, n) \
    for (typeof(n+0) i = 0 ; i < (n) ; i++)

#define MF_CGImage_rect(cgImage) \
    NSMakeRect(0, 0, CGImageGetWidth(cgImage), CGImageGetHeight(cgImage))

/// MARK: - RGBAContext

/// Discussion: [Jun 28 2025]
///     Methods for directly manipulating an image at the RGBA pixel level.
///     I just wrote this [Jun 2025] but its unused.
///     Why did I write this?: I made   the `RGBAContext` stuff because I wanted to display an SFSymbol-like icon containing the AppStore logo in the effect-popUpButtons of the RemapsTable to symbolize the new "Show Apps" action in macOS Tahoe (which replaced Launchpad). Xcode uses this symbol in its menuBar (under macOS Tahoe Beta 2), and I extracted a similar-looking .png file from a .car file found in Xcode. However, this .png had pretty low opacity. I made this method to manipulate the opacity directly at the pixel level – without the abstraction layers.
///         Result: [Jun 28 2025] This seems to work, but it doesn't quite look right ... But we found another AppStoreIcon in another Xcode `.car` file which is fully opaque and looks perfect! So as of now all this `RGBAContext` stuff is unused.
///     Caution: This isn't tested or super-well-thought-through! So review it before using in production.

void MF_RGBAPixel_setA(MF_RGBAPixel *px, uint8_t newAlpha) {
        
    /// The r, g, and b values are *premultiplied* with the alpha value. So if you want to change a, don't forget to also change the r, g, and b values using the formula:`x = x / old_a * new_a` - `MF_RGBAPixel_setA()` does that for you.
        
    if ( !((0 <= newAlpha) && (newAlpha <= UINT8_MAX)) ) {
        assert(false); return;
    }
        
    uint8_t a0 = px->a;
    uint8_t a1 = newAlpha;

    px->r = round((double)px->r * a1 / a0);
    px->g = round((double)px->g * a1 / a0);
    px->b = round((double)px->b * a1 / a0);
    
    px->a = a1;
}

CGContextRef MF_CGImage_createRGBAContext(CGImageRef cgImage) {
    
    /// Returns a CGBitmapContext containing an array of `width * height` pixels represented by `MF_RGBAPixel` instances
    ///     Use `CGBitmapContextGetData()` to get the pixel buffer.
    ///     Use `CGBitmapContextGetWidth()` and `CGBitmapContextGetHeight()` to get the dimensions of the pixel grid.
    ///     Use `MF_RGBAPixel_setA()` to manipulate the alpha values.
    ///     Use `CGBitmapContextCreateImage()` to create a new image from the manipulated pixel buffer.
    ///
    /// Research notes from when I tried to figure out how to do pixel-level manipulation on NSImage:
    ///     - Image+Trim.swift: https://gist.github.com/chriszielinski/aec9a2f2ba54745dc715dd55f5718177
    ///     - https://stackoverflow.com/questions/74822880/manipulate-pixels-in-nsimage-swift
    ///     - Quartz 2d Programming Guide:
    ///         - Link: https://developer.apple.com/library/archive/documentation/GraphicsImaging/Conceptual/drawingwithquartz2d/dq_images/dq_images.html#//apple_ref/doc/uid/TP30001066-CH212-TPXREF101
    ///         - Section: **Bitmap Images  and Image Masks**
    ///             - Tells you to use `vImageBuffer_InitWithCGImage` for raw pixel operations
    ///         - Section: **Creating a Bitmap Graphics Context**
    ///             - Shows how to create a `CGBitmapContext` and do higher-level drawing operations on it (But it also supports pixel-level drawing.)
    ///     CGBitmapContext Reference:
    ///         https://leopard-adc.pepas.com/documentation/GraphicsImaging/Reference/CGBitmapContext/CGBitmapContext.pdf
    ///     Discussion of different APIs for direct pixel manipulation:
    ///         - https://developer.apple.com/forums/thread/99319
    ///         - (CGImageRef, NSBitmapImage, CVPixelBuffer, Metal)
    ///     vImage Docs: (Another API for direct pixel manipulation)
    ///         - Accelerate Release Notes: https://developer.apple.com/library/archive/releasenotes/Performance/RN-vecLib/index.html#//apple_ref/doc/uid/TP40001049
    ///         - `vImageBuffer_InitWithCGImage` docs:
    ///         - Tested the vImage API, but ...
    ///             - all the documentation is for Swift and `vImage_Buffer.free()` doesn't exist in objc. ... And this SO post reports memory leaks: https://stackoverflow.com/questions/29266444/correctly-freeing-a-buffer-from-vimagebuffer-initwithcvpixelbuffer
    ///                 ... This is too fishy for me.
    ///     Since iOS 8, non-premultiplied BitmapContexts aren't allowed:
    ///         https://github.com/IFTTT/FastttCamera/issues/71
    ///
    
    #define fail() \
        ({ assert(false); return NULL; });
    
    /// NULL safety
    if (!cgImage) fail();
    
    /// Get pixel dimensions of image
    size_t h = CGImageGetHeight(cgImage);
    size_t w = CGImageGetWidth(cgImage);

    /// Get colorSpace
    __block CGColorSpaceRef colorSpace = CGImageGetColorSpace(cgImage); /// Not totally sure
    MFDefer ^{ CGColorSpaceRelease(colorSpace); };
    if (!colorSpace) fail();

    /// Create bitmap drawing context and draw our cgImage into it.
    CGContextRef result = NULL;
    ({
        void *contextBufferPtr = NULL;
        result = CGBitmapContextCreate(
                                    contextBufferPtr                        ,
                                    w                                       ,
                                    h                                       ,
                                    8 * sizeof(uint8_t)                     , /// Bits per component
                                    w * 4 * sizeof(uint8_t)                 , /// Bytes per row
                                    colorSpace                              ,
                                    (CGBitmapInfo)(kCGImageAlphaPremultipliedLast));
        
        if (!result) fail();
        CGContextDrawImage(result, MF_CGImage_rect(cgImage), cgImage);
    });
    
    return result;
}

- (CGContextRef) mf_createRGBAContext {
    
    __block CGImageRef cgImage = [self CGImageForProposedRect: nil context: nil hints: nil];
    MFDefer ^{ if (cgImage) CFRelease(cgImage); };
    
    CGContextRef bmContext = MF_CGImage_createRGBAContext(cgImage);
    
    return bmContext;
}

+ (instancetype) mf_newWithRGBAContext: (CGContextRef) bmContext {
    CGImageRef newImageCG = CGBitmapContextCreateImage(bmContext);
    if (!newImageCG) return nil;
    NSImage *newImageNS = [[NSImage alloc]
        initWithCGImage: newImageCG
        size: NSMakeSize(CGBitmapContextGetWidth(bmContext), CGBitmapContextGetHeight(bmContext))];
    if (newImageCG) CFRelease(newImageCG);
    return newImageNS;
}

- (instancetype) mf_imageByModifyingRGBAPixels: (void (^) (MF_RGBAPixel *px, size_t x, size_t y, size_t w, size_t h)) modifierBlock {
    
    assert(false); /// All this RGBA stuff is unused and untested as of [Jul 2025]
    
    /// Sidenotes:
    ///     I just found CIColorMatrix – it seems to have similar capabilities to this
    ///
    /// Usage example:
    /// ```
    ///  symbol =  [symbol mf_imageByModifyingRGBAPixels: ^(MF_RGBAPixel *px, size_t x, size_t y, size_t w, size_t h) {
    ///      MF_RGBAPixel_setA(px, MIN(255, px->a * 1.5));
    ///  }];
    /// ```
    
    #undef fail
    #define fail() \
        ({ assert(false); return self; })
    
    /// Create BitmapContext
    __block CGContextRef bmContext = [self mf_createRGBAContext];
    MFDefer ^{ CGContextRelease(bmContext); };
    if (!bmContext) fail();
    
    /// Get pixel buffer
    size_t h = CGBitmapContextGetHeight(bmContext);
    size_t w = CGBitmapContextGetWidth(bmContext);
    MF_RGBAPixel *buf = CGBitmapContextGetData(bmContext);
    if (!buf) fail();
    
    /// Modify pixel buffer
    loopc(y, h) loopc(x, w) {
        MF_RGBAPixel *px = buf + (y*w + x);
        modifierBlock(px, x, y, w, h);
    }
        
    /// Create new image from context
    NSImage *result = [NSImage mf_newWithRGBAContext: bmContext];
    
    /// Return
    return result;
}

// MARK: - Color tinting

- (NSImage * )coolTintedImage:(NSImage *)inputImage color:(NSColor *)color {
    
    /// Create a copy of `inputImage` with tint of `color`
    /// - We're creating this because when we render fallback images for SFSymbols in we need to color those images like the surrounding text, and I haven't found API methods for this on older macOS versions. (`NSImageSymbolConfiguration` was only introduced in macOS 11.0)
    ///     - Update: [Jun 2025] Under Tahoe Beta 2, we can just use `NSImage.template = YES` instead of this. Also this messed up the sizing on custom symbols we made, so we replaced its usage with `NSImage.template = YES`. Not 100% sure this also works on older macOS versions.
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
