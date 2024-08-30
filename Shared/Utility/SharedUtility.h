//
// --------------------------------------------------------------------------
// SharedUtility.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <CoreGraphics/CoreGraphics.h>
//#import <Foundation/Foundation.h>
#import "Constants.h"

// Import WannabePrefixHeader.h here so we don't have to manually include it in as many places (not sure if bad practise)
#import "Shorthands.h"
#import <CoreVideo/CoreVideo.h>

NS_ASSUME_NONNULL_BEGIN

/// Define shorthand for string formatting
///  Notes:
///     - Don't use `stringf(@"%s", some_c_string)`, it breaks for emojis and you can just use `@(some_c_string)` instead.
#define stringf(format, ...) [NSString stringWithFormat:(format), ##__VA_ARGS__]

/// Define xxxNSLocalizedString,
///     which is replaced with nothing by the preprocessor.
///     The purpose of this is to 'turn off' NSLocalizedString() statements that we don't need at the moment.

#define xxxNSLocalizedString(...)

/// Shorthand for Benchmarks
/// Example usage:
///     ```
///     MFBenchmarkBegin(coolBench);
///     <code to measure>
///     DDLogDebug(@"%s", MFBenchmarkResult(coolBench));
///     ```
/// Example output:
///     `MFBenchmark coolBench: 0.002750 ms - Average: 0.025277 ms (11 samples)`
///
/// Explanation of weird macro syntax:
/// - `({...})` is a GCC statement expression.
///- `__bn` is the benchmark name `##` appends it to a variable name, `#__bn` turns it into a c-string.

#define MFBenchmarkBegin(__benchmarkName) \
    CFTimeInterval m_benchmarkTimestampStart_##__benchmarkName = CACurrentMediaTime();

#define MFBenchmarkResult(__bn) \
    ({ \
        CFTimeInterval m_benchmarkTimestampEnd_##__bn = CACurrentMediaTime(); \
        CFTimeInterval m_benchmarkDiff_##__bn = m_benchmarkTimestampEnd_##__bn - m_benchmarkTimestampStart_##__bn; \
        \
        static NSInteger m_benchmarkNOfSamples_##__bn = 0; \
        static CFTimeInterval m_benchmarkAverage_##__bn = -1; \
        m_benchmarkNOfSamples_##__bn += 1; \
        if (m_benchmarkNOfSamples_##__bn == 1) { \
            m_benchmarkAverage_##__bn = m_benchmarkDiff_##__bn; \
        } else { \
            m_benchmarkAverage_##__bn = (m_benchmarkDiff_##__bn/m_benchmarkNOfSamples_##__bn) + ((m_benchmarkAverage_##__bn/m_benchmarkNOfSamples_##__bn)*(m_benchmarkNOfSamples_##__bn-1)); \
        } \
        \
        static char m_benchmarkResult_##__bn[512]; \
        snprintf(m_benchmarkResult_##__bn, sizeof(m_benchmarkResult_##__bn), "MFBenchmark %s: %f ms - Average: %f ms (%ld samples)", #__bn, m_benchmarkDiff_##__bn*1000.0, m_benchmarkAverage_##__bn*1000.0, (long)m_benchmarkNOfSamples_##__bn); \
        m_benchmarkResult_##__bn; \
    })

/// Check if ptr is objc object
///     Copied from https://opensource.apple.com/source/CF/CF-635/CFInternal.h
#define CF_IS_TAGGED_OBJ(PTR)    ((uintptr_t)(PTR) & 0x1)
extern inline bool _objc_isTaggedPointer(const void *ptr);     /// Copied from https://blog.timac.org/2016/1124-testing-if-an-arbitrary-pointer-is-a-valid-objective-c-object/

@interface SharedUtility : NSObject

typedef void(*MFCTLCallback)(NSTask *task, NSPipe *output, NSError *error);

NSString *getMFRedirectionServiceLink(NSString *_Nonnull target, NSString *_Nullable message, NSDictionary *_Nullable otherQueryParamsDict);
CFTimeInterval machTimeToSeconds(uint64_t tsMach);
uint64_t secondsToMachTime(CFTimeInterval tsSeconds);
NSException * _Nullable tryCatch(void (^tryBlock)(void));
void *offsetPointer(void *ptr, int byteOffset);
bool runningPreRelease(void);
bool runningMainApp(void);
bool runningHelper(void);
//bool runningAccomplice(void);

+ (id)getPrivateValueOf:(id)obj forName:(NSString *)name;
+ (NSString *)dumpClassInfo:(id)obj;
+ (NSString *)launchCLT:(NSURL *)executableURL withArguments:(NSArray<NSString *> *)arguments error:(NSError ** _Nullable)error;
+ (void)launchCLT:(NSURL *)commandLineTool withArgs:(NSArray <NSString *> *)arguments;
+ (FSEventStreamRef)scheduleFSEventStreamOnPaths:(NSArray<NSString *> *)urls withCallback:(FSEventStreamCallback)callback;
+ (void)destroyFSEventStream:(FSEventStreamRef)stream;
+ (NSPoint)quartzToCocoaScreenSpace_Point:(CGPoint)quartzPoint;
+ (CGPoint)cocoaToQuartzScreenSpace_Point:(NSPoint)cocoaPoint;
+ (NSRect)quartzToCocoaScreenSpace:(CGRect)quartzFrame;
+ (CGRect)cocoaToQuartzScreenSpace:(NSRect)cocoaFrame;
+ (id)deepMutableCopyOf:(id)object;
+ (id)deepCopyOf:(id)object;
+ (id<NSCoding>)deepCopyOf:(id<NSCoding>)original error:(NSError *_Nullable *_Nullable)error;
+ (NSString *)callerInfo;
+ (NSDictionary *)dictionaryWithOverridesAppliedFrom:(NSDictionary *)src to: (NSDictionary *)dst;
+ (CGEventType)CGEventTypeForButtonNumber:(MFMouseButtonNumber)button isMouseDown:(BOOL)isMouseDown;
+ (CGMouseButton)CGMouseButtonFromMFMouseButtonNumber:(MFMouseButtonNumber)button;
+ (int8_t)signOf:(double)x;
int8_t sign(double x);
+ (NSString *)currentDispatchQueueDescription;
+ (void)printInvocationCountWithId:(NSString *)strId;
+ (BOOL)button:(NSNumber * _Nonnull)button isPartOfModificationPrecondition:(NSDictionary *)modificationPrecondition;
+ (NSString *)binaryRepresentation:(unsigned int)value;
+ (void)resetDispatchGroupCount:(dispatch_group_t)group;

@end

NS_ASSUME_NONNULL_END
