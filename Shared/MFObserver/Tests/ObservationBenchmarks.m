//
//  ObservationBenchmarks.m
//  objc-test-july-13-2024
//
//  Created by Noah Nübling on 31.07.24.
//

#import "ObservationBenchmarks.h"
#import "MFDataClass.h"
#import "MFObserver.h"
#import "CoolMacros.h"
#import "objc_tests-Swift.h"
#import "KVOMutationSupport.h"
#import "QuartzCore/QuartzCore.h"
#import "AppKit/AppKit.h"
#import "EXTScope.h"

#define stringf(format, args...) [NSString stringWithFormat:format, args]

MFDataClass(TestObject, (MFDataPropPrimitive(NSInteger value)))

MFDataClass(TestObject4, (MFDataPropPrimitive(NSInteger value1)
                          MFDataPropPrimitive(NSInteger value2)
                          MFDataPropPrimitive(NSInteger value3)
                          MFDataPropPrimitive(NSInteger value4)))

MFDataClass(TestStrings, (MFDataProp(NSMutableString *string1)
                          MFDataProp(NSMutableString *string2)));

static MFObserver *_memoryTestVariable = nil;

@implementation ObservationBenchmarks

void runMFObserverBenchmarks(void) {
        
    @autoreleasepool {
        
        int iterations = 1000000;
        
        CFTimeInterval combineTime = NAN;
        CFTimeInterval kvoTime = NAN;
        CFTimeInterval swiftKVOTime = NAN;
        CFTimeInterval pureObjcTime = NAN;
        CFTimeInterval pureSwiftTime = NAN;
        
        NSLog(@"Running simple tests with %d iterations", iterations);
        
        combineTime = [ObservationBenchmarksSwift runCombineTestWithIterations:iterations];
        kvoTime = runKVOTest(iterations);
        swiftKVOTime = [ObservationBenchmarksSwift runSwiftKVOTestWithIterations:iterations];
        pureObjcTime = runPureObjcTest(iterations);
        pureSwiftTime = [ObservationBenchmarksSwift runPureSwiftTestWithIterations:iterations];
        
        NSLog(@"Combine time: %f", combineTime);
        NSLog(@"kvo time: %f", kvoTime);
        NSLog(@"swiftKVO time: %f", swiftKVOTime);
        NSLog(@"pure objc time: %f", pureObjcTime);
        NSLog(@"pure swift time: %f", pureSwiftTime);
        NSLog(@"pureSwift is %.2fx faster than pureObjc. pureObjc is %.2fx faster than kvo. kvo is %.2fx faster than Combine. Combine is %.2fx faster than SwiftKVO", 1/(pureSwiftTime/pureObjcTime) , 1/(pureObjcTime/kvoTime), 1/(kvoTime/combineTime), 1/(combineTime/swiftKVOTime));
        
        iterations = iterations / 4;
        
        NSLog(@"Running combineLatest tests with %d iterations", iterations);
        
        combineTime = [ObservationBenchmarksSwift runCombineTest_ObserveLatestWithIterations:iterations];
        kvoTime = runKVOTest_ObserveLatest(iterations);
        pureObjcTime = runPureObjcTest_ObserveLatest(iterations);
        pureSwiftTime = [ObservationBenchmarksSwift runPureSwiftTest_ObserveLatestWithIterations:iterations];
        
        NSLog(@"Combine time: %f", combineTime);
        NSLog(@"kvo time: %f", kvoTime);
        NSLog(@"pureObjc time: %f", pureObjcTime);
        NSLog(@"pureSwift time: %f", pureSwiftTime);
        NSLog(@"pureSwift is %.2fx faster than pureObjc. pureObjc is %.2fx faster than kvo. kvo is %.2fx faster than Combine", pureObjcTime / pureSwiftTime , kvoTime / pureObjcTime, combineTime / kvoTime);
        
        iterations = iterations/2;
        
        NSLog(@"Running string manipulation tests with %d iterations", iterations);
//        
        combineTime = [ObservationBenchmarksSwift runCombineTest_StringsWithIterations:iterations];
        kvoTime = runKVOTest_Strings(iterations);
        pureObjcTime = runPureObjcTest_Strings(iterations);
        
        NSLog(@"Combine time: %f", combineTime);
        NSLog(@"kvo time: %f", kvoTime);
        NSLog(@"pureObjc time: %f", pureObjcTime);
        NSLog(@"kvo is %.2fx faster than Combine", combineTime / kvoTime);
        
    } /// End of autoreleasePool
    
    /// Idle after  autoreleasePool to look at memery graph
    ///     See if there are memory leaks
    if ((NO)) {
        NSLog(@"Idling an a runLoop...");
        
        [_memoryTestVariable cancel];
        CFRunLoopRunInMode(0, 2.0, false);
        @autoreleasepool {
            _memoryTestVariable = nil;
        }
        CFRunLoopRun();
    } else {
        exit(0);
    }


}

