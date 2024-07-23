//
// --------------------------------------------------------------------------
// LocalizedStringAnnotation.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "LocalizedStringAnnotation.h"
#import "AnnotationUtility.h"

@implementation LocalizedStringAnnotation

#if ANNOTATE_LOCALIZED_STRINGS

+ (void)load {
    
    swizzleMethodOnClassAndSubclasses([NSBundle class], @{ @"framework": @"AppKit" }, @selector(<#selector#>), MakeInterceptorFactory(<#returnType#>, (<#argumentList#>), {
        <#onInterception#>
    }));
    
}

#endif

@end
