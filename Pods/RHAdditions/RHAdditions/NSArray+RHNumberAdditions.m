//
//  NSArray+RHNumberAdditions.m
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

#import "NSArray+RHNumberAdditions.h"

@implementation NSArray (RHNumberAdditions)

//primitive additions
-(BOOL)boolAtIndex:(NSUInteger)index                           { return [[self objectAtIndex:index] boolValue];             }
-(int)intAtIndex:(NSUInteger)index                             { return [[self objectAtIndex:index] intValue];              }
-(long)longAtIndex:(NSUInteger)index                           { return [[self objectAtIndex:index] longValue];             }
-(unsigned long)unsignedLongAtIndex:(NSUInteger)index          { return [[self objectAtIndex:index] longValue];             }
-(long long)longLongAtIndex:(NSUInteger)index                  { return [[self objectAtIndex:index] longLongValue];         }
-(unsigned long long)unsignedLongLongAtIndex:(NSUInteger)index { return [[self objectAtIndex:index] unsignedLongLongValue]; }
-(double)doubleAtIndex:(NSUInteger)index                       { return [[self objectAtIndex:index] doubleValue];           }
-(float)floatAtIndex:(NSUInteger)index                         { return [[self objectAtIndex:index] floatValue];            }
-(NSInteger)integerAtIndex:(NSUInteger)index                   { return [[self objectAtIndex:index] integerValue];          }
-(NSUInteger)usignedIntegerAtIndex:(NSUInteger)index           { return [[self objectAtIndex:index] unsignedIntegerValue];  }

@end

@implementation NSMutableArray (RHNumberAdditions)

//primitive additions
-(void)addBool:(BOOL)value                           { [self addObject:[NSNumber numberWithBool:value]];             }
-(void)addInt:(int)value                             { [self addObject:[NSNumber numberWithInt:value]];              }
-(void)addLong:(long)value                           { [self addObject:[NSNumber numberWithLong:value]];             }
-(void)addUnsignedLong:(unsigned long)value          { [self addObject:[NSNumber numberWithUnsignedLong:value]];     }
-(void)addLongLong:(long long)value                  { [self addObject:[NSNumber numberWithLongLong:value]];         }
-(void)addUnsignedLongLong:(unsigned long long)value { [self addObject:[NSNumber numberWithUnsignedLongLong:value]]; }
-(void)addDouble:(double)value                       { [self addObject:[NSNumber numberWithDouble:value]];           }
-(void)addFloat:(float)value                         { [self addObject:[NSNumber numberWithFloat:value]];            }
-(void)addInteger:(NSInteger)value                   { [self addObject:[NSNumber numberWithInteger:value]];          }
-(void)addUnsignedInteger:(NSUInteger)value          { [self addObject:[NSNumber numberWithUnsignedInteger:value]];  }

//primitive insertions
-(void)insertBool:(BOOL)value atIndex:(NSUInteger)index                           { [self insertObject:[NSNumber numberWithBool:value] atIndex:index];             }
-(void)insertInt:(int)value atIndex:(NSUInteger)index                             { [self insertObject:[NSNumber numberWithInt:value] atIndex:index];              }
-(void)insertLong:(long)value atIndex:(NSUInteger)index                           { [self insertObject:[NSNumber numberWithLong:value] atIndex:index];             }
-(void)insertUnsignedLong:(unsigned long)value atIndex:(NSUInteger)index          { [self insertObject:[NSNumber numberWithUnsignedLong:value] atIndex:index];     }
-(void)insertLongLong:(long long)value atIndex:(NSUInteger)index                  { [self insertObject:[NSNumber numberWithLongLong:value] atIndex:index];         }
-(void)insertUnsignedLongLong:(unsigned long long)value atIndex:(NSUInteger)index { [self insertObject:[NSNumber numberWithUnsignedLongLong:value] atIndex:index]; }
-(void)insertDouble:(double)value atIndex:(NSUInteger)index                       { [self insertObject:[NSNumber numberWithDouble:value] atIndex:index];           }
-(void)insertFloat:(float)value atIndex:(NSUInteger)index                         { [self insertObject:[NSNumber numberWithFloat:value] atIndex:index];            }
-(void)insertInteger:(NSInteger)value atIndex:(NSUInteger)index                   { [self insertObject:[NSNumber numberWithInteger:value] atIndex:index];          }
-(void)insertUnsignedInteger:(NSUInteger)value atIndex:(NSUInteger)index          { [self insertObject:[NSNumber numberWithUnsignedInteger:value] atIndex:index];  }

@end

//include an implementation in this file so we don't have to use -load_all for this category to be included in a static lib
@interface RHFixCategoryBugClassNSARHNA : NSObject @end @implementation RHFixCategoryBugClassNSARHNA @end


