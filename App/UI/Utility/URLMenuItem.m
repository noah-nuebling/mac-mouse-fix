//
// --------------------------------------------------------------------------
// URLMenuItem.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "URLMenuItem.h"

/// A menu item which opens a URL when it's clicked. The URL is configurable in Interface Builder

@interface URLMenuItem ()

@property (nonatomic) IBInspectable NSString *URLString;
/// ^ Don't know why this is nonatomic. Copied it from https://stackoverflow.com/questions/24465679/xcode6-ibdesignable-and-ibinspectable-with-objective-c

@end

@implementation URLMenuItem

- (void)awakeFromNib {
    /// Could maybe also use initWithCoder: here

    /// Awake super
    
    [super awakeFromNib];
    
    /// Set action to opening the URL
    
    BOOL enable = self.URLString.length > 0;
    
    [self setEnabled:enable];
    
    if (enable) {
        [self setTarget:self];
        [self setAction:@selector(openURLL:)];
    }
}


- (IBAction)openURLL:(URLMenuItem *)sender {
    [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:self.URLString]];
    
    
}

@end
