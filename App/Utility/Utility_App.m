//
// --------------------------------------------------------------------------
// Utility_App.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "Utility_App.h"
#import <AppKit/AppKit.h>
#import "NSArray+Additions.h"
#import "Constants.h"
@import Darwin.sys.sysctl;

@implementation Utility_App

/// Compatibility design

bool MFRunningCompatMode(void) {
    return [NSBundle.mainBundle.infoDictionary[@"UIDesignRequiresCompatibility"] boolValue];
}

/// CGRect NSEdgeInsets

CGRect MFCGRectInset(CGRect rect, NSEdgeInsets insets) {
    rect.origin.x += insets.left;
    rect.origin.y += insets.top;
    rect.size.width  -= (insets.left + insets.right);
    rect.size.height -= (insets.top  + insets.bottom);
    return rect;
}

/// Define dimensions of NSBox
///     Also see `[RemapTableController viewDidLoad]` – In MMF 2, the RemapTable had to line up exactly with an NSBox surrounding it – so some of the same knowledge about NSBox sizes should be encoded there.

#define _MFNSBoxDispatch()                                      \
    if (@available(macOS 26.0, *)) {                            \
        if (MFRunningCompatMode())          goto tahoe_compat;  \
        else                                goto tahoe;         \
    }                                                           \
    else if (@available(macOS 11.0, *))     goto sequoia;       \
    else                                    goto catalina;      \

 CGFloat MFNSBoxCornerRadius(void) {
    
    _MFNSBoxDispatch()
    
    tahoe:          return 13.0; /// Not sure if 12 or 13
    tahoe_compat:   return 6.5;  /// Tahoe Beta 8
    sequoia:        return 5.0;
    catalina:       return 4.0;
};

CALayerCornerCurve MFNSBoxCornerCurve(void) {
    
    _MFNSBoxDispatch()
    
    tahoe:              return kCACornerCurveContinuous;
    tahoe_compat:       return kCACornerCurveCircular;
    sequoia:            return kCACornerCurveCircular;
    catalina:           return kCACornerCurveCircular;
}

NSEdgeInsets MFNSBoxInsets(void) {
        
    /// How far the visible part of the NSBox is inset from the actual view edges.
    ///     Necessary to know for inserting custom views directly into the NSBox.
    
    _MFNSBoxDispatch()
    
    tahoe:          return (NSEdgeInsets){ .top = 0, .bottom = 0,  .left = 0,  .right = 0 };
    tahoe_compat:   return (NSEdgeInsets){ .top = 0, .bottom = 0,  .left = 0,  .right = 0 }; /// Tahoe Beta 8
    sequoia:        return (NSEdgeInsets){ .top = 4, .bottom = 2,  .left = 3,  .right = 3 }; /// [Aug 2025] Trivia: These weird insets only appear on NSPrimaryBox, not NSCustomBox [Aug 2025]
    catalina:       return (NSEdgeInsets){ .top = 4, .bottom = 2,  .left = 3,  .right = 3 }; /// [Aug 2025] Not sure if pixel perfect but MMF 3 looks crappy pre-Big Sur anyways.
}

+ (void)centerWindow:(NSWindow *)win atPoint:(NSPoint)pt {
    
    NSRect frm = win.frame;
    
    NSPoint newOrg;
    newOrg.x = pt.x - (frm.size.width / 2);
    newOrg.y = pt.y - (frm.size.height / 2);
    
    [win setFrameOrigin:newOrg];
}
+ (void)openWindowWithFadeAnimation:(NSWindow *)window fadeIn:(BOOL)fadeIn fadeTime:(NSTimeInterval)time {
    [window makeKeyAndOrderFront: self];
    [window setAlphaValue: fadeIn ? 0.0 : 1.0];
    [NSAnimationContext runAnimationGroup: ^(NSAnimationContext *context) {
        [context setDuration: time];
        [window.animator setAlphaValue:fadeIn ? 1.0 : 0.0];
    } completionHandler:^{
        if (!fadeIn) [window close];
    }];
}
+ (NSPoint)getCenterOfRect:(NSRect)rect {
    NSPoint ctr;
    ctr.x = NSMidX(rect);
    ctr.y = NSMidY(rect);
    
    return ctr;
}
+ (BOOL)appIsInstalled:(NSString *)bundleID {
    NSString *appPath = [NSWorkspace.sharedWorkspace URLForApplicationWithBundleIdentifier:bundleID].path;
    if (appPath) {
        return YES;
    }
    return NO;
}
+ (NSImage *)tintedImage:(NSImage *)image withColor:(NSColor *)tint {
    image = image.copy;
    if (tint) {
        [image lockFocus];
        
        NSRect imageRect = NSMakeRect(0, 0, image.size.width, image.size.height);
        [image drawInRect:imageRect fromRect:imageRect operation:NSCompositingOperationSourceOver fraction:tint.alphaComponent];
        [[tint colorWithAlphaComponent:1] set];
        NSRectFillUsingOperation(imageRect, NSCompositingOperationSourceAtop);
        [image unlockFocus];
    }
    [image setTemplate:NO];
    return image;
}