NSTimeInterval runPureObjcTest(NSInteger iterations) {
    
    /// Don't use observation
    
    /// Ts
    CFTimeInterval startTime = CACurrentMediaTime();
    
    /// Mutable data
    
    NSInteger value = 0;
    NSMutableArray *valuesFromCallback = [NSMutableArray array];
    __block NSInteger sumFromCallback = 0;

    
    /// Setup callback
    __auto_type callback = ^void (NSInteger newValue) {
        [valuesFromCallback addObject:@(newValue)];
        sumFromCallback += newValue;
        if (newValue % 2 == 0) {
            sumFromCallback <<= 2;
        }
    };
    
    /// Change value
    for (NSInteger i = 0; i < iterations; i++) {
        value = i;
        callback(value);
    }
    
    /// Ts
    CFTimeInterval endTime = CACurrentMediaTime();
    
    /// Log
    NSLog(@"pureObjc - count: %ld, sum: %ld", valuesFromCallback.count, (long)sumFromCallback);
    
    /// Return
    CFTimeInterval testDuration = endTime - startTime;
    return testDuration;
}

NSTimeInterval runKVOTest(NSInteger iterations) {
    
    /// Ts
    CFTimeInterval startTime = CACurrentMediaTime();
    
    /// Mutable data
    NSMutableArray *valuesFromCallback = [NSMutableArray array];
    __block NSInteger sumFromCallback = 0;
    
    /// Setup callback
    TestObject *testObject = [[TestObject alloc] init];
    [testObject mf_observe:@"value" block:^(NSObject * _Nonnull newValueBoxed) {
        NSInteger newValue = unboxNSValue(NSInteger, newValueBoxed);
        [valuesFromCallback addObject:newValueBoxed];
        sumFromCallback += newValue;
        if (newValue % 2 == 0) {
            sumFromCallback <<= 2;
        }
    }];
    
    /// Change value
    for (NSInteger i = 0; i < iterations; i++) {
        testObject.value = i;
    }
    
    /// Ts
    CFTimeInterval endTime = CACurrentMediaTime();
    
    /// Log
    NSLog(@"KVO - count: %ld, sum: %ld", valuesFromCallback.count, (long)sumFromCallback);
    
    /// Return
    CFTimeInterval testDuration = endTime - startTime;
    return testDuration;
}


NSTimeInterval runPureObjcTest_ObserveLatest(NSInteger iterations) {
    
    CFTimeInterval startTime = CACurrentMediaTime();
    
    __block NSInteger sumFromCallback = 0;
    
    NSInteger v1 = 0;
    NSInteger v2 = 0;
    NSInteger v3 = 0;
    NSInteger v4 = 0;
    
    __auto_type callback = ^void (NSInteger value1, NSInteger value2, NSInteger value3, NSInteger value4) {
        
        sumFromCallback += value1 + value2 + value3 + value4;
        if ((value1 + value2 + value3 + value4) % 2 == 0) {
            sumFromCallback <<= 8;
        }
    };
    
    for (NSInteger i = 1; i < iterations; i++) {
        v1 = i;
        callback(v1, v2, v3, v4);
        v2 = i * 2;
        callback(v1, v2, v3, v4);
        v3 = i * 3;
        callback(v1, v2, v3, v4);
        v4 = i * 4;
        callback(v1, v2, v3, v4);
    }
    
    CFTimeInterval endTime = CACurrentMediaTime();
    
    NSLog(@"pureObjc - ObserveLatest - sum: %ld", (long)sumFromCallback);
    
    return endTime - startTime;
}

