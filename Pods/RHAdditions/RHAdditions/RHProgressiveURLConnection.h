//
//  RHProgressiveURLConnection.h
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

#import <Foundation/Foundation.h>

//notifications (object == self)
extern NSString * const RHProgressiveURLConnectionDidUpdateProgressNotification;
extern NSString * const RHProgressiveURLConnectionDidFinishNotification;

@class RHProgressiveURLConnection;

typedef void (^RHProgressiveURLConnectionProgressBlock)(RHProgressiveURLConnection *connection, double percentageProgress);
typedef void (^RHProgressiveURLConnectionCompletionBlock)(NSURLResponse *response, NSData *data, NSError *connectionError);

@interface RHProgressiveURLConnection : NSObject {
@private
    NSURLConnection *_connection;
    id<NSURLConnectionDownloadDelegate, NSURLConnectionDataDelegate> _delegate; //strong, however nil'd once download is finished
    
    NSURLResponse *_response;
    NSMutableData *_responseData; //we should provide an easy way to keep this out of memory for large files
    NSError *_responseError;
    
    long long _expectedContentLength;
    double _percentageProgress;
    
    NSOperationQueue *_delegateQueue;
    
    RHProgressiveURLConnectionProgressBlock _progressBlock;
    RHProgressiveURLConnectionCompletionBlock _completionBlock;
}

@property (nonatomic, readonly) NSURLConnection *connection;
@property (nonatomic, readonly) id<NSURLConnectionDownloadDelegate, NSURLConnectionDataDelegate> delegate;

@property (nonatomic, readonly) NSURLResponse *response;
@property (nonatomic, readonly) NSData *responseData;
@property (nonatomic, readonly) NSError *responseError;

@property (nonatomic, readonly) long long expectedContentLength;
@property (nonatomic, readonly) double percentageProgress; //KVO observable

//designated initializer
-(id)initWithRequest:(NSURLRequest *)request delegate:(id)delegate startImmediately:(BOOL)startImmediately; //(delegate has all methods passed through to it from the internal NSURLConnection, if implemented)

//init helpers
-(id)initWithRequest:(NSURLRequest *)request;
-(id)initWithRequest:(NSURLRequest *)request delegate:(id)delegate;
+(RHProgressiveURLConnection*)connectionWithRequest:(NSURLRequest *)request;

//passthrough methods to the internal NSURLConnection
-(void)start;
-(void)cancel;

//progress blocks
-(void)setDelegateQueue:(NSOperationQueue*)blockQueue; //defaults to the main queue (nil == main queue)
-(void)setProgressBlock:(RHProgressiveURLConnectionProgressBlock)progressBlock; //called when our progress changes, useful for updating UI etc.
-(void)setCompletionBlock:(RHProgressiveURLConnectionCompletionBlock)completionBlock; //called on completion, useful for updating UI etc.

//same as the NSURLConnection counterpart, except that the method returns the created progressiveURLConnection instance, which can be monitored for progress / status changes
+(RHProgressiveURLConnection*)sendAsynchronousRequest:(NSURLRequest*)request queue:(NSOperationQueue*)queue completionHandler:(RHProgressiveURLConnectionCompletionBlock)handler;

@end

