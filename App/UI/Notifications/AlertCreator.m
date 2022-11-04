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

@implementation AlertCreator

+ (NSAlert *)alertWithTitle:(NSString *)title markdownBody:(NSString *)bodyRaw maxWidth:(int)maxWidth style:(NSAlertStyle)style isAlwaysOnTop:(BOOL)isAlwaysOnTop {
    
    NSAttributedString *body = [NSAttributedString attributedStringWithCoolMarkdown:bodyRaw];
    if (@available(macOS 11.0, *)) {
        body = [body attributedStringByAligningSubstring:nil alignment:NSTextAlignmentCenter];
    } else {
        body = [body attributedStringByAligningSubstring:nil alignment:NSTextAlignmentNatural];
    }
    
    /// Create alert
    
    NSAlert *alert = [[NSAlert alloc] init];
    
    /// Set alert stye
    alert.alertStyle = style;
    
    /// Make alert alway-on-top
    ///     This doesn't work under 13.0
    alert.window.level = CGWindowLevelForKey(isAlwaysOnTop ? kCGFloatingWindowLevelKey : kCGNormalWindowLevelKey);
    
    /// Set alert title
    alert.messageText = title;
    
    /// Create view for alert body
    NSTextView *bodyView = [[NSTextView alloc] init];
    bodyView.editable = NO;
    bodyView.drawsBackground = NO;
    [bodyView.textStorage setAttributedString:body];
    [bodyView setFrameSize:[body sizeAtMaxWidth:maxWidth]];
    
    /// Set alert body
    alert.accessoryView = bodyView;
    return alert;
}

@end