NSTimeInterval runKVOTest_ObserveLatest(NSInteger iterations) {
    
    CFTimeInterval startTime = CACurrentMediaTime();
    
    __block NSInteger sumFromCallback = 0;
    
    TestObject4 *testObject = [[TestObject4 alloc] init];
    
    [MFObserver observeLatest4:@[@[testObject, @"value1"],
                                 @[testObject, @"value2"],
                                 @[testObject, @"value3"],
                                 @[testObject, @"value4"]]
                         block:^void (int updatedIndex, id v0, id v1, id v2, id v3) {
        
        NSInteger value1 = unboxNSValue(NSInteger, v0);
        NSInteger value2 = unboxNSValue(NSInteger, v1);
        NSInteger value3 = unboxNSValue(NSInteger, v2);
        NSInteger value4 = unboxNSValue(NSInteger, v3);
        
        sumFromCallback += value1 + value2 + value3 + value4;
        if ((value1 + value2 + value3 + value4) % 2 == 0) {
            sumFromCallback <<= 8;
        }
    }];
    
    for (NSInteger i = 1; i < iterations; i++) {
        testObject.value1 = i;
        testObject.value2 = i * 2;
        testObject.value3 = i * 3;
        testObject.value4 = i * 4;
    }
    
    CFTimeInterval endTime = CACurrentMediaTime();
    
    NSLog(@"KVO - ObserveLatest - sum: %ld", (long)sumFromCallback);
    
    return endTime - startTime;
}

NSTimeInterval runKVOTest_Strings(NSInteger iterations) {
    
    CFTimeInterval startTime = CACurrentMediaTime();
    __block NSInteger checkSum = 0;
    
    TestStrings *testObject = [[TestStrings alloc] init];
    testObject.string1 = [NSMutableString stringWithString:@"Hello"];
    testObject.string2 = [NSMutableString stringWithString:@"World"];
    
    [testObject.string1 notifyOnMutation:YES];
    [testObject.string2 notifyOnMutation:YES];
    
    [testObject.string2 mf_observe:@"self" block:^(NSString * updatedString2) {
        
        static BOOL isFirst = YES;
        if (isFirst) { isFirst = NO; return; }
        
        uint16_t lastChar = (uint16_t)[updatedString2 characterAtIndex:updatedString2.length - 1];
        checkSum += lastChar;
    }];
    
    @weakify(testObject);
    _memoryTestVariable = [testObject.string1 mf_observe:@"self" block:^(NSString *_Nonnull updatedString1) {
        @strongify(testObject);
            
        static BOOL isFirst = YES;
        if (isFirst) { isFirst = NO; return; }
        
        NSInteger lastIndex = testObject.string1.length - 1;
        uint16_t lastChar = (uint16_t)[updatedString1 characterAtIndex:lastIndex];
        
        [testObject.string2 appendString:stringf(@"%d", lastChar + 1)];
        [testObject.string2 appendString:stringf(@"%d", lastChar + 2)];
    }];
    
    for (NSInteger i = 0; i < iterations; i++) {
        
        [testObject.string1 appendString:stringf(@"%ld", (long)i)];
    }
    
    CFTimeInterval endTime = CACurrentMediaTime();
    NSLog(@"KVO - strings - count: %ld, checksum: %ld", iterations, checkSum);
    
    return endTime - startTime;
}
NSTimeInterval runPureObjcTest_Strings(NSInteger iterations) {
    
    CFTimeInterval startTime = CACurrentMediaTime();
    __block NSInteger checkSum = 0;
    
    TestStrings *testObject = [[TestStrings alloc] init];
    testObject.string1 = [NSMutableString stringWithString:@"Hello"];
    testObject.string2 = [NSMutableString stringWithString:@"World"];
    
    void (^string2MutationCallback)(NSString *) =  ^(NSString *updatedString2){
        uint16_t lastChar = (uint16_t)[updatedString2 characterAtIndex:updatedString2.length - 1];
        checkSum += lastChar;
    };
    
    void (^string1MutationCallback)(NSString *) = ^(NSString *updatedString1) {
        
        NSInteger lastIndex = testObject.string1.length - 1;
        uint16_t lastChar = (uint16_t)[updatedString1 characterAtIndex:lastIndex];
        
        [testObject.string2 appendFormat:@"%d", lastChar + 1];
        string2MutationCallback(testObject.string2);
        [testObject.string2 appendFormat:@"%d", lastChar + 2];
        string2MutationCallback(testObject.string2);
    };
    
    for (NSInteger i = 0; i < iterations; i++) {
        [testObject.string1 appendFormat:@"%ld", (long)i];
        string1MutationCallback(testObject.string1);
    }
    
    CFTimeInterval endTime = CACurrentMediaTime();
    NSLog(@"pureObjc - strings - count: %ld, checksum: %ld", iterations, checkSum);
    
    return endTime - startTime;
}


@end
