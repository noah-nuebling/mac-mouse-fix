//
// --------------------------------------------------------------------------
// SharedUtility.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// ------------------------

/// Import dependencies
///     Note: Maybe we should keep imports minimal for better compile-times, since SharedUtility.h is imported in many places?
#import <CoreGraphics/CoreGraphics.h>
//#import <Foundation/Foundation.h>
#import "Constants.h"

#import "Shorthands.h"
#import <CoreVideo/CoreVideo.h>
#import "objc/runtime.h"
#import "SharedMacros.h"

/// Import other stuff so we don't have to import it in so many places
#import "MFDefer.h"

/// 'Basic' NSErrors
///     Use this to create an NSError (which is the most universally compatible type of error across Swift and objc afaik), and you only need to specify a "reason" string – no "error domain" or "error code" or additional info.
NS_INLINE NSError *_Nonnull MFNSErrorBasicMake(NSString *_Nonnull reason) {
    return [[NSError alloc] initWithDomain: @"" code: 0 userInfo: @{ @"reason": reason }];
}
NS_INLINE NSString *_Nullable MFNSErrorBasicGetReason(NSError *_Nonnull error) {
    return error.userInfo[@"reason"];
}

///
/// SharedUtility object
///

@interface SharedUtility : NSObject

NS_ASSUME_NONNULL_BEGIN

NSString *MFLocale(void);
void MFCFRunLoopPerform(CFRunLoopRef _Nonnull rl, NSArray<NSRunLoopMode> *_Nullable modes, void (^_Nonnull workload)(void));
bool MFCFRunLoopPerform_sync(CFRunLoopRef _Nonnull rl, NSArray<NSRunLoopMode> *_Nullable modes, NSTimeInterval timeout, void (^_Nonnull workload)(void));
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
+ (void)destroyFSEventStream:(FSEventStreamRef _Nullable)stream;
+ (NSPoint)quartzToCocoaScreenSpace_Point:(CGPoint)quartzPoint;
+ (CGPoint)cocoaToQuartzScreenSpace_Point:(NSPoint)cocoaPoint;
+ (NSRect)quartzToCocoaScreenSpace:(CGRect)quartzFrame;
+ (CGRect)cocoaToQuartzScreenSpace:(NSRect)cocoaFrame;
+ (id)deepMutableCopyOf:(id)object;
+ (id _Nullable)deepCopyOf:(id _Nullable)object;
+ (id<NSCoding> _Nullable)deepCopyOf:(id<NSCoding> _Nonnull)original error:(NSError *_Nullable *_Nullable)error;
+ (NSString *)callerInfo;
+ (NSDictionary *)dictionaryWithOverridesAppliedFrom:(NSDictionary *)src to: (NSDictionary *)dst;
+ (CGEventType)CGEventTypeForButtonNumber:(MFMouseButtonNumber)button isMouseDown:(BOOL)isMouseDown;
+ (CGMouseButton)CGMouseButtonFromMFMouseButtonNumber:(MFMouseButtonNumber)button;
+ (NSString *)currentDispatchQueueDescription;
+ (void)printInvocationCountWithId:(NSString *)strId;
+ (BOOL)button:(NSNumber * _Nonnull)button isPartOfModificationPrecondition:(NSDictionary *)modificationPrecondition;
+ (void)resetDispatchGroupCount:(dispatch_group_t)group;
NSString *_Nonnull bitflagstring(int64_t flags, NSString *const _Nullable bitToNameMap[_Nullable], int bitToNameMapCount);

NS_ASSUME_NONNULL_END

@end
