//
//  NSJSONSerialization+RHTypeAdditions.m
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

#import "NSJSONSerialization+RHTypeAdditions.h"
#import "RHARCSupport.h"

@implementation NSJSONSerialization (RHTypeAdditions)

+(NSArray*)arrayWithData:(NSData *)data{
    return [self arrayWithData:data error:nil];
}

+(NSArray*)arrayWithData:(NSData *)data error:(NSError **)error{
    id result = [self JSONObjectWithData:data options:0 error:error];
    if (![result isKindOfClass:[NSArray class]]) return nil;
    return result;
}

+(NSMutableArray*)mutableArrayWithData:(NSData *)data error:(NSError **)error{
    id result = [self JSONObjectWithData:data options:NSJSONReadingMutableContainers error:error];
    if (![result isKindOfClass:[NSMutableArray class]]) return nil;
    return result;
}

+(NSDictionary*)dictionaryWithData:(NSData *)data{
    return [self dictionaryWithData:data error:nil];
}
+(NSDictionary*)dictionaryWithData:(NSData *)data error:(NSError **)error{
    id result = [self JSONObjectWithData:data options:0 error:error];
    if (![result isKindOfClass:[NSDictionary class]]) return nil;
    return result;
}

+(NSMutableDictionary*)mutableDictionaryWithData:(NSData *)data error:(NSError **)error{
    id result = [self JSONObjectWithData:data options:NSJSONReadingMutableContainers error:error];
    if (![result isKindOfClass:[NSMutableDictionary class]]) return nil;
    return result;
}

@end

@implementation NSDictionary (RHJSONDataAdditions)

-(NSData*)JSONData{
    return [self JSONDataWithError:nil];
}

-(NSData*)JSONDataWithError:(NSError **)error{
    return [NSJSONSerialization dataWithJSONObject:self options:0 error:error];
}

+(id)dictionaryWithJSONData:(NSData*)data{
    return arc_autorelease([[self alloc] initWithJSONData:data error:nil]);
}

-(id)initWithJSONData:(NSData*)data error:(NSError **)error{
    NSDictionary *dictionary = [NSJSONSerialization dictionaryWithData:data error:error];
    if (!dictionary) return nil;
    return [self initWithDictionary:dictionary];
}

@end


@implementation NSArray (RHJSONDataAdditions)

-(NSData*)JSONData{
    return [self JSONDataWithError:nil];
}

-(NSData*)JSONDataWithError:(NSError **)error{
    return [NSJSONSerialization dataWithJSONObject:self options:0 error:error];
}

+(id)arrayWithJSONData:(NSData*)data{
    return arc_autorelease([[self alloc] initWithJSONData:data error:nil]);
}

-(id)initWithJSONData:(NSData*)data error:(NSError **)error{
    NSArray *array = [NSJSONSerialization arrayWithData:data error:error];
    if (!array) return nil;
    return [self initWithArray:array];
}

@end


//include an implementation in this file so we don't have to use -load_all for this category to be included in a static lib
@interface RHFixCategoryBugClassNSJSONSRHTA : NSObject @end @implementation RHFixCategoryBugClassNSJSONSRHTA @end

