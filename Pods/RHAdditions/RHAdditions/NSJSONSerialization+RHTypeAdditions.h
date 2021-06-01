//
//  NSJSONSerialization+RHTypeAdditions.h
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
// Add some type safety to NSJSONSerialization return types

#import <Foundation/Foundation.h>

@interface NSJSONSerialization (RHTypeAdditions)

+(NSArray*)arrayWithData:(NSData *)data;
+(NSArray*)arrayWithData:(NSData *)data error:(NSError **)error;
+(NSMutableArray*)mutableArrayWithData:(NSData *)data error:(NSError **)error;

+(NSDictionary*)dictionaryWithData:(NSData *)data;
+(NSDictionary*)dictionaryWithData:(NSData *)data error:(NSError **)error;
+(NSMutableDictionary*)mutableDictionaryWithData:(NSData *)data error:(NSError **)error;

@end

@interface NSDictionary (RHJSONDataAdditions)

-(NSData*)JSONData;
-(NSData*)JSONDataWithError:(NSError **)error;

+(id)dictionaryWithJSONData:(NSData*)data;
-(id)initWithJSONData:(NSData*)data error:(NSError **)error;

@end

@interface NSArray (RHJSONDataAdditions)

-(NSData*)JSONData;
-(NSData*)JSONDataWithError:(NSError **)error;

+(id)arrayWithJSONData:(NSData*)data;
-(id)initWithJSONData:(NSData*)data error:(NSError **)error;

@end

