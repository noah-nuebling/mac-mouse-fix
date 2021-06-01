//
//  RHProgressiveURLConnection.m
//
//  Created by Richard Heard on 27/10/2013.
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

#import "RHProgressiveURLConnection.h"
#import "RHARCSupport.h"
#import <TargetConditionals.h>

NSString * const RHProgressiveURLConnectionDidUpdateProgressNotification = @"RHProgressiveURLConnectionDidUpdateProgressNotification";
NSString * const RHProgressiveURLConnectionDidFinishNotification = @"RHProgressiveURLConnectionDidFinishNotification";

@interface RHProgressiveURLConnection () <NSURLConnectionDelegate>

@property (nonatomic, retain) NSURLConnection *connection;
@property (nonatomic, retain) id<NSURLConnectionDownloadDelegate, NSURLConnectionDataDelegate> delegate;

@property (nonatomic, retain) NSURLResponse *response;
@property (nonatomic, retain) NSMutableData *responseData;
@property (nonatomic, retain) NSError *responseError;

@property (nonatomic, assign) long long expectedContentLength;
@property (nonatomic, assign) double percentageProgress;

-(void)_progressUpdated;
-(void)_downloadFinished;
@end

@implementation RHProgressiveURLConnection

@synthesize connection=_connection;
@synthesize delegate=_delegate;
@synthesize response=_response;
@synthesize responseData=_responseData;
@synthesize responseError=_responseError;
@synthesize expectedContentLength=_expectedContentLength;
@synthesize percentageProgress=_percentageProgress;

