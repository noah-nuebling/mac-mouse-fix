//
//  MFOnce.h
//  objc-tests-nov-2024
//
//  Created by Noah Nübling on 05.02.25.
//

/// mfonce
///     boilerplate- and block-free replacement for `dispatch_once`.
///     `dispatch_once()` is more than good enough though, and this implementation is super complicated
///     -> Don't use this.
///
///     (Usage examples in MFOnceMacro.m)

#if 0 /// Use `dispatch_once() instead`
        
/// Helper macros
///     These are found in a documented form inside EventLoggerForBrad which we'll eventually merge into MMF.
#define scopedstatement_start(statement)                                    \
    for (                                                                   \
        int __scopedstatement_oncetoken = 0;                                \
        __scopedstatement_oncetoken == 0 ? ({ statement; true; }) : false;  \
        __scopedstatement_oncetoken = 1                                     \
    )

#define scopedstatement_end(statement)                                 \
    for (                                                           \
        int __scopedstatement_oncetoken = 0;                           \
        __scopedstatement_oncetoken == 0;                              \
        ({ statement; __scopedstatement_oncetoken = 1; })              \
    )

#define scopedvar(declaration)                                                                  \
    for (int __scopedvar_oncetoken = 0; __scopedvar_oncetoken == 0;)                            \
    for (declaration;                   __scopedvar_oncetoken == 0; __scopedvar_oncetoken = 1)

#define __deferred_concat(a, b) a##b
#define _deferred_concat(a, b) __deferred_concat(a, b)

#define __deferred_concat3(a, b, c) a##b##c
#define _deferred_concat3(a, b, c) __deferred_concat3(a, b, c)

#define _unique(identifier)     _deferred_concat3(identifier, _on_line_, __LINE__)

/// mfonce

#define mfonce                                                      \
    static int _unique(__mfonce_didrun) = 0;                        \
    id __unsafe_unretained _unique(__mfonce_mutexkey) =             \
        (__bridge id)(void *)&_unique(__mfonce_didrun);             /** This works because 1. The static var always has the same address || 2. objc_sync_enter() expects an object, but only uses its address || Alternative: We could also create NSNumber here. It seem that all NSNumbers with the same value have the same address. */\
    if (__builtin_expect(_unique(__mfonce_didrun), ~0) == ~0)       /** dispatch_once() uses `~0l` as a flag. Not sure why not just 1?  It would sorta make sense if they are assuming that writing to didrun is not atomic? But I heard setting integers is atomic on ARM. */ \
    {                                                               \
        dispatch_compiler_barrier();                                /** Prevent compiler optimizer from reading data that is initialized by the user's block before we enter this if statement. That should allow this to be thread safe without using locks. Confusing but makes sense when you think about it. _dispatch_once() also does this. */\
        __builtin_assume(_unique(__mfonce_didrun) == ~0);           /** Optimization. _dispatch_once() also does this. Perhaps this 'restores' some knowledge of the compiler after dispatch_compiler_barrier() destroys it? */\
    }                                                               \
    else                                                            \
        scopedstatement_start(({                                \
            objc_sync_enter(_unique(__mfonce_mutexkey));        /** Lock mutex */\
        }))                                                     \
            scopedstatement_end(({                                      \
                dispatch_compiler_barrier();                            /** This barrier makes sure didrun is only set *after* the user's block has fully run – even with compiler optimizations turned on. (I think.)*/\
                _unique(__mfonce_didrun) = ~0;                          /** Set didrun */\
                objc_sync_exit(_unique(__mfonce_mutexkey));             /** Unlock mutex */\
                __builtin_assume(_unique(__mfonce_didrun) == ~0);       /** Optimization. Not sure this is necessary. */\
            }))                                                         \
                if (_unique(__mfonce_didrun) != ~0)                 /** Only run user's block if didrun is still not set after acquiring the lock. */\

#endif
