//
// --------------------------------------------------------------------------
// AnnotationUtility.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
@import AppKit.NSAccessibility;

NS_ASSUME_NONNULL_BEGIN

@interface AnnotationUtility : NSObject

#pragma mark - Runtime

#define getReturnAddress() \
    __builtin_return_address(0) /// If this fails, `backtrace()` should be more robust

NSString *getExecutablePath(void);
NSString *getImagePath(void *address);
NSString *getSymbol(void *address);

typedef NSString * MFClassSearchCriterion NS_TYPED_ENUM;
#define MFClassSearchCriterionFrameworkName @"framework"
#define MFClassSearchCriterionClassNamePrefix @"namePrefix"
#define MFClassSearchCriterionProtocol @"protocol"
#define MFClassSearchCriterionSuperclass @"superclass"

NSArray<Class> *searchClasses(NSDictionary<MFClassSearchCriterion, id> *criteria);
bool classInheritsMethod(Class class, SEL selector);

#pragma mark - Swizzling

/// Typedefs

typedef id InterceptorBlock; /// Will be passed into `imp_implementationWithBlock`
typedef IMP OriginalImplementation;
typedef InterceptorBlock _Nonnull (^InterceptorFactory)(Class originalClass, SEL originalSelector, OriginalImplementation _Nonnull originalImplementation);

/// Main interface

void swizzleMethod(Class cls, SEL originalSelector, InterceptorFactory interceptorFactory);
void swizzleMethodOnClassAndSubclasses(Class baseClass, NSDictionary<MFClassSearchCriterion, id> *subclassSearchCriteria, SEL originalSelector, InterceptorFactory interceptorFactory);

/// Main macro
/// Note:
///     We had an older alternate factory-maker that used inline typedef to be more neat and totally properly typed, but it seemed to break autocomplete

#define MakeInterceptorFactory(__MethodReturnType, __MethodArguments, __OnIntercept...) \
    (id)                                                                            /** Cast the entire factory block to id to silence type-checker */ \
    ^InterceptorBlock (Class m_originalClass, SEL m__cmd, __MethodReturnType (*m_originalImplementation)(id self, SEL _cmd APPEND_ARGS __MethodArguments)) /** Return type and args of the factory  block */ \
    {                                                                               /** Body of the factory block */ \
        return ^__MethodReturnType (id m_self APPEND_ARGS __MethodArguments)        /** Return type and args of the interceptor block */ \
            __OnIntercept;                                                          /**  Body of the interceptor block - the code that the caller of the macro provided. This will be executed when the method is intercepted. Needs to be the varargs (...) to prevent weird compiler errors. */ \
    } \

/// Convenience macros
///     To be used inside the `__OnIntercept` codeblock passed to the `MakeInterceptorFactory()` macro

#define OGImpl(args...) \
    m_originalImplementation(m_self, m__cmd APPEND_ARGS(args))

#pragma mark - Recursions

void countRecursions(id recursionDepthKey, void (^workload)(NSInteger recursionDepth));

#pragma mark - Parse format strings

NSRegularExpression *formatStringRecognizer(NSString *formatString);

#pragma mark - objc introspection

NSArray<Class> *getSuperClasses(id obj);

Class getMetaClass(id obj);

NSString *listMethods(id obj);
NSString *listSuperClasses(id obj);
NSString *blockDescription(id block);


@end

NS_ASSUME_NONNULL_END
