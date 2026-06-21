# Xcode Nullability Settings

([Apr 2025] You can use the information here to **enable nullability warnings** in Xcode.)

Goal of this investigation [Apr 2025]
    We wanna make MFObserver.m null-safe for Swift
    Usually, for objc code we just write `if (!arg) return nil;` if we don't wanna handle nil-args. But this would lead to everything being optional in Swift which is not what you want I guess.
    Therefore, in the objc code, we wanna ensure that functions/methods that have a `_Nonnull` return value never return nil – unless you pass nil to a`_Nonnull` arg - that will make things safe and non-optional for Swift, while still being safe when objc passes nil. 
    But this is not super trivial, so we wanted to know what help we can get from the compiler to enforce `_Nonnull` inside objc code.

---

[Apr 2025] I just looked through Apple's Xcode build-settings reference,
    and there are 7 build settings regarding null pointers:

- CLANG_UNDEFINED_BEHAVIOR_SANITIZER_NULLABILITY   (Title: Enable Nullability Annotation Checks)
    Check for violations of nullability annotations
    in function calls, return statements, and
    assignments.
- CLANG_WARN_NON_LITERAL_NULL_CONVERSION           (Title: Implicit Non-Literal Null Conversions)
    Warn about non-literal expressions that
    evaluate to zero being treated as a null
    pointer.
- CLANG_ANALYZER_NONNULL                           (Title: Misuse of 'nonnull')
    Check for misuses of nonnull parameter and
    return types.
- CLANG_ANALYZER_NULL_DEREFERENCE                  (Title: Dereference of Null Pointers)
    Check for dereferences of null pointers.
- CLANG_WARN_NULLABLE_TO_NONNULL_CONVERSION        (Title: Incorrect Uses of Nullable Values)
    Warns when a nullable expression is used
    somewhere it's not allowed, such as when
    passed as a _Nonnull parameter.

- CLANG_ANALYZER_OBJC_ATSYNC                        (Title: @synchronized with nil mutex)
    Warn on nil pointers used as mutexes for 
    @synchronized.
- CLANG_WARN_OBJC_REPEATED_USE_OF_WEAK              (Title: Repeatedly using a `__weak` reference)
    Warn about repeatedly using a weak reference 
    without assigning the weak reference to a 
    strong reference. This is often symptomatic of 
    a race condition where the weak reference can 
    become nil between accesses, resulting in 
    unexpected behavior. Assigning to temporary 
    strong reference ensures the object stays 
    alive during the related accesses.

Notes:
- CLANG_WARN_NULLABLE_TO_NONNULL_CONVERSION seems very useful.
    Info: 
        - Corresponds to clang flag `-Wnullable-to-nonnull-conversion` 
        - It is a _secret setting_ -> It doesn't show up by default, instead you have to add it yourself as a `User-Defined` build setting.
    What we found it does:
        - Warns when pass a nullable expression 
            to a `_Nonnull` function argument.                              (Very useful if you wanna make things safe for Swift interop)
        - Warns when you return a nullable expression 
            from a function with a `_Nonnull` return type.
        - Does not warn when you pass *literal nil* 
            to a `_Nonnull` *function argument*. 
        - Does not warn when you return *literal nil* 
            from a function with a `_Nonnull` return type.

## Clang flags

I could find further "clang diagnostic flags" regarding nullability:

- -Wnullability
- -Wnullability-completeness
- -Wnullability-completeness-on-arrays
- -Wnullability-declspec
- -Wnullability-extension
- -Wnullability-inferred-on-nested-type
    (Haven't looked into these)
    (There's also more that I haven't listed here)

- -Wnonnull
    - Doesn't seem to have an Xcode build setting equivalent
    - Is enabled by default
    - We found it does:
        - Warns when you pass *literal nil* 
            to a `_Nonnull` *function argument*.                (This is useful, and something that `-Wnullable-to-nonnull-conversion` doesn't do)
        - Does not warn when you return *literal nil* 
            from a function with a `_Nonnull` return type.      (This is a major limitation, but we found one hacky workaround by redefining nil – See src [2])

## How we can use this

Using the `-Wnullable-to-nonnull-conversion` flag, plus the workaround from [2], we should be able to get a compiler warning whenever we violate nullability 
    while passing something into or returning something out of a function.
    -> That is exactly what we want to help us make our APIs safe for Swift and objc.
    
Caveats:   
    - You can still set local vars of unspecified nullability to nil and return them from a `_Nonnull` function without a warning.
    - `NS_ASSUME_NONNULL` doesn't seem to work. The `-Wnullable-to-nonnull-conversion` warnings don't show up unless you explicitly use `_Nonnull`.
    - ... Can't think of anything else, (But also have barely used this, yet)

Tips:
    - If the nullability warnings ever get annoying, you can turn the off just like all typesystem warnings – by casting to `(id)`
    - Not sure but I think:
        - For local vars, we only need to specify `_Nullable`
        - For function signatures we only need to specify `_Nonnull`
        -> Cause the thing we wanna get warned about is if we pass null/nullable into/out-of a function where the rest of the program doesn't expect nil.
        -> ... Not sure this makes sense.
---

Sources/Also see:

- [1] SO Post about CLANG_WARN_NULLABLE_TO_NONNULL_CONVERSION: https://stackoverflow.com/questions/40990741/clang-warn-nullable-to-nonnull-conversion-removed/40991122#comment140332721_40991122
- [2] GH Issue about -Wnonnull bugs and workarounds: https://github.com/llvm/llvm-project/issues/83606#issuecomment-2801874614
- [3] llvm issues for "-Wnonnull": https://github.com/llvm/llvm-project/issues?q=is%3Aissue%20state%3Aopen%20-Wnonnull
- [4] clang diagnostic flags: https://clang.llvm.org/docs/DiagnosticsReference.html

---

Workaround from [2]:

In case that GitHub comments gets deleted or something here's a summary of the workaround:
    - You add `"-Dnil=((id\ _Nullable)__DARWIN_NULL)"` to the `OTHER_CFLAGS` Xcode build-setting.
    -> This redefines literal nil to have type `(id _Nullable)`, which causes the `-Wnullable-to-nonnull-conversion` warnings to apply to literal nil.
    Update: [Apr 15 2024] to make warnings appear for literal `NULL` as well I added `"-DNULL=((void *\ _Nullable)0)"`
        - I'm not sure if redefining nil and NULL this way is totally safe, but it seem to work so far.
        - ... I also don't know if redefining NULL like this even makes a difference (maybe the bug only applies to `nil`) Haven't tested at all [Apr 15 2025]
    
---

Sidenote:
- You can make Xcode show build-setting _names_ (instead of titles) at: `Editor > Show Setting Names`
