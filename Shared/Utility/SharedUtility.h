//
// --------------------------------------------------------------------------
// SharedUtility.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <CoreGraphics/CoreGraphics.h>
//#import <Foundation/Foundation.h>
#import "Constants.h"

// Import WannabePrefixHeader.h here so we don't have to manually include it in as many places (not sure if bad practise)
#import "WannabePrefixHeader.h"
#import "Shorthands.h"
#import <CoreVideo/CoreVideo.h>

#define stringf(format, ...) [NSString stringWithFormat:(format), ##__VA_ARGS__]

NS_ASSUME_NONNULL_BEGIN

@interface SharedUtility : NSObject

typedef void(*MFCTLCallback)(NSTask *task, NSPipe *output, NSError *error);

void *offsetPointer(void *ptr, int byteOffset);
+ (BOOL)runningPreRelease;

+ (BOOL)runningMainApp;
+ (BOOL)runningHelper;
+ (BOOL)runningAccomplice;

+ (CVReturn)displayUnderMousePointer:(CGDirectDisplayID *)dspID withEvent:(CGEventRef _Nullable)event;
+ (CVReturn)display:(CGDirectDisplayID *)dspID atPoint:(CGPoint)point;

+ (NSString *)dumpClassInfo:(Class)class;
+ (NSString *)launchCLT:(NSURL *)executableURL withArguments:(NSArray<NSString *> *)arguments error:(NSError ** _Nullable)error;
+ (void)launchCLT:(NSURL *)commandLineTool withArgs:(NSArray <NSString *> *)arguments;
+ (FSEventStreamRef)scheduleFSEventStreamOnPaths:(NSArray<NSString *> *)urls withCallback:(FSEventStreamCallback)callback;
+ (void)destroyFSEventStream:(FSEventStreamRef)stream;
+ (NSRect)quartzToCocoaScreenSpace:(CGRect)quartzFrame;
+ (CGRect)cocoaToQuartzScreenSpace:(NSRect)cocoaFrame;
+ (id)deepMutableCopyOf:(id)object;
+ (id)deepCopyOf:(id)object;
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
