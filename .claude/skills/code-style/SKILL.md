---
name: code-style
description: Code structure and style preferences. Use when writing or modifying code - prefer inline logic over outlined functions.
---

# Code Style Preferences

## Prefer Inline Code Over Outlined Functions

There is a strong preference for keeping logic **inlined** rather than breaking it into separate top-level functions. Only outline code when there is a clear, compelling reason.

### Valid Reasons to Outline

1. **Code reuse** - The function is genuinely called from multiple places
2. **Fundamental abstractions** - The function is so well-understood that you never need to think about its internals when reading the callsite (e.g., `sort()`, `fetch_url()`)

The key test: *If you have to think about what's inside the function while reading the callsite, it should probably be inlined.*

### Costs of Unnecessary Outlining

- **Over-engineering**: Tendency to add documentation and handle edge cases for a "general" problem that only exists in one place
- **Navigation overhead**: More top-level functions makes it harder to orient yourself and understand what's important
- **Mental overhead**: Jumping in and out of functions and tracking how values are renamed as they're passed around

### Use Scoped Blocks Instead

Instead of outlining, create a nested scope within the parent function with a comment describing the substep:

**Swift:** Use `do { }` blocks
**C/C++:** Use `{ }` blocks
**Python:** Use `if 1:` (the most concise way to open a nested scope in Python)

### Pattern for Scoped Blocks

1. Add a comment describing the substep
2. Initialize any "result" variables *before* opening the scope
3. Do the work inside the scope
4. Assign results to the pre-initialized variables

### Example

**Bad** - Unnecessary outlining:
```python
def get_processed_data(items):
    transformed = [parse(x) for x in items]
    filtered = [x for x in transformed if x.is_valid]
    return filtered

def f(...):
    ...
    data = get_processed_data(items)
    ...
```

**Good** - Inlined with scoped block:
```python
def f(...):
    ...

    # Process data
    data = None
    if 1:
        transformed = [parse(x) for x in items]
        filtered = [x for x in transformed if x.is_valid]
        data = filtered

    ...
```

---

## Prefer Concise Expressions Over Intermediate Variables

Within each step, keep the actual data transformation logic **concise**. Avoid unnecessary intermediate variables - instead, write longer expressions that can be read "inside out" to understand the full transformation.

The goal: High-level structure is visible through **commented steps**, while the actual logic within each step is **dense and readable**.

### Why Avoid Intermediate Variables?

- **Mental overhead**: Each variable is a name you have to hold in your head and track back to its definition
- **Similar to outlining functions**: Instead of jumping to another location in the file, you're jumping up a few lines to find "what was `x` again?"
- **Obscures the transformation**: When logic is spread across many variables, it's harder to see the full picture of how input becomes output

### Use Formatting to Keep Long Expressions Readable

Instead of breaking expressions into intermediate variables, use **indentation, line breaks, and alignment** to keep them readable. You get the benefits of named intermediates (clarity, structure) with none of the downsides (mental overhead, indirection).

```c
if (
    (a || b || c || d) &&   // User is authorized
    (w || x || y || z)      // Resource is available
) {
    ...
}
```

### Example

**Bad** - Too many intermediate variables:
```python
# Process data
data = None
if 1:
    transformed = [parse(x) for x in items]
    filtered = [x for x in transformed if x.is_valid]
    data = filtered
```

**Good** - Concise expression:
```python
# Process data
data = [x for x in [parse(x) for x in items] if x.is_valid]
```

**Python-specific concession** - In languages like C, you'd use inline comments and line breaks instead, but Python doesn't support comments inside expressions, so an intermediate variable can be acceptable if it adds clarity:

```python
# Process data
parsed = [parse(x) for x in items]
data = [x for x in parsed if x.is_valid]
```

### Another Example: Nested Data Traversal

When traversing nested structures (JSON, dicts, etc.), keep the full path in a single expression rather than creating intermediate variables for each level.

**Bad** - Intermediate variables for each level:
```python
strings = xcstrings_obj["strings"]
key_data = strings[key]
localizations = key_data["localizations"]
locale_data = localizations[locale]
string_unit = locale_data["stringUnit"]
```

**Good** - Single expression with full path:
```python
string_unit = mfkeypath(xcstrings_obj, f"strings/{key}/localizations/{locale}/stringUnit")
```

The single expression is self-contained - you see exactly where `string_unit` comes from without tracing back through 5 variable definitions.

---

## Prefer Single Codepaths Over Defensive Checks

Design code that naturally handles edge cases in one codepath, rather than scattering `if` checks everywhere.

### Why prefer single codepaths?

Your code becomes shorter and simpler, which makes it less error prone, and easier to understand.

### Example: Nested Data Access

**Bad** - Defensive checks at every level:
```python
string_unit = None
if "strings" in xcstrings_obj:
    strings = xcstrings_obj["strings"]
    if key in strings:
        key_data = strings[key]
        if "localizations" in key_data:
            localizations = key_data["localizations"]
            if locale in localizations:
                locale_data = localizations[locale]
                if "stringUnit" in locale_data:
                    string_unit = locale_data["stringUnit"]
```

**Good** - API designed to handle missing paths gracefully:
```python
string_unit = mfkeypath(xcstrings_obj, f"strings/{key}/localizations/{locale}/stringUnit")
# Returns {} if path doesn't exist - no checks needed
```

The `mfkeypath` helper returns an empty dict for missing paths, allowing the code to continue without explicit null checks. Look for similar patterns: APIs that return sensible defaults, operations that are no-ops on empty inputs, etc.

### Use Asserts Instead of "Just In Case" Checks

When you're unsure about an assumption, don't write defensive code to handle cases that shouldn't happen. Instead, use an `assert` to document the assumption and move on.

**Bad** - Defensive handling for cases that shouldn't occur:
```python
def process_item(item):
    if item is None:
        return None  # Just in case?
    if not hasattr(item, 'value'):
        return None  # What if it doesn't have value?
    ...
```

**Good** - Assert assumptions and proceed:
```python
def process_item(item):
    assert item is not None
    assert hasattr(item, 'value')
    ...
```

Asserts are documentation that will loudly fail if your assumptions are wrong - much better than silently returning `None` and causing confusing behavior downstream.

---

## Python Scripts: Use Shared Utilities

When working on Python scripts in this project, check `mac-mouse-fix-scripts/shared/` for established utilities before writing your own. Examples:

- `runclt()` instead of `subprocess`
- `mfkeypath()` for traversing nested dicts

---

## Don't Add Complexity to Satisfy Linters

If a linter or type checker complains but the code is correct and clear, ignore the warning. Don't:

- Add type hints just to satisfy the type checker
- Add docstrings just because a linter wants them
- Restructure working code to avoid a lint warning

Linter warnings are suggestions, not requirements. Simple, working code is more important than a clean lint output.

