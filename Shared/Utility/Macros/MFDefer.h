//
// --------------------------------------------------------------------------
// MFDefer.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// This emulates Swift's `defer` feature in Objective-C.
///     I don't like Swift but that's a good feature.
///
/// Usage example:
///
///     ```
///     {
///         printf("First\n");
///         MFDefer ^{ printf("Deferred 1\n"); };
///         printf("Middle\n");
///         MFDefer ^{ printf("Deferred 2\n"); };
///         printf("Last\n");
///     }
///     ```
///     Output:
///         First
///         Middle
///         Last
///         Deferred 2
///         Deferred 1
///
/// Also see:
///     - https://thephd.dev/_vendor/future_cxx/papers/C%20-%20Improved%20__attribute__%28%28cleanup%29%29%20Through%20defer.html
///         -> thephd 2023 proposal about adding defer to C (very detailed and interesting)
///     - https://social.belkadan.com/@jrose/statuses/01HGKXQQAM9H4DSZ4S9FCV6P4C
///         -> Belkadan post by @jrose
///     - https://nshipster.com/new-years-2016/#swifts-defer-in-objective-c
///         ->  Nolan O’Brien's implementation
///     - https://openradar.appspot.com/21684961
///         - Nolan O'Brien's open radar request to add @defer to Objective-C
///
/// Will MFDefer still be invoked when an exception is thrown?
///     -> I haven't tested (as of Nov 2024) but I think so. The GCC docs seem to suggest that `__attribute__((cleanup(...))` will be invoked during the 'stack unwinding' that happens when an exception is thrown.
///     -> Src: https://gcc.gnu.org/onlinedocs/gcc-11.1.0/gcc/Common-Variable-Attributes.html#index-cleanup-variable-attribute
///
/// We could have made the MFDefer macro look like really cool objc @keyword
///         like this: `@defer { ... };` instead of `MFDefer ^{ ... };`
///     -> we could've done that by using the technique that is used for the `@strongify` `@weakify` macros.
///


#ifndef MFDefer_h
#define MFDefer_h

/// Helper macros

#define __delayed_macro_concat(a, b) a##b
#define _delayed_macro_concat(a, b) __delayed_macro_concat(a, b)

/// Helper function

NS_INLINE void _MFDefer_deferred_block_executor(void (^*deferred_block)(void)) {
    (*deferred_block)();
}

/// Main macro

#define MFDefer \
    __attribute__((cleanup(_MFDefer_deferred_block_executor), unused)) \
    void (^_delayed_macro_concat(_MFDefer_deferred_block_on_line_, __LINE__))(void) = 


#endif /* MFDefer_h */