#pragma mark - init
-(id)initWithRequest:(NSURLRequest *)request delegate:(id<NSURLConnectionDownloadDelegate, NSURLConnectionDataDelegate>)delegate startImmediately:(BOOL)startImmediately{
    self = [super init];
    if (self) {
        self.delegate = delegate;
        self.responseData = [NSMutableData data];
        self.connection = arc_autorelease([[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:startImmediately]);
        [self setDelegateQueue:[NSOperationQueue mainQueue]];
    }
    return self;
}

-(void)dealloc{
    arc_release_nil(_connection);
    arc_release_nil(_delegate);
    
    arc_release_nil(_response);
    arc_release_nil(_responseData);
    arc_release_nil(_responseError);
    
    arc_release_nil(_delegateQueue);
    arc_release_nil(_progressBlock);
    arc_release_nil(_completionBlock);
    
    arc_super_dealloc();
}


#pragma mark - init helpers
-(id)initWithRequest:(NSURLRequest *)request{
    return [self initWithRequest:request delegate:nil];
}

-(id)initWithRequest:(NSURLRequest *)request delegate:(id<NSURLConnectionDownloadDelegate, NSURLConnectionDataDelegate>)delegate{
    return [self initWithRequest:request delegate:delegate startImmediately:YES];
}

+(RHProgressiveURLConnection*)connectionWithRequest:(NSURLRequest *)request{
    return [[self alloc] initWithRequest:request];
}


#pragma mark - passthrough methods
-(void)start{
    [self.connection start];
}
-(void)cancel{
    [self.connection cancel];
}


#pragma mark - properties
-(void)setPercentageProgress:(double)percentageProgress{
    [self willChangeValueForKey:@"percentageProgress"];
    _percentageProgress = MIN(MAX(percentageProgress, 0.0), 1.0);
    [self didChangeValueForKey:@"percentageProgress"];
}


#pragma mark - progress blocks
-(void)setDelegateQueue:(NSOperationQueue*)delegateQueue{
    //nil == main queue
    if (!delegateQueue) delegateQueue = [NSOperationQueue mainQueue];
    if (_delegateQueue != delegateQueue){
        arc_release(_delegateQueue);
        _delegateQueue = arc_retain(delegateQueue);
    }
    //pass it through to the underlying connection
    [self.connection setDelegateQueue:_delegateQueue];
}

-(void)setProgressBlock:(RHProgressiveURLConnectionProgressBlock)progressBlock{
    if (_progressBlock != progressBlock){
        arc_release(_progressBlock);
        _progressBlock = [progressBlock copy];
    }
}

-(void)setCompletionBlock:(RHProgressiveURLConnectionCompletionBlock)completionBlock{
    if (_completionBlock != completionBlock){
        arc_release(_completionBlock);
        _completionBlock = [completionBlock copy];
    }
}


#pragma mark - NSURLConnection convenience
+(RHProgressiveURLConnection*)sendAsynchronousRequest:(NSURLRequest*)request queue:(NSOperationQueue*)queue completionHandler:(void (^)(NSURLResponse* response, NSData* data, NSError* connectionError))handler{
    RHProgressiveURLConnection *result = [[self alloc] initWithRequest:request delegate:nil startImmediately:NO];
    [result setDelegateQueue:queue];
    [result setCompletionBlock:handler];
    [result start];
    return arc_autorelease(result);
}


#pragma mark - NSURLConnectionDelegate
-(void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error{
    self.responseError = error;
    
    if ([self.delegate respondsToSelector:_cmd]){
        [self.delegate connection:connection didFailWithError:error];
    }
    
    [self _downloadFinished];
}

-(BOOL)connectionShouldUseCredentialStorage:(NSURLConnection *)connection{
    if ([self.delegate respondsToSelector:_cmd]){
        return [self.delegate connectionShouldUseCredentialStorage:connection];
    }
    return YES;
}

-(void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge{
    if ([self.delegate respondsToSelector:_cmd]){
        [self.delegate connection:connection willSendRequestForAuthenticationChallenge:challenge];
        return;
    }
    
    if ([challenge.sender respondsToSelector:@selector(performDefaultHandlingForAuthenticationChallenge:)]){
        [challenge.sender performDefaultHandlingForAuthenticationChallenge:challenge];
        return;
    }
    
    [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}

//ignore the deprecated delegate methods because we can't actually handle the old because we implement the new methods

#if TARGET_OS_IPHONE
//we only compile these methods into iOS targets because they are actually implemented on OS X 10.9 in response to 404s etc
// see rdar://15338545

#pragma mark - NSURLConnectionDownloadDelegate (iOS Only)
-(void)connection:(NSURLConnection *)connection didWriteData:(long long)bytesWritten totalBytesWritten:(long long)totalBytesWritten expectedTotalBytes:(long long) expectedTotalBytes{
    self.expectedContentLength = expectedTotalBytes;
    if (self.expectedContentLength > 0) self.percentageProgress = (double)totalBytesWritten / (double)self.expectedContentLength;
    
    if ([self.delegate respondsToSelector:_cmd]){
        [self.delegate connection:connection didWriteData:bytesWritten totalBytesWritten:totalBytesWritten expectedTotalBytes:expectedTotalBytes];
    }
    
    [self _progressUpdated];
}

-(void)connectionDidResumeDownloading:(NSURLConnection *)connection totalBytesWritten:(long long)totalBytesWritten expectedTotalBytes:(long long) expectedTotalBytes{
    self.expectedContentLength = expectedTotalBytes;
    if (self.expectedContentLength > 0) self.percentageProgress = (double)totalBytesWritten / (double)self.expectedContentLength;
    
    if ([self.delegate respondsToSelector:_cmd]){
        [self.delegate connectionDidResumeDownloading:connection totalBytesWritten:totalBytesWritten expectedTotalBytes:expectedTotalBytes];
    }
    
    [self _progressUpdated];
}

-(void)connectionDidFinishDownloading:(NSURLConnection *)connection destinationURL:(NSURL *) destinationURL{
    self.percentageProgress = 1.0;
    self.responseData = [NSMutableData dataWithContentsOfURL:destinationURL];
    self.responseError = nil;
    
    if ([self.delegate respondsToSelector:_cmd]){
        [self.delegate connectionDidFinishDownloading:connection destinationURL:destinationURL];
    }
    
    [self _progressUpdated];
    [self _downloadFinished];
    
}
#endif //end iPhone


#pragma mark - NSURLConnectionDataDelegate
-(NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response{
    if ([self.delegate respondsToSelector:_cmd]){
        return [self.delegate connection:connection willSendRequest:request redirectResponse:response];
    }
    
    //default
    return request;
}

-(void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response{
    self.response = response;
    [_responseData setLength:0];
    self.responseError = nil;
    
    self.percentageProgress = 0.0;
    self.expectedContentLength = response.expectedContentLength;
    
    if ([self.delegate respondsToSelector:_cmd]){
        [self.delegate connection:connection didReceiveResponse:response];
    }
    
    [self _progressUpdated];
}

-(void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data{
    [_responseData appendData:data];
    
    if (self.expectedContentLength > 0) self.percentageProgress = (double)_responseData.length / (double)self.expectedContentLength;
    
    if ([self.delegate respondsToSelector:_cmd]){
        [self.delegate connection:connection didReceiveData:data];
    }
    
    [self _progressUpdated];
}

/*
 //We opt out of NSInputStream spooling because in most cases the OS X default behaviour is what we want
 //and we dont want to have to implement spool to disk behaviour ourselves.
 -(NSInputStream *)connection:(NSURLConnection *)connection needNewBodyStream:(NSURLRequest *)request{
 if ([self.delegate respondsToSelector:_cmd]){
 return [self.delegate connection:connection needNewBodyStream:request];
 }
 return nil; //this will throw an error.
 }
 */

-(void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite{
    self.expectedContentLength = totalBytesExpectedToWrite;
    if (self.expectedContentLength > 0) self.percentageProgress = (double)totalBytesWritten / (double)self.expectedContentLength;
    
    if ([self.delegate respondsToSelector:_cmd]){
        [self.delegate connection:connection didSendBodyData:bytesWritten totalBytesWritten:totalBytesWritten totalBytesExpectedToWrite:totalBytesExpectedToWrite];
    }
    
    [self _progressUpdated];
}


-(NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse{
    if ([self.delegate respondsToSelector:_cmd]){
        return [self.delegate connection:connection willCacheResponse:cachedResponse];
    }
    return cachedResponse;
}

-(void)connectionDidFinishLoading:(NSURLConnection *)connection{
    self.responseError = nil;
    self.percentageProgress = 1.0;
    
    
    if ([self.delegate respondsToSelector:_cmd]){
        [self.delegate connectionDidFinishLoading:connection];
    }
    
    [self _progressUpdated];
    [self _downloadFinished];
}


#pragma mark - internal
-(void)_progressUpdated{
    [_delegateQueue addOperation:[NSBlockOperation blockOperationWithBlock:^{
        if (_progressBlock) _progressBlock(self, self.percentageProgress);
        [[NSNotificationCenter defaultCenter] postNotificationName:RHProgressiveURLConnectionDidUpdateProgressNotification object:self];
    }]];
}

-(void)_downloadFinished{
    [_delegateQueue addOperation:[NSBlockOperation blockOperationWithBlock:^{
        if (_completionBlock) _completionBlock(_response, self.responseError ? nil : self.responseData, self.responseError);
        [[NSNotificationCenter defaultCenter] postNotificationName:RHProgressiveURLConnectionDidFinishNotification object:self];
        
        //now that we have finished downloading, nil our delegate to prevent any possible retain cycles.
        self.delegate = nil;
        arc_release_nil(_completionBlock);
        arc_release_nil(_progressBlock);
    }]];
}

@end

