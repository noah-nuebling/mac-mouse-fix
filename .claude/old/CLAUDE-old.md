Code Style

    - Add Credits

        When writing new functions, add a comment indicating it was written by a Claude. 

        Example:

            ```python
            def my_function(): 
                # (By Claude)
            ```

            or

            ```python
            def my_function(): 
                """
                (By Claude)
                ...
                """
            ```

    - We have some nice shorthands when writing Objective-C code:
        auto -> __auto_type
        stringf(fmt, args) -> [NSString stringWithFormat: fmt, args]
        isclass(x, NSDictionary) -> [x isKindOfClass: [NSDictionary class]] 
        isclass(x, NSDictionary) -> [x isSubclassOfClass: [NSDictionary class]]

    - Always use documentation comments when writing Objective-C and Swift code. 
        Good: /// Hello there
        Bad: // Hi ho

        You can use `code blocks` and markdown inside the documentation comments to highlight variables and stuff like that.

        (This displays nicely inside Xcode)

    - Prefer to use scopes instead of splitting long functions up.
        
        Prefer adding scopes to break things down into steps instead of adding new Functions at the top-level, unless there's a good reason to.
            Good reasons to outline into a function:
                1. If you want to reuse the function's logic in multiple places.
                2. If the function performs a very fundamental operation that isn't closely tied to the problem at hand, such as componentsSeparatedByString:. If it's very unlikely that you'll have to think about the function internals while reading the call-site, it's ok to outline.
                3. Not much else.

        Examples:

            ```objc

                /// Step 1
                auto result1 = ...
                {
                    ...
                    auto intermediateValue = ...
                    result1 = doStuff(result1, intermedidateValue); /// The scoping makes it immediately obvious that the intermediate value is not used after step 1
                    ...
                }

                /// Step 2
                auto result2 = ...
                {
                    ...
                    result2 = ...
                    ...
                }
            ```
            
            In Python, use `if 1:` to create scopes
            ```python

                # Step 1
                result1 = None
                if 1: 
                    ...
                    result1 = ...
                    ...
                
                # Step 2
                result2 = []
                if 1:
                    ...
                    result 2 = ...
                    ...
            ```

            In Swift, use `do { ... }` for scoping.

            (In such simple examples, the scoping doesn't help very much, and you don't have to use it everywhere. But do use it for longer sub-steps inside functions.)
    
    - Break your code down into clear substeps, (as demonstrated above) that make it easy to understand the high-level logic later. But write compact code inside of those substeps. Prefer to avoid introducing variables for intermediate values if you can get away with 'inlining' those into longer expressions. Use linebreaks and indentation inside long expressions to make them easy to scan.
    
    - Date comments that may go out of date.

        Example:
            xyz += 1 # +1 instead of +2 is best choice due do current factors a, b, and c [Jan 2026]
    
    - Add references when there is relevant code (or other resources) that is far away:

        Example:
            def my_func():
                # Validate the repo paths
                #   We do the same thing in mflocales.py > localize_the_stuff()
                ...