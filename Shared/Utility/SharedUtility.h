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

/// Import WannabePrefixHeader.h here so we don't have to manually include it in as many places (not sure if bad practise)
#import "WannabePrefixHeader.h"

/// Import other stuff so we don't have to import it in so many places
#import "MFDefer.h"

/// Helper macros
///     To implement other macros
#define UNPACK(args...) args /// This allows us to include `,` inside an argument to a macro (but the argument then needs to be wrapped inside `()` by the caller of the macro )
#define APPEND_ARGS(args...) , ## args /// This is like UNPACK but it also automatically inserts a comma before the args. The ## deletes the comma, if `args` is empty. I have no idea why. But this lets us nicely append args to an existing list of arguments in a function call or function header.

/// `nowarn_begin()` and `nowarn_end()` macros:
///     Temporarily disable all clang warnings (-Weverything).
///     Example usage:
///     ```
///     nowarn_begin();
///     <Code that triggers warnings>
///     nowarn_end();
///     ```

#define nowarn_begin()                                      \
    _Pragma("clang diagnostic push")                        \
    _Pragma("clang diagnostic ignored \"-Weverything\"")    \

#define nowarn_end()                                        \
    _Pragma("clang diagnostic pop")

/// `_isobject()` – internal helper macro.
///     Check if an expression evaluates to an objc object.
#define _isobject(expression) __builtin_types_compatible_p(typeof(expression), id)

/// `ifthen()` macro
/// boolean algrebra implication operator
///     TODO: Replace this with the properly documented impl from EventLoggerForBrad
#define ifthen(a, b) (!(a) || (b))

/// `rangefromto` macro
///     Alternative to NSMakeRange(), lets you specify the range in terms of (firstindex, lastindex) instead of (firstindex, count) – which I find more intuitive.
#define rangefromto(firstindex, lastindex) ({                     \
    __auto_type __firstindex = (firstindex);                    \
    NSMakeRange(__firstindex, (lastindex) - __firstindex + 1);  \
})

/// array count convenience
#define arrcount(x) (sizeof(x) / sizeof((x)[0]))

/// `MFNSSetMake()`
///     Substitute for missing NSSet literal
///     You could also do `[NSSet setWithArray:@[objects...]]`, but I assume that's less efficient.

#define MFNSSetMake(objects...) ({                                          \
    id __objects[] = { objects };                                           \
    [[NSSet alloc] initWithObjects: __objects count: arrcount(__objects)];    \
})

/// `bcase()`/`fcase()` macros
///     - Use these inside switches instead of `case` and `default` for more concise syntax
///     - `bcase()` automatically (b)reaks after each case! (Treat this as the default)
///     - If you ever do need to (f)all through, use `fcase()`.
///     - When you pass 0 arguments to bcase()/fcase(), they expand to the 'default' case.
///
/// Example usage:
///     ```
///     switch (x) {
///         bcase (A):          doA();
///         bcase (B, C):       doBC();
///         fcase (D):          doBCD();
///         bcase ():           doDefault();
///     }
///     ```
///     ... This expands to:
///         ```
///         switch (x) {
///             break; case A:          doA();       // The leading break statement is simply ignored
///             break; case B: case C:  doBC();
///                    case D:          doBCD();     // Since we used fcase(), there's no break statement, and we (f)all through from the previous case.
///             break; default:         doDefault(); // 0 arguments expand to the `default` case
///         }
///         ```
///     ... Which is equivalent to the traditional style of writing this switch:
///         ```
///         switch (x) {
///             case A:
///                 doA();
///                 break;
///             case B:
///             case C:
///                 doBC();
///             case D:
///                 doBCD();
///                 break;
///             default:
///                 doDefault();
///         }
///         ```
/// Meta:
///     - [Feb 2025]
///         These macros are a bit complex for what they do – you could achieve similar conciseness and clarity for 95% of cases (ha ha) with a simple `#define bcase break; case`.
///         However, then you'd still have to use `case` both to match multiple values *and* to get fallthrough behavior.
///         I think using bcase by default, fcase to get fallthrough, and using comma-separated-list to match multiple values is significantly nicer and clearer.
///         -> So we'll stick with this complicated implementation for now.
///             That way we can do anything we'd ever wanna do with switches using `bcase()`/`fcase()` – which has very clear semantics, and we'd never have to go back to using the raw `case` keyword for anything.

