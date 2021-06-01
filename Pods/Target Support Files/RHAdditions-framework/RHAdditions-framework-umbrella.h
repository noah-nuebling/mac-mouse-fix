#ifdef __OBJC__
#import <Cocoa/Cocoa.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "NSArray+RHFirstObjectAdditions.h"
#import "NSArray+RHNumberAdditions.h"
#import "NSBundle+RHLaunchAtLoginAdditions.h"
#import "NSDate+RHCalendarAdditions.h"
#import "NSDictionary+RHNumberAdditions.h"
#import "NSImage+RHImageRepresentationAdditions.h"
#import "NSImage+RHResizableImageAdditions.h"
#import "NSImageView+RHImageLoadingAdditions.h"
#import "NSImageView+RHImageRectAdditions.h"
#import "NSJSONSerialization+RHTypeAdditions.h"
#import "NSObject+RHClassInfoAdditions.h"
#import "NSString+RHCaseAdditions.h"
#import "NSString+RHNumberAdditions.h"
#import "NSString+RHRot13Additions.h"
#import "NSString+RHURLEncodingAdditions.h"
#import "NSTextField+RHLabelAdditions.h"
#import "NSTextField+RHSizeAdditions.h"
#import "NSThread+RHBlockAdditions.h"
#import "NSUserDefaults+RHColorAdditions.h"
#import "NSView+RHSnapshotAdditions.h"
#import "NSWindow+RHPreventCaptureAdditions.h"
#import "NSWindow+RHResizeAdditions.h"
#import "RHAdditions.h"
#import "RHARCSupport.h"
#import "RHDraggableImageView.h"
#import "RHGetBSDProcessList.h"
#import "RHGoogleURLShortener.h"
#import "RHLoggingSupport.h"
#import "RHProgressiveURLConnection.h"
#import "RHWeakSelectorForwarder.h"
#import "RHWeakValue.h"

FOUNDATION_EXPORT double RHAdditionsVersionNumber;
FOUNDATION_EXPORT const unsigned char RHAdditionsVersionString[];

