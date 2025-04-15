//
//  MFObserver.h
//  objc-test-july-13-2024
//
//  Created by Noah Nübling on 30.07.24.
//

#import <Foundation/Foundation.h>

///
/// This file provides a simple block-based API for observing Key-Value-Observation-compliant objects.
/// We used to call it 'BlockObserver' but renamed to 'MFObserver' [Apr 2025]
/// It consists of 4 core methods: [Apr 2025]
///
///    Simple observation:
///         ```
///         MFObserver *buttonObserver = [button mf_observe:@"value" block:^void (NSString *newValue) {
///             otherValue = [newValue stringByAppendingString: @"Hello from KVO block!"];
///             self.something = value;
///         }];
///         ```
///
///    Cancel observation:
///         ```
///         [buttonObserver cancel];
///         ```
///
///    Observe latest:
///         ```
///         NSArray *observers = [MFObserver observeLatest2:@[@[button, @"value"], @[slider, @"doubleValue"]]
///                                                   block:^void (int updatedValueIndex, NSValue *v0, NSValue *v1)
///         {
///             int buttonValue = unboxNSValue(int, v0);
///             double sliderValue = unboxNSValue(int, v1);
///             ...
///         }];
///         ```
///
///     Cancel observeLatest:
///         ```
///         [MFObserver cancelObservers:observers];
///         ```
///
///     (API Notes:)
///         [Apr 2025] You can also ignore the `MFObserver *` return value and your callback block will still be called. (The `MFObserver *` will be retained by the observee)
///             (I believe this is different to Swift's KVO wrapper `mf_observe(_:options:changeHandler:)`, where the caller has to retain the return-value (I think))
///
/// API design discussion: `nullability`: [Apr 2025]
///     - We're trying to make an interface where: If the caller breaks nullability (by passing in nil to a `_Nonnull` arg), then the method/function may break nullability, too (by returning nil).
///         But as long as the caller 'adheres' to the declared nullability, the function's return value will also adhere to its declared nullability.
///         -> This way the interface should be *extremely* 'safe' both for
///             Swift                – it will import a valid, non-optional interface
///             Objective-C     – it will be allowed to pass nil into the interface and just get nil back – this is 'safer' in objc since there are no great compiler warnings for all situations where you try to pass in a nullable value to a `_Nonnull` function arg.
///     - Is this overengineered?
///         Yes absolutely. I'm treating this like I'm trying to design some production libary, while in reality, not even *I* am probably going to use this. Aghghghg. I've wasted so much time on this. I hope I learned something at least.
///
/// Caution: [Apr 2025]
///     To ensure correctness, users (me) need to pay special attention to
///         - thread-safety
///         - retain-cycles
///         - macOS-Version (Might be unsafe to use pre macOS 11 Big Sur)
///         -> More info about all these below and in the implementation.
///
/// @strongify/@weakify dance example: [Apr 2025]
///         To prevent retain cycles you must avoid strongly referencing the observed objects in the callback. Here's an example:
///         ```
///         @weakify(nsBox, nsButton)
///         NSArray *observers = [MFObserver observeLatest2:@[@[nsBox, @"borderColor"], @[nsButton, @"title"]]
///                                                   block:^(int updatedValueIndex, NSColor *newBorderColor, NSValue *newTitle)
///         {
///             @strongify(nsBox, nsButton)
///             nsButton.sound      = color_and_title_to_sound(newBorderColor, newTitle);
///             nsBox.borderRect    = color_and_title_to_position(newBorderColor, newTitle);
///         }];
///         ```

#pragma mark - local macros
#define avail   API_AVAILABLE(macos(10.13)) /** API might be unsafe pre-macOS 11. See notes for more. */
#define nullid  id _Nullable
#define nnullid id _Nonnull

#pragma mark - Typedef

/// Basic observation callbacks
avail typedef id MFObserver_CallbackBlock;
avail typedef void (^MFObserver_CallbackBlock_New)(nnullid newValue);
avail typedef void (^MFObserver_CallbackBlock_OldAndNew)(nullid oldValue, nnullid newValue);

/// Observe-latest callbacks
avail typedef id MFObserver_CallbackBlock_Latest;
avail typedef void (^MFObserver_CallbackBlock_Latest2)(int updatedValueIndex, nullid v0, nullid v1);
avail typedef void (^MFObserver_CallbackBlock_Latest3)(int updatedValueIndex, nullid v0, nullid v1, nullid v2);
avail typedef void (^MFObserver_CallbackBlock_Latest4)(int updatedValueIndex, nullid v0, nullid v1, nullid v2, nullid v3);
avail typedef void (^MFObserver_CallbackBlock_Latest5)(int updatedValueIndex, nullid v0, nullid v1, nullid v2, nullid v3, nullid v4);
avail typedef void (^MFObserver_CallbackBlock_Latest6)(int updatedValueIndex, nullid v0, nullid v1, nullid v2, nullid v3, nullid v4, nullid v5);
avail typedef void (^MFObserver_CallbackBlock_Latest7)(int updatedValueIndex, nullid v0, nullid v1, nullid v2, nullid v3, nullid v4, nullid v5, nullid v6);
avail typedef void (^MFObserver_CallbackBlock_Latest8)(int updatedValueIndex, nullid v0, nullid v1, nullid v2, nullid v3, nullid v4, nullid v5, nullid v6, nullid v7);
avail typedef void (^MFObserver_CallbackBlock_Latest9)(int updatedValueIndex, nullid v0, nullid v1, nullid v2, nullid v3, nullid v4, nullid v5, nullid v6, nullid v7, nullid v8);

