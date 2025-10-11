//
// --------------------------------------------------------------------------
// MarkdownParser.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "MarkdownParser.h"
#import "AppDelegate.h"
#import <AppKit/AppKit.h>
#import "cmark.h"
#import "SharedUtility.h"
#import "NSString+Additions.h"
#import "NSAttributedString+Additions.h"
#import "ListOperations.h"

/**
 
    Notes:
        - Markdown parsing bug when using `NSString+Steganography.m` [Oct 2025]
            - The zero-width unicode characters we're using in `NSString+Steganography.m` trigger a bug where the parsing of **emphasis** doesn't work when the content of the emphasis begins with a single quote (`'`)
                - Minimal repro:
                    ```
                    [MarkdownParser attributedStringWithCoolMarkdown: @""
                        "Titletitletitle title title title\n"
                        ""          "**'asdfsaf'** noononono\n"   /// Works
                        " "         "**'asdfsaf'** noononono\n"   /// Works
                        "\u200B"    "**'asdfsaf'** noononono\n"   /// Doesn't work
                        "\u2060"    "**'asdfsaf'** noononono\n"   /// Doesn't work
                        "\u200C"    "**'asdfsaf'** noononono\n"   /// Doesn't work
                        "\u200D"    "**'asdfsaf'** noononono\n"   /// Doesn't work
                        "\u2062"    "**'asdfsaf'** noononono\n"   /// Doesn't work
                        "\u2063"    "**'asdfsaf'** noononono\n"   /// Doesn't work
                        "\u2063"    "**"asdfsaf"** noononono\n"   /// Doesn't work (Using double quotes)
                        "\u2063"    "**asdfsaf** noononono\n"     /// Works        (Using no quotes)
                    ];
                    ```
                -  Reproduction environment: We're using some weird commit of the the markdown library on the CJK branch or some stuff. Wrote more about this elsewhere. [Oct 2025]
                - Impact: This currently affects the `license-toast.unknown-key` UI string. [Oct 2025]
*/

@implementation MarkdownParser

+ (NSAttributedString *_Nullable) attributedStringWithCoolAttributedMarkdown: (NSAttributedString *)md fillOutBase: (BOOL)fillOutBase styleOverrides: (MDStyleOverrides *_Nullable)styleOverrides {
    
    NSAttributedString *result = nil;
    
    if ((NO)) {
        
        /// Never use Apple API, always use custom method - so things are consistent across versions and we can catch issues witht custom version during development
        //
        //        /// Use library function
        //
        //        /// Create options object
        //        NSAttributedStringMarkdownParsingOptions *options = [[NSAttributedStringMarkdownParsingOptions alloc] init];
        //
        //        /// No idea what these do
        //        options.allowsExtendedAttributes = NO;
        //        options.appliesSourcePositionAttributes = NO;
        //
        //        /// Make it respect linebreaks
        //        options.interpretedSyntax = NSAttributedStringMarkdownInterpretedSyntaxInlineOnlyPreservingWhitespace;
        //
        //        /// Create string
        //        result = [[NSAttributedString alloc] initWithMarkdownString:md options:options baseURL:[NSURL URLWithString:@""] error:nil];
        
    } else {
        
        /// Fallback to custom function
        result = attributedStringWithMarkdown(md, true, styleOverrides);
    }
    
    if (fillOutBase) {
        result = [result attributedStringByFillingOutBase];
    }
    
    return result;
}

+ (NSAttributedString *_Nullable) attributedStringWithCoolAttributedMarkdown: (NSAttributedString *)md {
    return [self attributedStringWithCoolAttributedMarkdown: md fillOutBase: NO styleOverrides: nil];
}

+ (NSAttributedString *_Nullable) attributedStringWithCoolMarkdown: (NSString *)md fillOutBase: (BOOL)fillOutBase {
    return [self attributedStringWithCoolAttributedMarkdown: [md attributed] fillOutBase: fillOutBase styleOverrides: nil];
}

+ (NSAttributedString *_Nullable) attributedStringWithCoolMarkdown: (NSString *)md {
    return [self attributedStringWithCoolMarkdown: md fillOutBase: YES];
}

