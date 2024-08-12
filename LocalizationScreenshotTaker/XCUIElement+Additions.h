//
// --------------------------------------------------------------------------
// XCUIElement+Swizzle.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

@import XCTest;
#import "AnnotationUtility.h"

///
/// Notes:
/// - Use `listMethods([XCUIElement class])` in the lldb console to easily discover private methods
/// - Interesting Classes:
///     - `XCUIAccessibilityInterface_macOS` -> seems like a powerful object-oriented wrapper around AXUIElement API. Called by `-[XCElementSnapshot hitTest:]` to do the main hitTesting work I think.

NS_ASSUME_NONNULL_BEGIN

///
/// Extending public interfaces
///

@interface XCUIApplication (MFStuff)
- (void)_waitForQuiescence;
@end

@interface XCUIScreen (MFStuff)
- (CGDirectDisplayID)displayID;
@end

@interface XCUIElement (MFStuff)

- (id)identifier;

- (NSRect)screenshotFrame;

- (XCUIApplication *)application;
- (XCUIDevice *)device;
- (XCUIScreen *)screen;
@end

///
/// Private interfaces
///

@interface XCUIHitPointResult
- (BOOL)isHittable;
- (CGPoint)hitPoint;
@end

@interface XCAccessibilityElement /// If you use this directly from Swift, there will be linker errors.
- (id)AXUIElement;
@end

@interface XCElementSnapshot
- (NSArray<NSValue *> *)suggestedHitpoints; /// Result array contains NSPoints wrapped in NSValues
- (XCAccessibilityElement *)accessibilityElement;
- (XCElementSnapshot *)hitTest:(CGPoint)point; /// I think this returns the child element at `point`. `point` seems to be in screenspace coords. || Update: Can't figure out how to call this so far - always returns nil.
- (XCUIHitPointResult *)hitPoint:(id _Nullable *_Nullable)somethingPtr;
- (XCUIHitPointResult *)hitPointPointForScrolling:(id _Nullable *_Nullable)somethingPtr;
@end

///
/// Swift wrappers
///     For XCElementSnapshot, since we get linker errors when we use it from swift.

XCUIHitPointResult *_Nullable hitPointForSnapshot_ForSwift(id<XCUIElementSnapshot> snapshot, id _Nullable *_Nullable idk);
AXUIElementRef _Nullable getAXUIElementForXCElementSnapshot(id<XCUIElementSnapshot> snapshot);

///
/// Helper macros
///

/// MakeCFunctionForMethod macro
///
/// Explanation:
///     Usually, when there's a private class or method we want to access, we can just declare the interface for the class/method,
///     and the linker will automatically link to the correct implementation at compile time. But for some classes, the linker fails for some reason.
///     So instead we write a c function which finds and calls the method at runtime.
///     These macros help us write such c functions.
///
/// Update:
///     This is not needed - I found a simpler way: I can link XCElementSnapshot etc fine in objc and then write a wrapper to call from swift.
///
/// Usage example:
///         To make a c function that calls `-[XCElementSnapshot suggestedHitpointsInRect:cacheResults:]` add this in the .m file:            (Note how `:` is replaced with `__`, since `:` is not allowed in a c-function name)
///         ```
///         MakeCFunctionForMethod(XCElementSnapshot, NSArray *, suggestedHitpointsInRect__cacheResults__,  (NSRect rect, BOOL doCache), (rect, doCache));
///         ```
///         Add this in your .h file:
///         ```
///         MakeCFunctionForMethod_Decl(XCElementSnapshot, NSArray *, suggestedHitpointsInRect__cacheResults__, (NSRect rect, BOOL doCache), (rect, doCache));
///         ```
///         Then call the method like this:
///         ```
///         NSArray *result = XCElementSnapshot_suggestedHitpointsInRect__cacheResults__(<some NSRect>, <some BOOL>);
///         ```

#define APPEND_ARGS(args...) , ## args

#define MakeCFunctionForMethod(__className, __returnType, __methodNameEscaped, __args, __callArgs) \
    __returnType __className##_##__methodNameEscaped(id m_instance APPEND_ARGS __args) { \
        Class m_instanceClass = object_getClass(m_instance); \
        const char *m_instanceClassName = class_getName(m_instanceClass); \
        if (strcmp(m_instanceClassName, #__className) != 0) { \
            NSLog(@"Error: CFunctionForMethod call: The class of the instance (%s) didn't match the class of the method (%s)", m_instanceClassName, #__className); \
            assert(false); \
            return nil; \
        } \
        NSString *m_methodName = [@(#__methodNameEscaped) stringByReplacingOccurrencesOfString:@"__" withString:@":"]; \
        SEL m_sel = NSSelectorFromString(m_methodName); \
        __returnType (*m_imp)(id obj, SEL sel APPEND_ARGS __args) = (void *)class_getMethodImplementation(m_instanceClass, m_sel); \
        if (m_imp == NULL) { \
            NSLog(@"Error: CFunctionForMethod call: Implementation of method (%@) of class (%s) is NULL.", m_methodName, #__className); \
            assert(false); \
            return nil; \
        } \
        __returnType m_result = m_imp(m_instance, m_sel APPEND_ARGS __callArgs); \
        return m_result; \
     } \
    
#define MakeCFunctionForMethod_Decl(__className, __returnType, __methodName, __args, __callArgs) \
    __returnType __className##_##__methodName(id m_instance APPEND_ARGS __args);


NS_ASSUME_NONNULL_END
