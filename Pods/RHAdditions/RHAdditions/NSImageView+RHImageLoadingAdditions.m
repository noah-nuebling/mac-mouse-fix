//
//  NSImageView+RHImageLoadingAdditions.m
//
//  Created by Richard Heard on 2/05/13.
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
//

#import "NSImageView+RHImageLoadingAdditions.h"
#import <objc/runtime.h>
#import "RHARCSupport.h"


@interface NSImageView (RHImageLoadingPrivateAdditions) <NSURLConnectionDelegate>
@property (nonatomic, retain) NSURLConnection *fetchConnection;
@property (nonatomic, retain) NSMutableData *fetchData;
@property (nonatomic, retain) NSProgressIndicator *spinner;
@property (nonatomic, retain) NSURL *contentURL;
-(void)showSpinner;
-(void)hideSpinner;
@end

@implementation NSImageView (RHImageLoadingAdditions)

-(void)setImageWithContentsOfURL:(NSURL*)url{
    [self setImageWithContentsOfURL:url placeholderImage:self.placeholderImage errorImage:self.errorImage];
}

-(void)setImageWithContentsOfURL:(NSURL*)url placeholderImage:(NSImage*)placeholderImage{
    [self setImageWithContentsOfURL:url placeholderImage:placeholderImage errorImage:self.errorImage];
}
-(void)setImageWithContentsOfURL:(NSURL*)url placeholderImage:(NSImage*)placeholderImage errorImage:(NSImage*)errorImage{
    if (!url) return;
    
    //dont refetch, for no reason.
    if ([self.contentURL isEqualTo:url] && [self.placeholderImage isEqualTo:placeholderImage] && [self.errorImage isEqualTo:errorImage]) return;

    self.placeholderImage = placeholderImage;
    self.errorImage = errorImage;
    self.contentURL = url;
    
    if (self.placeholderImage){
        self.image = self.placeholderImage;
    }
    
    [self stopFetchingImage];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    self.fetchConnection = arc_autorelease([[NSURLConnection alloc] initWithRequest:request delegate:self]);
    self.fetchData = [NSMutableData data];
    [self.fetchConnection start];
    
    if (self.showsLoadingSpinner){
        [self showSpinner];
    }
}

-(void)stopFetchingImage{
    //[self.fetchConnection cancel]; //calling cancel is causing an intermittent crash inside of NSURLConnection. Instead, lets check to make sure we have the correct fetchConnection in our delegate callbacks, and if not ignore. (ie ghosting the no longer required connections, but not actually cancelling them)
    self.fetchConnection = nil;
    self.fetchData = nil;
    [self hideSpinner];
}

#pragma mark - properties
static void * const kRHPlaceholderImageKey = (void*)&kRHPlaceholderImageKey;
-(NSImage*)placeholderImage{
    return objc_getAssociatedObject(self, kRHPlaceholderImageKey);
}
-(void)setPlaceholderImage:(NSImage *)placeholderImage{
    objc_setAssociatedObject(self, kRHPlaceholderImageKey, placeholderImage, OBJC_ASSOCIATION_RETAIN);
}

static void * const kRHErrorImageKey = (void*)&kRHErrorImageKey;
-(NSImage*)errorImage{
    return objc_getAssociatedObject(self, kRHErrorImageKey);
}
-(void)setErrorImage:(NSImage*)errorImage{
    objc_setAssociatedObject(self, kRHErrorImageKey, errorImage, OBJC_ASSOCIATION_RETAIN);
}

static void * const kRHShowsLoadingSpinnerKey = (void*)&kRHShowsLoadingSpinnerKey;
-(BOOL)showsLoadingSpinner{
    NSNumber *number = objc_getAssociatedObject(self, kRHShowsLoadingSpinnerKey);
    return [number boolValue];
}
-(void)setShowsLoadingSpinner:(BOOL)showsLoadingSpinner{
    NSNumber *number = [NSNumber numberWithBool:showsLoadingSpinner];
    objc_setAssociatedObject(self, kRHShowsLoadingSpinnerKey, number, OBJC_ASSOCIATION_RETAIN);
}

@end


@implementation NSImageView (RHImageLoadingPrivateAdditions)

