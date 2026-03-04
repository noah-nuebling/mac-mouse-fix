//
// --------------------------------------------------------------------------
// SharedHelperMacros.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2026
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// Helper macros
///     To implement other macros

#define UNPACK(args...) args                /// This allows us to include `,` inside an argument to a macro (but the argument then needs to be wrapped inside `()` by the caller of the macro )
#define APPEND_ARGS(args...) , ## args      /// This is like UNPACK but it also automatically inserts a comma before the args. The ## deletes the comma, if `args` is empty. I have no idea why. But this lets us nicely append args to an existing list of arguments in a function call or function header.

#define TOSTR(x)    #x                      /// `#` operator but delayed – Sometimes necessary when order-of-operations matters
#define TOSTR_(x)   TOSTR(x)                /// `#` operator but delayed even more

#define _IFELSE_TRUE(iftrue, iffalse)                  UNPACK iftrue
#define _IFELSE_TRUE_JUST_KIDDING(iftrue, iffalse)     UNPACK iffalse

#define _IFEMPTY(iftrue, iffalse, ...)                 _IFELSE_TRUE ## __VA_OPT__(_JUST_KIDDING) (iftrue, iffalse)
#define IFEMPTY(condition, body...)                    _IFEMPTY((body), (),     condition)
#define IFEMPTY_NOT(condition, body...)                _IFEMPTY((),     (body), condition)

#define FOR_EACH(function, separator, functionargs...) \
    _FOR_EACH_SELECTOR(functionargs, _FOR_EACH_20, _FOR_EACH_19, _FOR_EACH_18, _FOR_EACH_17, _FOR_EACH_16, _FOR_EACH_15, _FOR_EACH_14, _FOR_EACH_13, _FOR_EACH_12, _FOR_EACH_11, _FOR_EACH_10, _FOR_EACH_9, _FOR_EACH_8, _FOR_EACH_7, _FOR_EACH_6, _FOR_EACH_5, _FOR_EACH_4, _FOR_EACH_3, _FOR_EACH_2, _FOR_EACH_1)(function, separator, functionargs)
    
#define _FOR_EACH_SELECTOR(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16, arg17, arg18, arg19, arg20, macroname, ...) macroname

#define _FOR_EACH_1(function, separator, functionarg)           function(functionarg)
#define _FOR_EACH_2(function, separator, functionarg, rest...)  function(functionarg) UNPACK separator _FOR_EACH_1(function, separator, rest)
#define _FOR_EACH_3(function, separator, functionarg, rest...)  function(functionarg) UNPACK separator _FOR_EACH_2(function, separator, rest)
#define _FOR_EACH_4(function, separator, functionarg, rest...)  function(functionarg) UNPACK separator _FOR_EACH_3(function, separator, rest)
#define _FOR_EACH_5(function, separator, functionarg, rest...)  function(functionarg) UNPACK separator _FOR_EACH_4(function, separator, rest)
#define _FOR_EACH_6(function, separator, functionarg, rest...)  function(functionarg) UNPACK separator _FOR_EACH_5(function, separator, rest)
#define _FOR_EACH_7(function, separator, functionarg, rest...)  function(functionarg) UNPACK separator _FOR_EACH_6(function, separator, rest)
#define _FOR_EACH_8(function, separator, functionarg, rest...)  function(functionarg) UNPACK separator _FOR_EACH_7(function, separator, rest)
#define _FOR_EACH_9(function, separator, functionarg, rest...)  function(functionarg) UNPACK separator _FOR_EACH_8(function, separator, rest)
#define _FOR_EACH_10(function, separator, functionarg, rest...) function(functionarg) UNPACK separator _FOR_EACH_9(function, separator, rest)
#define _FOR_EACH_11(function, separator, functionarg, rest...) function(functionarg) UNPACK separator _FOR_EACH_10(function, separator, rest)
#define _FOR_EACH_12(function, separator, functionarg, rest...) function(functionarg) UNPACK separator _FOR_EACH_11(function, separator, rest)
#define _FOR_EACH_13(function, separator, functionarg, rest...) function(functionarg) UNPACK separator _FOR_EACH_12(function, separator, rest)
#define _FOR_EACH_14(function, separator, functionarg, rest...) function(functionarg) UNPACK separator _FOR_EACH_13(function, separator, rest)
#define _FOR_EACH_15(function, separator, functionarg, rest...) function(functionarg) UNPACK separator _FOR_EACH_14(function, separator, rest)
#define _FOR_EACH_16(function, separator, functionarg, rest...) function(functionarg) UNPACK separator _FOR_EACH_15(function, separator, rest)
#define _FOR_EACH_17(function, separator, functionarg, rest...) function(functionarg) UNPACK separator _FOR_EACH_16(function, separator, rest)
#define _FOR_EACH_18(function, separator, functionarg, rest...) function(functionarg) UNPACK separator _FOR_EACH_17(function, separator, rest)
#define _FOR_EACH_19(function, separator, functionarg, rest...) function(functionarg) UNPACK separator _FOR_EACH_18(function, separator, rest)
#define _FOR_EACH_20(function, separator, functionarg, rest...) function(functionarg) UNPACK separator _FOR_EACH_19(function, separator, rest)

/// `_isobject()` – internal helper macro.
///     Check if an expression evaluates to an objc object.
#define _isobject(expression) __builtin_types_compatible_p(typeof(expression), id)

/// Branch-prediction hints
///     Explanation and example: https://stackoverflow.com/a/133555/10601702
#define mflikely(b)    (long)__builtin_expect(!!(b), 1)
#define mfunlikely(b)  (long)__builtin_expect(!!(b), 0)