#pragma mark - Main Interface

avail
@interface MFObserver : NSObject
@end

avail
@interface NSObject (MFObserverInterface)

    /// Basic observation
    ///     Note this when using:
    ///     - Caution: If the callbackBlock captures the observedObject or any other object which itself retains the observedObject, that will create a retain cycle!
    ///         (Use @strongify/@weakify dance to avoid this.)
    ///     - The returned MFObserver can be used to cancel the observation prematurely by calling `- cancel` on it.
    ///     - If you observe a primitive value such as int or float, it will arrrive in the callback boxed in an NSValue. Use the unboxNSValue() macro to conveniently get the underlying primitive inside the callback.
    - (MFObserver *_Nonnull)mf_observe:(NSString *_Nonnull)keyPath block:(MFObserver_CallbackBlock_New _Nonnull)callbackBlock;

    /// Basic observation with some extra options.
    /// The default options are:
    ///     - immediate: YES which means the callback will immediately fire upon creation with the current value of self.keyPath, instead of first firing on the first *change* of self.keyPath after you call this method.
    ///     - withOld: NO which means that, inside the callbackBlock, you only receive the updated value - not the previous values - of self.keyPath.
    ///         > Use MFObserver_CallbackBlock_OldAndNew as the callbackBlock's type if you set this option to YES.
    - (MFObserver *_Nonnull)mf_observe:(NSString *_Nonnull)keyPath immediate:(BOOL)receiveInitialValue withOld:(BOOL)receiveOldAndNewValues block:(MFObserver_CallbackBlock _Nonnull)callbackBlock;

@end

avail
@interface MFObserver (MFObserverInterface)

    /// Cancel observation
    - (void)cancel;
    + (void)cancelObservers:(NSArray<MFObserver *> *_Nonnull)observers;

    /// Introspection
    ///     [Apr 2025] Kinda not thread safe. Use for debugging. See implementation for more.
    - (BOOL)_isActive;

    /// Observe latest
    ///     Note this when using:
    ///     - Caution: If any of the observedObjects are retained inside the callbackBlock -> retain cycle!
    ///     - If one of the observed objects is deallocated during the observation, the latest value will appear as 'nil' in the subsequent callbacks triggered by any of the other objects updating, unless the value is retained elsewhere. (The observedObjects don't retain the latest values to help prevent reference cycles).
    ///     - The callbackBlock will be executed on the thread where the underlying value was changed, as soon as the value change happens. That means the callback might run on different threads concurrently. You can use `pthread`, `dispatch_async` `@synchronized()` or similar to handle concurrency inside the callback.
    ///     - The returned array of MFObservers can be used to cancel observation prematurely using `[MFObserver cancelObservers:arrayOfObservers]`.
    + (NSArray<MFObserver *> *_Nonnull)observeLatest2:(NSArray<NSArray *> *_Nonnull)objectsAndKeypaths block:(MFObserver_CallbackBlock_Latest2 _Nonnull)callbackBlock;
    + (NSArray<MFObserver *> *_Nonnull)observeLatest3:(NSArray<NSArray *> *_Nonnull)objectsAndKeypaths block:(MFObserver_CallbackBlock_Latest3 _Nonnull)callbackBlock;
    + (NSArray<MFObserver *> *_Nonnull)observeLatest4:(NSArray<NSArray *> *_Nonnull)objectsAndKeypaths block:(MFObserver_CallbackBlock_Latest4 _Nonnull)callbackBlock;
    + (NSArray<MFObserver *> *_Nonnull)observeLatest5:(NSArray<NSArray *> *_Nonnull)objectsAndKeypaths block:(MFObserver_CallbackBlock_Latest5 _Nonnull)callbackBlock;
    + (NSArray<MFObserver *> *_Nonnull)observeLatest6:(NSArray<NSArray *> *_Nonnull)objectsAndKeypaths block:(MFObserver_CallbackBlock_Latest6 _Nonnull)callbackBlock;
    + (NSArray<MFObserver *> *_Nonnull)observeLatest7:(NSArray<NSArray *> *_Nonnull)objectsAndKeypaths block:(MFObserver_CallbackBlock_Latest7 _Nonnull)callbackBlock;
    + (NSArray<MFObserver *> *_Nonnull)observeLatest8:(NSArray<NSArray *> *_Nonnull)objectsAndKeypaths block:(MFObserver_CallbackBlock_Latest8 _Nonnull)callbackBlock;
    + (NSArray<MFObserver *> *_Nonnull)observeLatest9:(NSArray<NSArray *> *_Nonnull)objectsAndKeypaths block:(MFObserver_CallbackBlock_Latest9 _Nonnull)callbackBlock;

@end

#pragma mark - Undef local macros

#undef avail
#undef nullid
#undef nnullid

#pragma mark - Convenience Macro

///
/// Unbox NSValue
///
///     TODO: Move this into SharedMacros.h or something.
///
/// Use like this:
///     `CGRect unboxed = unboxNSValue(CGRect, someNSValue)`
///
/// Use this inside `MFObserver_CallbackBlock`s - primitive values like int and float will be passed into the callback boxed in an NSValue.
///
/// Explanation:
///     The last expression is like the 'return value' in this weird ({}) c syntax

#define unboxNSValue(__unboxedType, __boxedValue)   \
({                                                  \
    assert(__boxedValue);                           /** Not sure how this behaves when you pass in nil */\
    __unboxedType unboxedValue;                     \
    [(id)__boxedValue getValue:&unboxedValue];      \
    unboxedValue;                                   \
})                                                  \