// Source: https://stackoverflow.com/a/25941139/10601702
+ (CGFloat)actualTextViewWidth:(NSTextView *)textView {
    CGFloat padding = textView.textContainer.lineFragmentPadding;
    CGFloat  actualPageWidth = textView.bounds.size.width - padding * 2;
    return actualPageWidth;
}
//+ (CGFloat)actualTextFieldWidth:(NSTextField *)textField {
    /// Don't know how to make this work
//    [textField sizeToFit]; /// This is wrong, we don't want fittingSize
//    return textField.frame.size.width;
//}

+ (NSArray <NSNumber *> * _Nullable)cpuUsageIncludingNice:(BOOL)includeNice {
    
    /// Source: https://stackoverflow.com/a/6795612/10601702
    /// Notes:
    /// - The result is an array of numbers each of the numbers represents the % CPU usage of one of the CPU cores of the computer.
    /// - If `includeNice` is false, this function doesn't measure CPU usage with a positive nice value - positive nice means that it has a lower than average priority and therefore won't block processes with average or above average priority.
    /// - At the time of writing, I think the first time this is called, it will give the average CPU usage for each core since boot. After that it will give the average CPU usage per core since the last invocation.
    ///     - We're currently only using this from GeneralTabController. If we use this from other places, we should proabably make this an instance method with separate state for each instance I think. 
    
    /// 
    /// Get number of CPUs
    ///
    
    static unsigned numCPUs = 0;
    
    if (numCPUs == 0) {
        int mib[2] = { CTL_HW, HW_NCPU };
        size_t sizeOfNumCPUs = sizeof(numCPUs);
        int status = sysctl(mib, 2U, &numCPUs, &sizeOfNumCPUs, NULL, 0U);
        if (status != 0) numCPUs = 1;
    }
    
    /// Declare result\
    
    NSMutableArray *result = [NSMutableArray array];
    
    /// Get processor info
    
    processor_info_array_t cpuInfo = NULL;
    mach_msg_type_number_t numCpuInfo = 0U;
    static processor_info_array_t prevCpuInfo = NULL;
    static mach_msg_type_number_t numPrevCpuInfo = 0U;
    
    natural_t numCPUsU = 0U;
    kern_return_t err = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUsU, &cpuInfo, &numCpuInfo);
    
    /// Guard success
    
    if (err != KERN_SUCCESS) {
        return nil;
    }
        
    /// Build result
    
    for (unsigned i = 0U; i < numCPUs; i++) {
            
        float user      = cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_USER];
        float system    = cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_SYSTEM];
        float nice      = cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_NICE];
        float idle      = cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_IDLE];
            
        if (prevCpuInfo) {
            
            float prevUser      = prevCpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_USER];
            float prevSystem    = prevCpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_SYSTEM];
            float prevNice      = prevCpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_NICE];
            float prevIdle      = prevCpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_IDLE];
            
            user    -= prevUser;
            system  -= prevSystem;
            nice    -= prevNice;
            idle    -= prevIdle;
        }
                    
        float total = user + system + nice + idle;
        float inUse = user + system;
        if (includeNice) inUse += nice;

        [result addObject:@(inUse/total)];
    }

    /// Dealloc prev
    if (prevCpuInfo) {
        size_t prevCpuInfoSize = sizeof(integer_t) * numPrevCpuInfo;
        vm_deallocate(mach_task_self(), (vm_address_t)prevCpuInfo, prevCpuInfoSize);
    }

    /// Replace prev
    prevCpuInfo = cpuInfo;
    numPrevCpuInfo = numCpuInfo;
    
    /// Return result
    return result;
}

@end
