//
//  RHGoogleURLShortener.m
//
//  Created by Richard Heard on 25/05/13.
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
// https://developers.google.com/url-shortener/v1/getting_started


#define kGoogleURLShortenerURLEndpoint @"https://www.googleapis.com/urlshortener/v1/url/?key=%@"
#define kRequestTimeout 5.0

#import "RHGoogleURLShortener.h"
#import "RHARCSupport.h"
#import "NSJSONSerialization+RHTypeAdditions.h"

static NSString * _apiKey = NULL;

@interface RHGoogleURLShortener () <NSURLConnectionDataDelegate>
-(void)_cleanup;
+(NSURL*)_shortURLFromData:(NSData*)data error:(NSError**)errorOut;
+(NSURLRequest*)_requestWithLongURL:(NSURL*)longURL;
@end

@implementation RHGoogleURLShortener

+(void)setGoogleURLShortenerAPIKey:(NSString*)key{
    arc_release(_apiKey);
    _apiKey = [key copy];
}


+(id)shortenURL:(NSURL*)url withCompletion:(RHGoogleURLShortenerCompletionBlock)completion{
    return arc_autorelease([[[self class] alloc] initWithLongURL:url withCompletion:completion]);
}

-(id)initWithLongURL:(NSURL*)url withCompletion:(RHGoogleURLShortenerCompletionBlock)completion{
    if (!url){
        [NSException raise:NSInvalidArgumentException format:@"Error: longURL must not be nil."];
        return nil;
    }

    self = [super init];
    if (self) {
        if (!_apiKey){
            [NSException raise:NSInternalInconsistencyException format:@"Error: setGoogleURLShortenerAPIKey: must be called with your google service API key in-order to use the RHGoogleURLShortener Class."];
        }

        _originalURL = arc_retain(url);
        _completionBlock = [completion copy];
        
        _mutableData = [[NSMutableData alloc] init];
        
        //retain ourselves until the networking finishes
        _retainedSelf = arc_retain(self);
        //setup the connection to the endpoint
        NSURLRequest *request = [self.class _requestWithLongURL:_originalURL];
        _connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    }
    return self;
}

-(void)dealloc{
    arc_release_nil(_originalURL);
    arc_release_nil(_completionBlock);
    arc_release_nil(_mutableData);
    arc_release_nil(_connection);
    arc_super_dealloc();
}

#pragma mark - public
-(void)cancel{
    [_connection cancel];
    [self _cleanup];
}

#pragma mark - internal
-(void)_cleanup{
    //we retain ourselves in init. so cleanup == release
    arc_release_nil(_retainedSelf);
}

+(NSURL*)_shortURLFromData:(NSData*)data error:(NSError**)errorOut{
    if (!data) return nil;
    
    NSDictionary *dictionary = [NSJSONSerialization dictionaryWithData:data error:errorOut];
    id result = [dictionary objectForKey:@"id"]; //{ "kind": "urlshortener#url", "id": "http://goo.gl/fbsS", "longUrl": "http://www.google.com/" }
    if (!result) return nil;
    return [NSURL URLWithString:[NSString stringWithFormat:@"%@", result]];
}

+(NSURLRequest*)_requestWithLongURL:(NSURL*)longURL{
    NSURL *apiURL = [NSURL URLWithString:[NSString stringWithFormat:kGoogleURLShortenerURLEndpoint, _apiKey]];
    NSMutableURLRequest *result = [[NSMutableURLRequest alloc] initWithURL:apiURL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:kRequestTimeout];
    [result setHTTPMethod:@"POST"];
    NSData *body = [[NSDictionary dictionaryWithObject:[longURL description] forKey:@"longUrl"] JSONData];
    [result setHTTPBody:body];
    [result setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    return arc_autorelease(result);
}

#pragma mark - NSURLConnectionDelegate
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error{
    if (_completionBlock) _completionBlock(nil, error);
    [self _cleanup];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response{
    [_mutableData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data{
    [_mutableData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection{
    NSError *errorOut = nil;
    NSURL *finalURL = [self.class _shortURLFromData:_mutableData error:&errorOut];
    if (_completionBlock && finalURL){
        _completionBlock(finalURL, nil);
    } else if (_completionBlock) {
        _completionBlock(nil, errorOut);
    }
    [self _cleanup];
}


@end