/// fcase – (f)allthrough variant

#define _fcase_0()              default
#define _fcase_1(x)             case x
#define _fcase_2(x, rest)       case x: _fcase_1(rest)
#define _fcase_3(x, rest...)    case x: _fcase_2(rest)
#define _fcase_4(x, rest...)    case x: _fcase_3(rest)
#define _fcase_5(x, rest...)    case x: _fcase_4(rest)
#define _fcase_6(x, rest...)    case x: _fcase_5(rest)
#define _fcase_7(x, rest...)    case x: _fcase_6(rest) /** 7 should be more than enough */

#define _fcase_selector(_dummy_, arg1, arg2, arg3, arg4, arg5, arg6, arg7, macroname, ...) macroname

#define fcase(values...) \
    _fcase_selector(_dummy_, ## values, _fcase_7, _fcase_6, _fcase_5, _fcase_4, _fcase_3, _fcase_2, _fcase_1, _fcase_0)(values) /** Trick: `_dummy_` arg is necessary because ## only deletes commas (,) to its left (I think). */

/// bcase – (b)reaking variant

#define bcase(values...) \
    break; fcase(values)

/// `isclass` macro
/// Behavior:
///     isclass(x, classname) works on both normal objects and class objects.
///         If `x` is a normal object:                  Checks whether *the class of x*  is equivalent to, or a subclass of, the class called `classname`
///         If `x` is a class-object:                    Checks whether *x itself*             is equivalent to, or a subclass of, the class called `classname`
///         -> Therefore, this replaces both [isKindOfClass:] and [isSubclassOfClass:]
/// Why does this work?
///     On a normal object:    `class` returns the class-object, and `object_getClass()` also returns the class-object.
///     On a class-object:       `class` returns the class-object, but `object_getClass()` returns the *meta-class-object*.
/// Performance:
///     Not how much slower this is compared to [isKindOfClass:] or [isSubclassOfClass:]. Prolly not significant.
/// Alternative implementation:
///     `[[(x) class] isSubclassOfClass: [classname class]]`
///         -> Isn't that a simpler way to achieve the same thing?
///         Meta: I think I used `object_getClass()` because I read somewhere that it is safer than some alternative.
///             I though the alternative might be `-isSubclassOfClass:` but I think the alternative was actually `objc_getMetaClass()` and I read about this here: https://stackoverflow.com/a/20833446/10601702
///

#define isclass(x, classname) \
    [[(x) class] isKindOfClass: object_getClass([classname class])]

/// `isprotocol` macro
///     - Works on normal objects and class objects just like `isclass()`
///     - The docs say this is slow, and to use -[respondsToSelector:] instead See: https://developer.apple.com/documentation/objectivec/nsobject/1418893-conformstoprotocol?language=objc

#define isprotocol(x, protocolname) \
    [[x class] conformsToProtocol: @protocol(protocolname)]

/// `threadobject()` and `staticobject()`  macros – creates an objc object whose state is retained between invocations.
///     Scope:
///     > `threadobject()` retains the state between all invocations on the same thread.
///     > `staticobject()` retains the state between all invocations in the same process.
///
///     Example usage:
///     `staticobject()`:
///         ```
///         NSCache *cache = staticobject([[NSCache alloc] init]);
///         id fromCache = [cache valueForKey: @"SomeKey"];
///         if (fromCache) return fromCache;
///         <...>
///         [cache setValue: expensiveValue forKey: @"SomeKey"]; /// (Caution: Generally, modifying the result of staticobject() isn't thread-safe. This particular example is thread-safe because NSCache uses locks internally.)
///         ```
///     `threadobject()`:
///         ```
///         NSMutableArray *arr = threadobject([NSMutableArray alloc] init]);
///         [arr addObject: @"a"];
///         NSLog("%@", arr);       // Will print more and more "a" strings as this code is invoked multiple times on the same thread.
///         ```
///
///     Meta: why is the threadobject implementation so complicated?
///         Objc objects aren't compatible with `static __thread` variables under ARC. That's why our implementation uses `[[NSThread currentThread] threadDictionary]` under the hood.
///
///     Meta: Only use mutable objects.
///         Overriding the returned pointer will not update the static/thread-local state. Instead you have to create mutable objects in static/thread-local storage, and then modify them.
///
///     Meta: what about storing non-objects?
///        To create non-objects variables that are static or thread-local, you can just use the `static`/`static __thread` keywords directly.
///        How to initialize non-objects?
///         - If your initial value is a compile-time-constant:          you can even initialize them very simply, like this `static int count = 99;`.
///         - If your initial value is not compile-time-constant:       you can use `dispatch_once()` (for static vars) or a `static __thread bool is_initialized` flag (for thread local vars.).

#define staticobject(initializer_expr)                 \
    (typeof(initializer_expr))                      \
    ({                                              \
        static_assert(_isobject(initializer_expr), "Use `static` for static variables that are not Objective-C objects."); \
        static typeof(initializer_expr) __result;   \
        static dispatch_once_t __oncetoken;         \
        dispatch_once(&__oncetoken, ^{              \
            __result = (initializer_expr);          \
        });                                         \
        __result;                                   \
    })

#define threadobject(initializer_expr)                                  \
    (typeof(initializer_expr))                                          \
    ({                                                                  \
        static_assert(_isobject(initializer_expr), "Use `static __thread` for thread-local variables that are not Objective-C objects."); \
        static NSString *__key;                                         \
        static dispatch_once_t __oncetoken;                             \
        dispatch_once(&__oncetoken, ^{                                  \
            __key = stringf(@"mf.threadobject.%p", &__key);             \
        });                                                             \
        NSMutableDictionary *__thread_dict =                            \
            [[NSThread currentThread] threadDictionary];                \
        typeof(initializer_expr) __result = __thread_dict[__key];       \
        if (!__result) {                                                \
            __result = (initializer_expr);                              \
            __thread_dict[__key] = __result;                            \
        }                                                               \
        __result;                                                       \
    })

/// String (f)ormatting convenience.
///  Notes:
///     - Don't use `stringf(@"%s", some_c_string)`, it breaks for emojis and you can just use `@(some_c_string)` instead.
#define stringf(format, ...) [NSString stringWithFormat: (format), ## __VA_ARGS__]

#define binarystring(__v) /** This is a macro to make this function generic. The output string's width will automatically match the byte count of the input type (by using sizeof()) */\
    (NSString *) \
    ({ \
        typeof(__v) m_value = __v; /** We call it `m_value` so there's no conflict in case `__v` is `value`. `m_` stands for `macro`. */ \
        int nibble_size = 8; \
        int nibble_count = sizeof(m_value)*8 / nibble_size; \
        int bit_str_len = (nibble_count * (nibble_size+1)) - 1; \
        char bit_str[bit_str_len + 1]; \
        bit_str[bit_str_len] = '\0'; /** Null terminator */ \
        for (int i = bit_str_len-1; i >= 0; i--) { \
            if (i % (nibble_size+1) == nibble_size) { /** Add a space every `nibble_size` bits for better legibility */ \
                bit_str[i] = ' '; \
            } else { \
                bit_str[i] = (m_value & 1) ? '1' : '0'; \
                m_value = m_value >> 1; \
            } \
        } \
        [NSString stringWithUTF8String: bit_str]; \
    })

///
/// Define xxxNSLocalizedString macro,
///     which is replaced with nothing by the preprocessor.
///     The purpose of this is to 'turn off' NSLocalizedString() statements that we don't need at the moment.

#define xxxNSLocalizedString(...)

///
/// MFBenchmark macros
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

///
/// Check if ptr is objc object
///     Copied from https://opensource.apple.com/source/CF/CF-635/CFInternal.h
///     Also see: https://blog.timac.org/2016/1124-testing-if-an-arbitrary-pointer-is-a-valid-objective-c-object/
#define CF_IS_TAGGED_OBJ(PTR)    ((uintptr_t)(PTR) & 0x1)

/// 'Basic' NSErrors
///     Use this to create an NSError (which is the most universally compatible type of error across Swift and objc afaik), and you only need to specify a "reason" string – no "error domain" or "error code" or additional info.
NS_INLINE NSError *_Nonnull MFNSErrorBasicMake(NSString *_Nonnull reason) {
    return [[NSError alloc] initWithDomain: @"" code: 0 userInfo: @{ @"reason": reason }];
}
NS_INLINE NSString *_Nullable MFNSErrorBasicGetReason(NSError *_Nonnull error) {
    return error.userInfo[@"reason"];
}

///
/// MFStringEnum macros
///     These macros simplify creating an `NS_TYPED_ENUM` with underlying NSString values
///
/// Example usage:
///     ```
///     MFStringEnum(MFLinkID)
///     MFStringEnumCase(kMFLinkID, CapturedButtonsGuide)
///     MFStringEnumCase(kMFLinkID, CapturedScrollingGuide)
///     MFStringEnumCase(kMFLinkID, VenturaEnablingGuide)
///     ```
///
/// ... which would expand to:
///     ```
///     typedef NSString * MFLinkID NS_TYPED_ENUM;
///     static MFLinkID * const kMFLinkIDCapturedButtonsGuide    = @"CapturedButtonsGuide";
///     static MFLinkID * const kMFLinkIDCapturedScrollingGuide  = @"CapturedScrollingGuide";
///     static MFLinkID * const kMFLinkIDVenturaEnablingGuide    = @"VenturaEnablingGuide";
///     ```
///
/// Discussion:
/// - Using `static` in `MFStringEnumCase()` to prevent linker errors. This makes it so every source file has its own copy of these constants afaik, which is inefficient. More efficient way afaik would be to use `extern` for the declaration
///     and then define the underlying NSString values inside the .m file. However, using static is easier since it lets us declare everything in one place and I'm sure the performance difference is negligible.
///
/// Probably don't use this:
///     Using `NS_TYPED_ENUM` makes swift rename the cases. E.g. `kMFLinkIDCapturedButtonsGuide` -> `MFLinkID.capturedButtonsGuide`. However this breaks for some of our cases (MMFLActivate), and makes it harder to search the project for usages of the cases.
///     The main benefit of this is that Swift lets you omit the enum name (so you just have to type `.capturedButtonsGuide` instead of `MFLinkID.capturedButtonsGuide`), but omitting stuff like that makes compile time slower afaik, which I really want to prevent - so I wouldn't do that anyways. (Swift compile times are painfully slow)
///     So in conclusion - we don't want the renaming.
///
///     I think the renaming shenanigans is the whole reason why `NS_TYPED_ENUM` even exists? (Don't know of anything else that it does.) And the `MFStringEnum` macros exist to make `NS_TYPED_ENUM` easier to use for me.
///     So perhaps it's better to not use the `MFStringEnum` macros at all and instead just declare the enum with a simple `typedef` and the cases with simple `#define`s.
///     That would look like this:
///     ```
///     typedef NSString * MFLinkID;
///     #define kMFLinkIDCapturedButtonsGuide @"CapturedButtonsGuide"
///     #define kMFLinkIDCapturedScrollingGuide @"CapturedScrollingGuide"
///     #define kMFLinkIDVenturaEnablingGuide @"VenturaEnablingGuide"
///     ```

#define MFStringEnum(__enumName) \
    typedef NSString * __enumName NS_TYPED_ENUM; \

#define MFStringEnumCase(__enumName, __caseName) \
    static __enumName const k ## __enumName ## __caseName = @(#__caseName);

///
/// SharedUtility object
///

@interface SharedUtility : NSObject

NS_ASSUME_NONNULL_BEGIN

NSString *getMFRedirectionServiceLink(NSString *_Nonnull target, NSString *_Nullable message, NSDictionary *_Nullable otherQueryParamsDict);
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
+ (void)setupBasicCocoaLumberjackLogging;
+ (void)resetDispatchGroupCount:(dispatch_group_t)group;

NS_ASSUME_NONNULL_END

@end

/// -------------------------------------
///     Macros that are tooo crazy
/// -------------------------------------


#if 0
    /// `allequal` macro
    /// Example usage:
    ///     `allequal(a, b, c)`
    ///     ... This expands to:
    ///         `({ __auto_type __y3 = (b); (a) == __y3 && ((__y3) == (c)); })`
    ///     ... which is equivalent to the following (minus deduplication of macro arg b):
    ///         `(a == b && b == c)`
    ///
    /// -> Not sure this is sensible to use. I'm crazy.

    #define _allequal2(x, y)          ((x) == (y))
    #define _allequal3(x, y, rest)    ({ __auto_type __y3 = (y); (x) == __y3 && _allequal2(__y3, rest); })
    #define _allequal4(x, y, rest...) ({ __auto_type __y4 = (y); (x) == __y4 && _allequal3(__y4, rest); })
    #define _allequal5(x, y, rest...) ({ __auto_type __y5 = (y); (x) == __y5 && _allequal4(__y5, rest); })
    #define _allequal6(x, y, rest...) ({ __auto_type __y6 = (y); (x) == __y6 && _allequal5(__y6, rest); })
    #define _allequal7(x, y, rest...) ({ __auto_type __y7 = (y); (x) == __y7 && _allequal6(__y7, rest); }) /// 7 Should be more than enough

    #define _allequal_selector(a1, a2, a3, a4, a5, a6, a7, macroname, ...) macroname

    #define allequal(x, y, rest...) \
        _allequal_selector(x, y, ## rest, _allequal7, _allequal6, _allequal5, _allequal4, _allequal3, _allequal2) (x, y, ## rest)

    /// `chaincmp` macro
    /// Example usage:
    ///     `chaincmp(a, ==, b, <, c)`
    ///     ... This expands to:
    ///         `({ __auto_type __y3 = (b); ((a) == __y3) && ((__y3) < (c)); })`
    ///     ... which is equivalent to the following (minus deduplication of macro arg b):
    ///         `(a == b && b < c)`
    ///
    /// -> Not sure this is sensible to use. I'm crazy.

    #define _chaincmpf(args...) ({ static_assert(false, "chaincmp() requires an odd number of arguments (alternating values and operators)."); 0; })

    #define _chaincmp2(x, op, y) ((x) op (y))
    #define _chaincmp3(x, op, y, rest...)   ({ __auto_type __y3 = (y); ((x) op __y3) && _chaincmp2(__y3, rest); })
    #define _chaincmp4(x, op, y, rest...)   ({ __auto_type __y4 = (y); ((x) op __y4) && _chaincmp3(__y4, rest); })
    #define _chaincmp5(x, op, y, rest...)   ({ __auto_type __y5 = (y); ((x) op __y5) && _chaincmp4(__y5, rest); })
    #define _chaincmp6(x, op, y, rest...)   ({ __auto_type __y6 = (y); ((x) op __y6) && _chaincmp5(__y6, rest); })
    #define _chaincmp7(x, op, y, rest...)   ({ __auto_type __y7 = (y); ((x) op __y7) && _chaincmp6(__y7, rest); }) /// 7 Should be more than enough

    #define _chaincmp_selector(_1, o1, _2, o2, _3, o3, _4, o4, _5, o5, _6, o6, _7, macroname, ...) macroname

    #define chaincmp(x, op, y, rest...) _chaincmp_selector(x, op, y, ## rest, _chaincmp7, _chaincmpf, _chaincmp6, _chaincmpf,  _chaincmp5, _chaincmpf, _chaincmp4, _chaincmpf, _chaincmp3, _chaincmpf, _chaincmp2) (x, op, y, ## rest)
#endif