#pragma mark - NSURLConnectionDelegate
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response{
    if (connection != self.fetchConnection) return; //bail if not our current fetchConnection, ie it's been ghosted
    
    //clear our fetched data, because, as per the docs, this can occasionally be called multiple times, in which case it's recommend to clear and previously fetched data.
    [self.fetchData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    if (connection != self.fetchConnection) return; //bail if not our current fetchConnection, ie it's been ghosted
    [self.fetchData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    if (connection != self.fetchConnection) return; //bail if not our current fetchConnection, ie it's been ghosted
    
    if (self.errorImage) self.image = self.errorImage;
    
    [self hideSpinner];
    
    self.fetchConnection = nil;
    self.fetchData = nil;
    self.contentURL = nil;
    
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    if (connection != self.fetchConnection) return; //bail if not our current fetchConnection, ie it's been ghosted
    
    NSImage *image = arc_autorelease([[NSImage alloc] initWithData:self.fetchData]);
    
    if(image){ //if NSData is from an image
        self.image = image;
        [self hideSpinner];
        
        self.fetchConnection = nil;
        self.fetchData = nil;
        
    } else {
        [self connection:connection didFailWithError:nil];
    }
}

#pragma mark - properties
static void * const kRHFetchConnectionKey = (void*)&kRHFetchConnectionKey;
-(NSURLConnection*)fetchConnection{
    return objc_getAssociatedObject(self, kRHFetchConnectionKey);
}
-(void)setFetchConnection:(NSURLConnection*)fetchConnection{
    objc_setAssociatedObject(self, kRHFetchConnectionKey, fetchConnection, OBJC_ASSOCIATION_RETAIN);
}

static void * const kRHFetchDataKey = (void*)&kRHFetchDataKey;
-(NSMutableData*)fetchData{
    return objc_getAssociatedObject(self, kRHFetchDataKey);
}
-(void)setFetchData:(NSMutableData*)fetchData{
    objc_setAssociatedObject(self, kRHFetchDataKey, fetchData, OBJC_ASSOCIATION_RETAIN);
}

static void * const kRHSpinnerKey = (void*)&kRHSpinnerKey;
-(NSProgressIndicator*)spinner{
    return objc_getAssociatedObject(self, kRHSpinnerKey);
}
-(void)setSpinner:(NSProgressIndicator*)spinner{
    objc_setAssociatedObject(self, kRHSpinnerKey, spinner, OBJC_ASSOCIATION_RETAIN);
}

static void * const kRHContentURLKey = (void*)&kRHContentURLKey;
-(NSURL*)contentURL{
    return objc_getAssociatedObject(self, kRHContentURLKey);
}
-(void)setContentURL:(NSURL *)contentURL{
    objc_setAssociatedObject(self, kRHContentURLKey, contentURL, OBJC_ASSOCIATION_RETAIN);
}


#pragma mark - actions
-(void)showSpinner{
    if (!self.spinner){
        //bail if we are smaller than the smallest spinner size!
        if (self.bounds.size.width < 16 || self.bounds.size.height < 16) return;
        
        
        NSProgressIndicator *spinner = [[NSProgressIndicator alloc] init];
        [self addSubview:spinner];
        
        [spinner setStyle:NSProgressIndicatorSpinningStyle];
        [spinner startAnimation:self];
        
        [spinner setControlSize:NSRegularControlSize];
        CGFloat width = 32;
        CGFloat height = 32;
        
        if (self.bounds.size.height < 64 || self.bounds.size.width < 64){
            //use the small size
            [spinner setControlSize:NSSmallControlSize];
            width = 16.0f;
            height = 16.0f;
        }
        
        //center the spinner
        spinner.frame = NSMakeRect((self.bounds.size.width - width) / 2.0f, (self.bounds.size.height - height) / 2.0f, width, height);
        
        self.spinner = spinner;
        arc_release(spinner);
    }
}
-(void)hideSpinner{
    if (self.spinner){
        [self.spinner removeFromSuperview];
        self.spinner = nil;
    }
}

@end

//include an implementation in this file so we don't have to use -load_all for this category to be included in a static lib
@interface RHFixCategoryBugClassNSIVRHILA : NSObject @end @implementation RHFixCategoryBugClassNSIVRHILA @end



