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

NSString *_Nullable getExecutablePath(void);
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

#define InterceptorFactory_Begin(methodReturnType, methodArguments) \
    (id)                                                                            /** Cast the entire factory block to id to silence type-checker */ \
    ^InterceptorBlock (Class m_originalClass, SEL m_cmd, methodReturnType (*m_originalImplementation)(id self, SEL _cmd APPEND_ARGS methodArguments)) /** Header of the factory block */ \
    {                                                                               \
        return ^methodReturnType (id m_self APPEND_ARGS methodArguments)            /** Header of the interceptor block */ \
        {                                                                           /** After this the macro user can type the body of the interceptor block. This will be executed when the method is intercepted. */ \

#define InterceptorFactory_End() \
    };}


/// Convenience macros
///     To be used inside the codeblock after the `InterceptorFactory_Begin()` macro

#define OGImpl(args...) \
    m_originalImplementation(m_self, m_cmd ,## args)

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

#pragma mark - Other
CGRect MFCGRectFlip(CGRect rect, CGFloat parentRectHeight);


@end

NS_ASSUME_NONNULL_END
