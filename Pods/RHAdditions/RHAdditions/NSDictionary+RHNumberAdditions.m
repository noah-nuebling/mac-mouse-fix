//
//  NSDictionary+RHNumberAdditions.m
//
//  Created by Richard Heard on 15/07/13.
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

#import "NSDictionary+RHNumberAdditions.h"

@implementation NSDictionary (RHNumberAdditions)

//primitive getters
-(BOOL)boolForKey:(id)aKey                           { return [[self objectForKey:aKey] boolValue];             }
-(int)intForKey:(id)aKey                             { return [[self objectForKey:aKey] intValue];              }
-(long)longForKey:(id)aKey                           { return [[self objectForKey:aKey] longValue];             }
-(unsigned long)unsignedLongForKey:(id)aKey          { return [[self objectForKey:aKey] unsignedLongValue];     }
-(long long)longLongForKey:(id)aKey                  { return [[self objectForKey:aKey] longLongValue];         }
-(unsigned long long)unsignedLongLongForKey:(id)aKey { return [[self objectForKey:aKey] unsignedLongLongValue]; }
-(double)doubleForKey:(id)aKey                       { return [[self objectForKey:aKey] doubleValue];           }
-(float)floatForKey:(id)aKey                         { return [[self objectForKey:aKey] floatValue];            }
-(NSInteger)integerForKey:(id)aKey                   { return [[self objectForKey:aKey] integerValue];          }
-(NSUInteger)usignedIntegerForKey:(id)aKey           { return [[self objectForKey:aKey] unsignedIntegerValue];  }

@end

@implementation NSMutableDictionary (RHNumberAdditions)

//primitive insertions
-(void)setBool:(BOOL)value forKey:(id <NSCopying>)aKey                           { [self setObject:[NSNumber numberWithBool:value] forKey:aKey];             }
-(void)setInt:(int)value forKey:(id <NSCopying>)aKey                             { [self setObject:[NSNumber numberWithInt:value] forKey:aKey];              }
-(void)setLong:(long int)value forKey:(id <NSCopying>)aKey                       { [self setObject:[NSNumber numberWithLong:value] forKey:aKey];             }
-(void)setUnsignedLong:(unsigned long)value forKey:(id <NSCopying>)aKey          { [self setObject:[NSNumber numberWithUnsignedLong:value] forKey:aKey];     }
-(void)setLongLong:(long long)value forKey:(id <NSCopying>)aKey                  { [self setObject:[NSNumber numberWithLongLong:value] forKey:aKey];     }
-(void)setUnsignedLongLong:(unsigned long long)value forKey:(id <NSCopying>)aKey { [self setObject:[NSNumber numberWithUnsignedLongLong:value] forKey:aKey]; }
-(void)setDouble:(double)value forKey:(id <NSCopying>)aKey                       { [self setObject:[NSNumber numberWithDouble:value] forKey:aKey];           }
-(void)setFloat:(float)value forKey:(id <NSCopying>)aKey                         { [self setObject:[NSNumber numberWithFloat:value] forKey:aKey];            }
-(void)setInteger:(NSInteger)value forKey:(id <NSCopying>)aKey                   { [self setObject:[NSNumber numberWithInteger:value] forKey:aKey];          }
-(void)setUnsignedInteger:(NSUInteger)value forKey:(id <NSCopying>)aKey          { [self setObject:[NSNumber numberWithUnsignedInteger:value] forKey:aKey];  }

@end

//include an implementation in this file so we don't have to use -load_all for this category to be included in a static lib
@interface RHFixCategoryBugClassNSDRHNA : NSObject @end @implementation RHFixCategoryBugClassNSDRHNA @end

