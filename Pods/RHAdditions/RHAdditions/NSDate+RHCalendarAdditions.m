//
//  NSDate+RHCalendarAdditions.m
//
//  Created by Richard Heard on 4/07/12.
//  Copyright (c) 2012 Richard Heard. All rights reserved.
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

#import "NSDate+RHCalendarAdditions.h"
#import "RHARCSupport.h"

@implementation NSCalendar (RHCalendarAdditions)

+(NSCalendar*)gregorianCalendar{
    static NSCalendar *_gregorianCalendar = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _gregorianCalendar =  [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    });
    
    return _gregorianCalendar;
}

@end


@implementation NSDate (RHCalendarAdditions)

//components
-(NSDateComponents*)componentsForGregorianCalendar{
    
    NSUInteger components = NSEraCalendarUnit
    | NSYearCalendarUnit
    | NSMonthCalendarUnit
    | NSDayCalendarUnit
    | NSHourCalendarUnit
    | NSMinuteCalendarUnit
    | NSSecondCalendarUnit
    | NSWeekdayCalendarUnit
    | NSWeekdayOrdinalCalendarUnit
    | NSQuarterCalendarUnit
    | NSWeekOfMonthCalendarUnit
    | NSWeekOfYearCalendarUnit
    | NSYearForWeekOfYearCalendarUnit
    | NSCalendarCalendarUnit
    | NSTimeZoneCalendarUnit;
    
    return [[NSCalendar gregorianCalendar] components:components fromDate:self];
}

//seconds
-(NSDate*)dateByAddingSeconds:(NSInteger)seconds{
    NSDateComponents *components = arc_autorelease([[NSDateComponents alloc] init]);
    [components setSecond:seconds];
    
    return [[NSCalendar gregorianCalendar] dateByAddingComponents:components toDate:self options:0];
}

-(NSInteger)secondsBetweenDates:(NSDate*)otherDate{
    NSDateComponents *components = [[NSCalendar gregorianCalendar] components:NSSecondCalendarUnit fromDate:self toDate:otherDate options:0];
    return ABS(components.second);
}

//days
-(NSDate*)dateByAddingDays:(NSInteger)days{
    NSDateComponents *components = arc_autorelease([[NSDateComponents alloc] init]);
    [components setDay:days];
    
    return [[NSCalendar gregorianCalendar] dateByAddingComponents:components toDate:self options:0];
}

-(NSInteger)daysBetweenDates:(NSDate*)otherDate{
    NSDateComponents *components = [[NSCalendar gregorianCalendar] components:NSDayCalendarUnit fromDate:self toDate:otherDate options:0];
    return ABS(components.day);
}

-(NSDate*)previousDay{
    return [self dateByAddingDays:-1];
}
-(NSDate*)nextDay{
    return [self dateByAddingDays:1];
}

//months
-(NSDate*)dateByAddingMonths:(NSInteger)months{
    NSDateComponents *components = arc_autorelease([[NSDateComponents alloc] init]);
    [components setMonth:months];
    
    return [[NSCalendar gregorianCalendar] dateByAddingComponents:components toDate:self options:0];
}

-(NSDate*)previousMonth{
    return [self dateByAddingMonths:-1];
}

-(NSDate*)nextMonth{
    return [self dateByAddingMonths:1];
}


//normalization
-(NSDate*)normalizedDate{
    NSDateComponents* components = [[NSCalendar gregorianCalendar] components:(NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit) fromDate:self];
    return [[NSCalendar gregorianCalendar] dateFromComponents:components];
}

@end


//include an implementation in this file so we don't have to use -load_all for this category to be included in a static lib
@interface RHFixCategoryBugClassNSDRHCA : NSObject @end @implementation RHFixCategoryBugClassNSDRHCA @end

