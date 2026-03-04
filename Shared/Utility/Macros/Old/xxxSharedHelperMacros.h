//
// --------------------------------------------------------------------------
// xxxSharedHelperMacros.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2026
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// Helper macros:`_scopeins_var` / `_scopeins_statement_start` / `_scopeins_statement_end`
/// What:   Insert a variable declaration or statement into the scope following the macro
/// Why:    Useful for implementing other macros – The macro can be used as a 'header' for a scope and insert useful variables or statements into it.
///         -> The real benefit of this is that the scope, which effectively acts like an argument to the macro, is *outside* the macro. And scopes outside a macro have much better debugging support. (Setting breakpoints inside a macro argument doesn't work in Xcode [Feb 2025])
/// How:    The macros use for-loop(s). Little hacky. Alternatives: In CPP there's `If Statement with Initializer`, but afaik, in C, this is the only way to insert a declaration into a scope from outside the scope.
///
/// Caution: Using`break` or `continue` inside a `_scopeins_...()` macro's scope will simply break out of that scope. It won't interact with any enclosing loops (since the `_scopeins_...()` macros use for-loops under-the-hood)
///         > `break` and `continue` also won't work for **any macros that use _scopeins_...() macros** – Don't forget this!
///
/// Update: [Mar 2026] This is a relatively basic macro technique that I don't really have a practical use for atm. Doesn't make sense to lug this abstraction around. Just write this pattern on the fly when you need it (which should be rarely)
///
/// Examples:
///
///     1. Insert var – into a scope without braces.
///         `_scopeins_var(int x = 5) printf("%d", x);  // Despite the lack of braces, this is a scope. x only exists for this printf`
///
///     2. Insert var – into a scope with { braces }
///         ```
///         _scopeins_var(NSMutableString *str = [NSMutableString string]) // str only exists inside { ... }
///         {
///             [str appendString:@"Hello"];
///             [str appendString:@" World"];
///             NSLog(@"%@", str);
///         }
///     3. Insert statements - at the start and end of a scope
///         ```
///         _scopeins_statement_start(pthread_mutex_lock(&mutex))
///             _scopeins_statement_end(pthread_mutex_unlock(&mutex))
///                 {
///                     // (mutex is locked here)
///                     shared_state++;
///                     // (mutex is unlocked here)
///                 }
///         ```
///     4. Insert multiple statements using ({ statement-expressions })
///         ```
///             _scopeins_var(FILE* f = fopen("test.txt", "r"))
///                 _scopeins_statement_start(printf("file %p was opened\n", f))
///                     _scopeins_statement_end( ({ fclose(f); printf("file %p was closed\n", f); }) ) // Insert an fclose and a printf statement at the end of the scope.
///                         {
///                             // File operations here
///                             char buf[100];
///                             fgets(buf, sizeof(buf), f);
///                             ...
///                         }
///         ```

/// Variable inserter
    
#define _scopeins_var(declaration...)                                                                   /** vararg... so the declaration may contain commas without being interpreted as multiple macro args */\
    for (int __scopeins_oncetoken = 0;     __scopeins_oncetoken == 0;)                                \
    for (declaration;                      __scopeins_oncetoken == 0; __scopeins_oncetoken = 1)      \

/// Statement inserters

#define _scopeins_statement_start(statement...)                         \
    for (                                                               \
        int __scopeins_oncetoken = 0;                                   \
        __scopeins_oncetoken == 0 ? ({ statement; true; }) : false;     \
        __scopeins_oncetoken = 1                                        \
    )

#define _scopeins_statement_end(statement...)                           \
    for (                                                               \
        int __scopeins_oncetoken = 0;                                   \
        __scopeins_oncetoken == 0;                                      \
        ({ statement; __scopeins_oncetoken = 1; })                      \
    )

/// Other
#define scoped_preprocess(statements...) /** Untested. Not well thought-through. Don't use this. Could perhaps be useful for validation or compile-time-checks of a _scopeins_var(). Since this is an if statement, the macro args could also easily prevent the scope from being executed entirely. */\
    if (({ statements }))
