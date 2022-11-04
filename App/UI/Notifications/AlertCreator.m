//
// --------------------------------------------------------------------------
// AlertCreator.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "AlertCreator.h"
#import "NSAttributedString+Additions.h"

#pragma mark - NSAlert subclass

@interface MFAlert : NSAlert<NSWindowDelegate> {
    @public BOOL stayOnTop; /// Instance vars are automatically initialized to 0 aka NO
}
    
@end

@implementation MFAlert

//- (void)windowDidBecomeKey:(NSNotification *)notification {
//
//    /// Notes:
//    /// - didBecomeMain is never called
//
//    /// Invoke super implementation
//
//    if ([self.class.superclass instancesRespondToSelector:_cmd]) {
//        IMP imp = [self.class.superclass instanceMethodForSelector:_cmd];
//        if (imp != NULL) {
//            void (*imp2)(id, SEL, NSNotification *) = (void *)imp;
//            imp2(self, _cmd, notification);
//        }
//    }
//
//    /// Make window on top of EVERYTHING
//
//    static BOOL didIt = NO;
//    if (!didIt) {
//        self.window.level = NSFloatingWindowLevel;
////        [self.window orderOut:nil];
//        [self.window orderFrontRegardless];
////        [self.window orderWindow:NSWindowAbove relativeTo:0];
//        didIt = YES;
//    }
//
//}

- (void)windowDidResignKey:(NSNotification *)notification {

    /// Notes:
    /// - This is a hack to keep the Alert window always on top of all other windows. This is very ugly. We managed to achieve always-on-top another way for OverridePanel, but I don't know what we did there. I also tried calling just`orderFrontRegardless` on `windowDidBecomeKey` but it didn't work. `windowDidBecomeMain` is never called
    
    /// Invoke super implementation

    if ([self.class.superclass instancesRespondToSelector:_cmd]) {
        IMP imp = [self.class.superclass instanceMethodForSelector:_cmd];
        if (imp != NULL) {
            void (*imp2)(id, SEL, NSNotification *) = (void *)imp;
            imp2(self, _cmd, notification);
        }
    }

    /// Keep window on top
    if (stayOnTop) {
        self.window.level = NSFloatingWindowLevel;
        [self.window orderFrontRegardless];
    }

}

@end

#pragma mark - AlertCreator

@implementation AlertCreator

+ (void)showAlertWithTitle:(NSString *)title markdownBody:(NSString *)bodyRaw maxWidth:(int)maxWidth style:(NSAlertStyle)style isAlwaysOnTop:(BOOL)isAlwaysOnTop {
    
    /// Override body alignment
    
    NSAttributedString *body = [NSAttributedString attributedStringWithCoolMarkdown:bodyRaw];
    if (@available(macOS 11.0, *)) {
        body = [body attributedStringByAligningSubstring:nil alignment:NSTextAlignmentCenter];
    } else {
        body = [body attributedStringByAligningSubstring:nil alignment:NSTextAlignmentNatural];
    }
    
    /// Create alert
    
    MFAlert *alert = [[MFAlert alloc] init];
    
    /// Set alert stye
    alert.alertStyle = style;
    
    /// Make alert alway-on-top
    alert->stayOnTop = isAlwaysOnTop;
    
    /// Set title
    alert.messageText = title;
    
    /// Create view for body
    NSTextView *bodyView = [[NSTextView alloc] init];
    bodyView.editable = NO;
    bodyView.drawsBackground = NO;
    [bodyView.textStorage setAttributedString:body];
    [bodyView setFrameSize:[body sizeAtMaxWidth:maxWidth]];
    
    /// Set alert body
    alert.accessoryView = bodyView;
    
    /// Show alert
    [alert runModal];
}

@end
