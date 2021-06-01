//
//  RHAdditions.h
//  RHAdditions
//
//  Created by Richard Heard on 7/04/13.
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


#ifdef __APPLE__
#import "TargetConditionals.h"
#endif

//don't include private stuff in App Store builds
#if !defined(INCLUDE_PRIVATE_API)
#define INCLUDE_PRIVATE_API 0
#endif

//common
#import "RHARCSupport.h"
#import "RHLoggingSupport.h"

#import "NSArray+RHFirstObjectAdditions.h"
#import "NSArray+RHNumberAdditions.h"
#import "NSDate+RHCalendarAdditions.h"
#import "NSDictionary+RHNumberAdditions.h"
#import "NSJSONSerialization+RHTypeAdditions.h"
#import "NSObject+RHClassInfoAdditions.h"
#import "NSString+RHCaseAdditions.h"
#import "NSString+RHNumberAdditions.h"
#import "NSString+RHRot13Additions.h"
#import "NSString+RHURLEncodingAdditions.h"
#import "NSThread+RHBlockAdditions.h"
#import "NSUserDefaults+RHColorAdditions.h"

//objects
#import "RHGoogleURLShortener.h"
#import "RHProgressiveURLConnection.h"
#import "RHWeakSelectorForwarder.h"
#import "RHWeakValue.h"

#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
//ios only
#import "UIApplication+RHStatusBarBoundsAdditions.h"
#import "UIColor+RHInterpolationAdditions.h"
#import "UIDevice+RHDeviceIdentifierAdditions.h"
#import "UIImage+RHComparingAdditions.h"
#import "UIImage+RHPixelAdditions.h"
#import "UIImage+RHResizingAdditions.h"
#import "UILabel+RHSizeAdditions.h"
#import "UIView+RHCompletedActionBadgeAdditions.h"
#import "UIView+RHSnapshotAdditions.h"

#else
//mac only
#import "NSAlert+RHBlockAdditions.h"
#import "NSBundle+RHLaunchAtLoginAdditions.h"
#import "NSImage+RHImageRepresentationAdditions.h"
#import "NSImage+RHResizableImageAdditions.h"
#import "NSImageView+RHImageLoadingAdditions.h"
#import "NSImageView+RHImageRectAdditions.h"
#import "NSTextField+RHLabelAdditions.h"
#import "NSTextField+RHSizeAdditions.h"
#import "NSView+RHSnapshotAdditions.h"
#import "NSWindow+RHPreventCaptureAdditions.h"
#import "NSWindow+RHResizeAdditions.h"
#import "RHGetBSDProcessList.h"
#import "RHDraggableImageView.h"

#endif

