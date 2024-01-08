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
#import "WannabePrefixHeader.h"
#import "Shorthands.h"
#import <CoreVideo/CoreVideo.h>

NS_ASSUME_NONNULL_BEGIN

#define stringf(format, ...) [NSString stringWithFormat:(format), ##__VA_ARGS__]

/// Check if ptr is objc object
///     Copied from https://opensource.apple.com/source/CF/CF-635/CFInternal.h
#define CF_IS_TAGGED_OBJ(PTR)    ((uintptr_t)(PTR) & 0x1)
extern inline bool _objc_isTaggedPointer(const void *ptr);     /// Copied from https://blog.timac.org/2016/1124-testing-if-an-arbitrary-pointer-is-a-valid-objective-c-object/

@interface SharedUtility : NSObject

typedef void(*MFCTLCallback)(NSTask *task, NSPipe *output, NSError *error);

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
+ (void)setupBasicCocoaLumberjackLogging;
+ (NSString *)binaryRepresentation:(unsigned int)value;
+ (void)resetDispatchGroupCount:(dispatch_group_t)group;

#pragma mark - Clipping

/// CLIP AKA CLAMP, BOUND
/// Src: https://stackoverflow.com/a/14770282/10601702

//#define MIN(A,B)    ({ __typeof__(A) __a = (A); __typeof__(B) __b = (B); __a < __b ? __a : __b; })
//#define MAX(A,B)    ({ __typeof__(A) __a = (A); __typeof__(B) __b = (B); __a < __b ? __b : __a; })

#define CLIP(x, low, high) ({\
__typeof__(x) __x = (x); \
__typeof__(low) __low = (low);\
__typeof__(high) __high = (high);\
__x > __high ? __high : (__x < __low ? __low : __x);\
})

@end

NS_ASSUME_NONNULL_END
