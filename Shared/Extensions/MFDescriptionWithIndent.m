//
// --------------------------------------------------------------------------
// MFDescriptionWithIndent.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2026
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// Goal: Describe Foundation collections with proper indentation.
///     (The SwitchMaster's logs were hard to read otherwise [Oct 2026])
/// Consideration: Should we swizzle `-description` / `descriptionWithLocale:indent:` to map to this? [Oct 2026]

#import "MFDescriptionWithIndent.h"

#define range(i, n) (int i = 0; i < (n); i++)

@implementation NSObject (MFDescriptionWithIndent)


    #define kIndentFirstLine 0

    static NSString *_stringByRepeatingChar(unichar c, int n) {
        unichar buf[n];
        for range(i, n) buf[i] = c;
        return [NSString stringWithCharacters: buf length: n];
    }
    - (NSString *) mf_descriptionWithIndent: (int)indent {

        /// Validate input
        if (indent < 0) indent = 0;

        /// Use native Cocoa, if possible
        if ([self respondsToSelector: @selector(descriptionWithLocale:indent:)])
            return [(id)self descriptionWithLocale: nil indent: (NSUInteger)indent/4];

        /// Fallback: Use `-description` and manually add indentation
        ///     This might be pretty slow. [Oct 2026]
        {
            NSString *description = [self description];

            /// Fastpath
            if (!indent) return description;
            bool hasLineBreaks = [description containsString: @"\n"];
            if (!kIndentFirstLine && !hasLineBreaks) return description;

            NSMutableString *result = [description mutableCopy];

            NSString *prefix = _stringByRepeatingChar(' ', indent);
            if (hasLineBreaks)
            [result replaceOccurrencesOfString: @"\n"
                    withString: [@"\n" stringByAppendingString: prefix]
                    options: NSLiteralSearch
                    range: NSMakeRange(0, result.length)];

            if (kIndentFirstLine) [result insertString: prefix atIndex: 0];

            return result;
        }
    }
@end

@implementation NSArray (MFDescriptionWithIndent)

    - (NSString *) mf_descriptionWithIndent: (int)indent {

        /// Validate input
        if (indent < 0) indent = 0;

        /// Declare result
        NSMutableString *result = [NSMutableString new];

        /// Indent first line
        NSString *prefix = _stringByRepeatingChar(' ', indent);
        if (kIndentFirstLine) [result appendString: prefix];

        /// Print empty on one line
        if (!self.count) { [result appendString: @"()"]; return result; }

        /// Print non-empty collection
        [result appendString: @"(\n"];
        for (id obj in self) {
            if (!kIndentFirstLine) { [result appendString: prefix]; [result appendString: @"    "]; } /// If the element descriptions doen't indent the first line, we have to do it here [Oct 2026]
            [result appendString: [obj mf_descriptionWithIndent: indent + 4]];
            [result appendString: @",\n"]; /// We're avoiding `appendFormat:` in case it's slower. Didn't test if worth it. [Oct 2026]
        }
        [result appendString: prefix]; [result appendString: @")"];

        return result;
    }

@end

@implementation NSDictionary (MFDescriptionWithIndent)

    - (NSString *) mf_descriptionWithIndent: (int)indent {

        /// Validate input
        if (indent < 0) indent = 0;

        /// Declare result
        NSMutableString *result = [NSMutableString new];

        /// Indent first line
        NSString *prefix = _stringByRepeatingChar(' ', indent);
        if (kIndentFirstLine) [result appendString: prefix];;

        /// Print empty on one line
        if (!self.count) { [result appendString: @"{}"]; return result; };

        /// Print non-empty collection
        [result appendString: @"{\n"];
        for (id key in self) {
            if (!kIndentFirstLine) { [result appendString: prefix]; [result appendString: @"    "]; }
            [result appendString: [key mf_descriptionWithIndent: indent + 4]];
            [result appendString: @" = "];
            if (kIndentFirstLine) [result appendString: @"\n"];
            [result appendString: [[self objectForKey: key] mf_descriptionWithIndent: indent + 4]];
            [result appendString: @";\n"];
        }
        [result appendString: prefix]; [result appendString: @"}"];

        return result;
    }

@end