static NSAttributedString *attributedStringWithMarkdown(NSAttributedString *src, Boolean keepExistingAttributes, MDStyleOverrides *_Nullable styleOverrides) {
    
    /// Irrelevant sidenote:
    /// - I started writing this using c-style variable names with lots of 'mnemonic' abbreviations and underscores - since that's what the cmark libary uses and I thought it was interesting to try.
    ///     But then we ended up also using lots of Cocoa APIs and all the naming got mixed up.
    
    /// Declare cmark parsing options
    ///
    /// Why use UNSAFE option?
    ///     - UNSAFE makes the md parser parse raw html, e.g. a `strong` tag for emphasis which works more reliably than `**` or `__` in some edge cases.
    ///     - This can be unsafe if there is a string from a strange, potentially malicious user, containing html tags, passing through the md parser, then still containing html tags, and then being parsed by another html parser
    ///         which might be hacked by the html in the string.
    ///         It gets really unsafe if that html parser allows javascript and is not sandboxed.
    ///     > In MMF, at the time of writing, we don't have such scenarios. The app doesn't load user generated strings from other users. The only strings are generated by me, translators, or the user themselves.
    ///         If we ever parse strings from untrusted sources with cmark, it's still unlikely that this would cause damage, since the only other place we'd be parsing HTML in the app aside from the md parser is a
    ///         WKWebView which is sandboxed and has JavaScript disabled by default.
    ///     > To mitigate any security risks, we could sanitize the output (strip out unsafe html tags) or turn off `CMARK_OPT_UNSAFE` altogether before passing the output from the MarkdownParser to an HTML parser.
    ///     -> But on second thought, I think the responsibility to sanitize untrusted content should not be with the markdown parser, especially since untrusted content doesn't necessarily pass through the markdown parser before ending up in an unsafe context.
    
    int md_options = CMARK_OPT_HARDBREAKS |     /// Turn softbreaks into hardbreaks. Not sure this works?
                     CMARK_OPT_UNSAFE;       /// Turn on support for inline html.
    
    /// Get markdown node iterator
    const char *md = [src.string cStringUsingEncoding:NSUTF8StringEncoding];
    cmark_node *root = cmark_parse_document(md, strlen(md), md_options);
    cmark_iter *iter = cmark_iter_new(root);
    
    ///  Create stack
    ///     Array of dicts that stores state of the nodes we're currently inside of as we're walking the tree.
    NSMutableArray<NSNumber *> *stack = [NSMutableArray array];
    
    /// Create/init search range for src string
    NSRange src_search_range = NSMakeRange(0, src.length);
    
    /// Create counter for md lists
    int md_list_index = -1;
    
    /// Declare result
    ///     Note: We're modifying this as we walk the markdown tree so should be mutable but all our custom`NSAttributedString` apis don't work on mutable strings, so we're making it immutable and copying it on every modification.
    NSAttributedString *dst = [[NSMutableAttributedString alloc] init];
    
    /// Walk the md tree
    while (1) {
        
        /// Increment iter
        cmark_iter_next(iter);
        
        /// Get info from iter
        cmark_event_type ev_type = cmark_iter_get_event_type(iter);
        cmark_node *node = cmark_iter_get_node(iter);
        
        /// Process the none event (assert false)
        if (ev_type == CMARK_EVENT_NONE) assert(false);
        
        /// Process the done event (break loop)
        if (ev_type == CMARK_EVENT_DONE) break;
        
        /// Process the enter / exit events
        Boolean did_enter = ev_type == CMARK_EVENT_ENTER; /// Entered node
        Boolean did_exit = ev_type == CMARK_EVENT_EXIT;
        assert(did_enter || did_exit);
        
        /// Get info from node
        cmark_node_type node_type = cmark_node_get_type(node);
        const char *node_type_name = cmark_node_get_type_string(node);
        const char *node_literal = cmark_node_get_literal(node);
        
        /// Handle weird tags on node type
        /// Explanation:
        ///     When we declare some unused string in IB that will be overriden programmatically, we wrap it in `<angle brackets>`, however cmark will parse the rootnode of
        ///     these strings as nonstandard type `CMARK_NODE_DOCUMENT | 0x8000`, and the nodes inside will also have these weird tags in their node type like 0x8000 or 0xc000.
        ///     It will also enter a second document node after the initial document node. Very weird I don't understand it.
        ///     But what we do here is we spit off these weird tags from the pure node type.
        ///     When parsing the `<angle brackes>` string, cmark then finds another document inside the root document, but those documents also ahve the weird non-standard types and contain literal texta and are leaf nodes, so I'm very confused.
        ///     Exact md string where I saw all this weird stuff when trying to parse it:
        ///         `"<Click \"**Restore Defaults...**\" to load the recommended settings for \nyour **Logitech M720 Triathlon**.>"
        /// Update:
        ///     I was accidentally still using swift-cmark, or cmark-gfm which was bundled with the swift-markdown package. After removing those and using cmark directly, this whole issue went away.
        
        if ((0)) {
            long weird_node_type_tags = 0;
            cmark_node_type first_node_type = MAX(CMARK_NODE_FIRST_INLINE, CMARK_NODE_FIRST_BLOCK);
            cmark_node_type last_node_type = MAX(CMARK_NODE_LAST_INLINE, CMARK_NODE_LAST_BLOCK);
            Boolean node_has_standard_type = first_node_type <= node_type && node_type <= last_node_type;
            if (!node_has_standard_type) {
                long node_type_mask = pow(2, bit_count(last_node_type)) - 1;
                weird_node_type_tags = node_type & ~node_type_mask;
                node_type = node_type & node_type_mask;
            }
        }
        
        /// Define `leaf_node_types`
        ///     Notes:
        ///     - These are the leaf node types as documented in the cmark headers.
        ///     - Other node types can also be leafs in the sense that they have no children (See `is_leaf` var [Oct 2025]), but leaf-node-type nodes can never have children, and we will only receive enter events for them, no exit events.
        ///             non-leaf-node-type nodes will receive an enter and an exit event, even if they have no children. The only non-leaf-node-type node that I've seen have 0 children is the document node when you pass in an emptry string for parsing.

        cmark_node_type leaf_types[] = {
            CMARK_NODE_HTML_BLOCK,
            CMARK_NODE_THEMATIC_BREAK,
            CMARK_NODE_CODE_BLOCK,
            CMARK_NODE_TEXT,
            CMARK_NODE_SOFTBREAK,
            CMARK_NODE_LINEBREAK,
            CMARK_NODE_CODE,
            CMARK_NODE_HTML_INLINE
        };
        bool is_leaf_type = anysatisfy(leaf_types, arrcount(leaf_types), x, x == node_type);
        
        /// Valdiate info from node
        
        #if DEBUG
            Boolean is_leaf = cmark_node_first_child(node) == NULL; /// This is different from `is_leaf_type` var (See above) [Oct 2025]
            if (node_literal) assert(is_leaf); /// I think only leaf nodes can directly contain text. That would simplify our control flow
            if (is_leaf_type) assert(is_leaf); /// leaf-node-type nodes can never have children. But other nodes types may also have 0 children.
        #endif
        
        /// Use stack to track node enter and exit
        
        NSRange rangeOfExitedNodeInDst = NSMakeRange(NSNotFound, 0);
        if (!is_leaf_type) {
            if (did_enter) {
                /// Stack push
                [stack addObject: @(dst.length)];
            } else if (did_exit) {
                /// Stack pop
                NSUInteger old_dst_len = [[stack lastObject] unsignedIntegerValue];
                [stack removeLastObject];
                /// Locate the exited node in the dst string.
                rangeOfExitedNodeInDst = NSMakeRange(old_dst_len, dst.length - old_dst_len);
            }
        }
        
        /// Modify dst style based on the markdown nodes that are parsed
        { /// dstmods
            
            /// Skip if this is not the right `event_type` to modify dst
            if (is_leaf_type) { if (!did_enter) goto endof_dstmods; } /// Leaf types only have an enter event, so we need to modify there.
            else              { if (!did_exit)  goto endof_dstmods; }
            
            /// Apply styleOverrides
            MDStyleOverride styleOverride = styleOverrides[@(node_type)];
            if (styleOverride) {
                assert(!is_leaf_type); /// Not sure how to handle `!is_leaf_type` – rangeOfExitedNodeInDst won't be valid.
                dst = styleOverride(dst, &rangeOfExitedNodeInDst);
                goto endof_dstmods;
            }

            /// Apply default styling
            ///     Notes:
            ///     - Nodes with a leaf-node-type are marked with 🍁. They only have enter events, no exit events.
            ///     - Performance testing: [Apr 2025]
            ///         Switch vs NSDictionary:
            ///             Instead of a C-switch, we used to use an NSDictionary containing objc-blocks. That seems slow, but from my benchmarking, the difference to the C-switch looks much smaller than the random fluctuations from run to run.
            ///             But we still stuck to switch since the code is a bit cleaner (at least with our bcase macros)
            ///         All the invocations of MarkdownParser take 10ths or 100ths of a millisecond, (and it's only called once per UI string, when the app first loads – I think)
            ///             -> Therefore, there is absolutely *zero* reason to try to optimize this any further.
            ///     - `man 3 cmark-gfm` says: "Nodes must only be modified after an EXIT event, or an ENTER event for leaf nodes"
            ///         - However we're not concerned about that since we're only analyzing, not modifying the nodes (I think) [Jul 2025]
            
            
            /// Define macros
            ///     To help with repetitve code for adding double linebreaks between block-elements.
            
            #define nodeIsBlockElement(__cmark_node) \
            ({ \
                cmark_node_type type = cmark_node_get_type(__cmark_node); \
                Boolean is_block = CMARK_NODE_FIRST_BLOCK <= type && type <= CMARK_NODE_LAST_BLOCK; \
                is_block; \
            })
            #define nodeIsInlineElement(__cmark_node) \
            ({ \
                cmark_node_type type = cmark_node_get_type(__cmark_node); \
                Boolean is_inline = CMARK_NODE_FIRST_INLINE <= type && type <= CMARK_NODE_LAST_INLINE; \
                is_inline; \
            })
            #define addDoubleLinebreaksForBlockElementToDst() \
                Boolean is_block = nodeIsBlockElement(node); \
                Boolean previous_sibling_is_also_block = nodeIsBlockElement(cmark_node_previous(node)); \
                if (is_block && previous_sibling_is_also_block) { \
                dst = [dst attributedStringByAppending:@"\n\n".attributed]; \
            }
            
            switch (node_type) {
                bcase(CMARK_NODE_NONE): {
                    
                    assert(false); /// Something went wrong
                    
                }
                bcase(CMARK_NODE_DOCUMENT): {          /// == `CMARK_NODE_FIRST_BLOCK`
                    
                    /// Root node
                    
                }
                bcase(CMARK_NODE_BLOCK_QUOTE): {
                    
                    assert(false); /// Don't know how to handle
                    
                }
                bcase(CMARK_NODE_LIST): {
                    
                    addDoubleLinebreaksForBlockElementToDst();
                                                
                    /// Initialize list item counter
                    md_list_index = cmark_node_get_list_start(node);
                    
                }
                bcase(CMARK_NODE_ITEM): {
                    
                    /// Note: Even though list items are blockElements, they don't have double linebreaks between them, so we don't use addDoubleLinebreaksForBlockElementToDst()
                    
                    /// Get parent node of item (the list node)
                    cmark_node *list_node = cmark_node_parent(node);
                    
                    /// Validate
                    assert(cmark_node_get_type(list_node) == CMARK_NODE_LIST);
                    
                    /// Get list tightness
                    ///     A markdown list can become non-tight when there are empty lines between the item lines.
                    Boolean is_tight = cmark_node_get_list_tight(list_node);
                    
                    /// Check if this is the first `list_item`
                    Boolean is_first_item = md_list_index == cmark_node_get_list_start(list_node);
                    
                    /// Get list prefix string
                    NSMutableString *prefix = [NSMutableString string];
                    
                    /// Append newline(s) to prefix
                    if (!is_first_item) {
                        if (is_tight || !is_tight) { /// Turning off non-tight lists (which have a whole free line between items) bc I don't like them and accidentally produce them sometimes.
                            [prefix appendString:@"\n"];
                        }
                    }
                    /// Append list marker (`-, 1., or 1)`) to prefix
                    cmark_list_type list_type = cmark_node_get_list_type(list_node);
                    if      (list_type == CMARK_BULLET_LIST) [prefix appendString:@"• "];
                    else if (list_type == CMARK_ORDERED_LIST)  {
                        if      (cmark_node_get_list_delim(list_node) == CMARK_PAREN_DELIM)     [prefix appendFormat:@"%d) ", md_list_index];
                        else if (cmark_node_get_list_delim(list_node) == CMARK_PERIOD_DELIM)    [prefix appendFormat:@"%d. ", md_list_index];
                        else                                                                    assert(false);
                    }
                    else assert(false);
                                            
                    /// Extract list item content
                    ///     that was already added to dst by our child nodes.
                    NSAttributedString *itemContent = [dst attributedSubstringFromRange:rangeOfExitedNodeInDst];
                    NSDictionary<NSAttributedStringKey, id> *itemFontAttributes = [dst fontAttributesInRange:rangeOfExitedNodeInDst];
                    NSDictionary<NSAttributedStringKey, id> *itemRulerAttributes = [dst rulerAttributesInRange:rangeOfExitedNodeInDst];
                    
                    /// Copy over font- and paragraph-style from listItemContent to the prefix
                    ///     I don't think there are any other attributes which make sense to copy over?
                    NSMutableAttributedString *prefixAttributed = [[NSMutableAttributedString alloc] initWithString: prefix];
                    [prefixAttributed addAttributes:itemFontAttributes range:NSMakeRange(0, prefixAttributed.length)];
                    [prefixAttributed addAttributes:itemRulerAttributes range:NSMakeRange(0, prefixAttributed.length)];
                    
                    /// Combine prefix + item-content
                    NSMutableAttributedString *prefixedItemString = prefixAttributed;
                    [prefixedItemString appendAttributedString:itemContent];
                    
                    /// Replace itemString in dst
                    NSMutableAttributedString *newDst = dst.mutableCopy; /// Man we do so much unnecessary copying and stuff
                    [newDst replaceCharactersInRange:rangeOfExitedNodeInDst withAttributedString:prefixedItemString];
                    dst = newDst;
                    
                    /// Advance list counter
                    md_list_index += 1;
                }
                bcase(CMARK_NODE_CODE_BLOCK): {        /// 🍁
                    
                    assert(false); /// Don't know how to handle
                    
                }
                bcase(CMARK_NODE_HTML_BLOCK): {        /// 🍁
                    
                    /// Explanation:
                    ///     We wrap unused placeholder strings in IB with `<angle brackets>`. This is parsed as a `CMARK_NODE_HTML_BLOCK`. (Or `CMARK_NODE_HTML_INLINE`)
                    ///     We attach these to dst to give users at least some context in case these placeholders make it through to the UI.
                    ///
                    dst = [dst attributedStringByAppending:@(cmark_node_get_literal(node) ?: "").attributed];
                }
                bcase(CMARK_NODE_CUSTOM_BLOCK): {
                    
                    assert(false); /// Don't know how to handle
                    
                }
                bcase(CMARK_NODE_PARAGRAPH): {
                    
                    addDoubleLinebreaksForBlockElementToDst();
                    
                    /// Note: Why the isTopLevel restriction?
                    ///     Update: every list item seems to contain its own paragraph, they are all last paragraphs through, so the `is_top_level` check doesn't seem necessary.
                }
                bcase(CMARK_NODE_HEADING): {
                    
                    assert(false); /// Don't know how to handle
                    
                }
                bcase(CMARK_NODE_THEMATIC_BREAK): {    /// == `CMARK_NODE_LAST_BLOCK` || 🍁 || "thematic break" is the horizontal line aka hrule
                    
                    assert(false); /// Don't know how to handle
                    
                }
                bcase(CMARK_NODE_TEXT): {              /// == `CMARK_NODE_FIRST_INLINE` || 🍁
                    
                    NSString *node_text = @(cmark_node_get_literal(node) ?: "");
                    
                    
                    if (!keepExistingAttributes) {
                        dst = [dst attributedStringByAppending: node_text.attributed]; /// Sooo much unnecessary copying of dst
                    } else {
                        /// Get attributed substring of src which contains the same text as `node_text`
                        ///     By appending the attributed substring of src to dst instead of appending `node_text` directly, we effectively carry over the string attributes from src into dst
                        ///
                        ///     Note: To find the correct substring it might be more efficient faster to use the private NSBigMutableString which seemingly uses unicode characters along with
                        ///     `cmark_node_get_[...]_column()` and `cmark_node_get_[...]_line()` APIs which also uses unicode characters afaik.
                        ///                 Update: [Apr 2025] IIRC, there's also a way to index normal NSString by unicode characters.
                        
                        NSRange src_range = [src.string rangeOfString: node_text options: 0 range: src_search_range];
                        NSAttributedString *src_substr = [src attributedSubstringFromRange: src_range];
                        dst = [dst attributedStringByAppending: src_substr];
                        
                        /// Remove the processed range from the search range
                        ///     End of the search range should always be the end of the src string
                        NSUInteger new_search_range_start = src_range.location + src_range.length;
                        src_search_range = NSMakeRange(new_search_range_start, src.length - new_search_range_start);
                    }
                    
                }
                bcase(CMARK_NODE_SOFTBREAK): {         /// 🍁
                    
                    dst = [dst attributedStringByAppending:@"\n".attributed];
                    
                }
                bcase(CMARK_NODE_LINEBREAK): {         /// 🍁
                    
                    /// Notes:
                    /// - I've never seen this be called. `\n\n` will start a new paragraph, not insert a 'linebreak'.
                    /// - That's because even a siingle newline char starts a new paragraph (at least for NSParagraphStyle). We should be using the "Unicode Line Separator" for simple linebreaks in UI text.
                    ///   - See: https://stackoverflow.com/questions/4404286/how-is-a-paragraph-defined-in-an-nsattributedstring
                    
                    dst = [dst attributedStringByAppending:@"\n".attributed];
                    
                }
                bcase(CMARK_NODE_CODE): {              /// 🍁
                    
                    assert(false); /// Don't know how to handle
                    
                }
                bcase(CMARK_NODE_HTML_INLINE): {       /// 🍁
                    
                    /// Append literal
                    ///     Explanation: See `CMARK_NODE_HTML_BLOCK`
                    NSString *literal = @(cmark_node_get_literal(node) ?: "");
                    if (literal != nil && literal.length > 0) {
                        dst = [dst attributedStringByAppending:literal.attributed];
                    }
                    
                }
                bcase(CMARK_NODE_CUSTOM_INLINE): {
                    
                    assert(false); /// Don't know how to handle
                    
                }
                bcase(CMARK_NODE_EMPH): {
                    /// Notes:
                    /// - We're misusing emphasis (which is usually italic) as a semibold. We're using the semibold, because for the small hint texts in the UI, bold looks way to strong. This is a very unsemantic and hacky solution. It works for now, but just keep this in mind.
                    /// - I tried using Italics in different places in the UI, and it always looked really bad. Also Chinese, Korean, and Japanese don't have italics. Edit: Actually on GitHub they do seem to have italics: https://github.com/dokuwiki/dokuwiki/issues/4080
                    dst = [dst attributedStringByAddingWeight:NSFontWeightSemibold forRange:&rangeOfExitedNodeInDst];
                }
                bcase(CMARK_NODE_STRONG): {
                    dst = [dst attributedStringByAddingWeight:NSFontWeightBold forRange:&rangeOfExitedNodeInDst];
                }
                bcase(CMARK_NODE_LINK): {
                    NSString *urlStr = @(cmark_node_get_url(node) ?: "");
                    if (urlStr != nil && urlStr.length > 0) {
                        dst = [dst attributedStringByAddingHyperlink:[NSURL URLWithString:urlStr] forRange:&rangeOfExitedNodeInDst];
                    }
                }
                bcase(CMARK_NODE_IMAGE): {             /// == `CMARK_NODE_LAST_INLINE`
                    assert(false); /// Don't know how to handle
                    
                }
                bcase(): {
                    NSLog(@"Error: Unknown node_type: %s", node_type_name); /// [Apr 2025] Why are we using NSLog?
                    assert(false);
                }
            }; /// endof switch (node_type)
        }
        endof_dstmods: {};
        
        
    } /// End iterating nodes
    
    /// Free iterator & and tree
    cmark_iter_free(iter);
    cmark_node_free(root);
    
    /// Return generated string
    return dst;
}

///
/// Helper
///

int bit_count(int x) {
    
    int bit_count = 0;
    
    while (true) {
        if (x == 0) break;
        bit_count += 1;
        x = x >> 1;
    }
    
    return bit_count;
}

@end
