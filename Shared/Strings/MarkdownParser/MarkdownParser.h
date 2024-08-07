//
// --------------------------------------------------------------------------
// MarkdownParser.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MarkdownParser : NSObject

/// CAUTION:
///     The parser does not strip out any unsafe HTML tags from the input.
///     > Make sure to `sanitize` any untrusted content before using it in an `unsafe context`.
///         Explanation:  An `unsafe context` is an HTML parser, especially if it allows JavaScript or is not sandboxed (WKWebView doesn't allow js by default and is sandboxed.)
///         Explanation:  `sanitizing` content means to remove any unsafe HTML tags like `<script>`.

+ (NSAttributedString *)attributedStringWithMarkdown:(NSString *)markdown;
+ (NSAttributedString *)attributedStringWithAttributedMarkdown:(NSAttributedString *)attributedMarkdown;

@end

NS_ASSUME_NONNULL_END
