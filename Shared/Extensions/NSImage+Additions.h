//
// --------------------------------------------------------------------------
// NSImage+Additions.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSImage (Additions)

typedef struct {
    uint8_t r, g, b, a;
} MF_RGBAPixel;
void MF_RGBAPixel_setA(MF_RGBAPixel *px, uint8_t newAlpha);
- (instancetype) mf_imageByModifyingRGBAPixels: (void (^) (MF_RGBAPixel *px, size_t x, size_t y, size_t w, size_t h)) modifierBlock;

- (NSImage *)coolTintedImage:(NSImage *)image color:(NSColor *)color;

@end

NS_ASSUME_NONNULL_END
