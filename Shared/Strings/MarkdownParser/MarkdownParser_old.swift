//
// --------------------------------------------------------------------------
// MarkdownParser.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// I want to create simple NSAttributed strings with bold and links defined by markup so they can be localized.
/// In macOS 13.0 there's a great standard lib method for this, but we also want this on older versions of macOS.
/// We found the library Down. but it's complicated to set up and doesn't end up looking like a native label string just with some bold and links added.
/// Sooo we're bulding our own parser. Wish me luck.
/// Edit: Works perfectly! Wasn't even that bad.

import Foundation
import Markdown

@objc class MarkdownParser_old: NSObject {
 
    @objc static func attributedString(markdown: String) -> NSAttributedString? {
        
//        if markdown.localizedCaseInsensitiveContains("the recommended settings for") {
//            
//        }
        
        
        let document = Document(parsing: markdown, source: URL(string: ""), options: [.disableSmartOpts])
        if document.isEmpty { return nil }
        
        var visitor = ApplyMarkdown(attributeBase: nil)
        let result = visitor.visit(document)
        
        return result
    }
    
    @objc static func attributedString(attributedMarkdown: NSAttributedString) -> NSAttributedString? {
        
        let document = Document(parsing: attributedMarkdown.string, source: URL(string: ""), options: [.disableSmartOpts])
        if document.isEmpty { return nil }
        
        var visitor = ApplyMarkdown(attributeBase: attributedMarkdown)
        let result = visitor.visit(document)
        
        return result /// Remember to fill out base before using this in UI or trying to calculate it's size. (What's wrong with using it in the UI before filling out base?)
    }
}

struct ApplyMarkdown: MarkupVisitor {
    
    /// Generic type
    
    typealias Result = NSAttributedString?
    
    /// Storage
    
    var base: NSAttributedString? = nil
    var baseRaw: NSString? = nil
    var baseSearchRange: NSRange? = nil
    
    /// Init
    
    init(attributeBase: NSAttributedString? = nil) {
        
        /// Use the attributes from `attributeBase` as base and override them with the markdown styling where there is markdown styling
        /// Note:
        ///     Don't use String.count!
        ///     The equivalent of NSString.length is String.unicodeScalars.count. (Or String.utf16.count, since NSString works in utf16?) String.count is something different (doesn't count all unicode characters as characters)
        
        if let base = attributeBase {
            self.base = base
            self.baseRaw = base.string as NSString
            self.baseSearchRange = NSRange(location: 0, length: baseRaw!.length)
        }
    }
    
    /// Helper function for visiting
    
    fileprivate mutating func descendInto(_ markup: Markup) -> ApplyMarkdown.Result {
        
        let result = NSMutableAttributedString()
        
        for child in markup.children {
            if let r = visit(child) {
                result.append(r)
            }
        }
        
        return result
    }
    
    /// Visitors
    
    mutating func defaultVisit(_ markup: Markdown.Markup) -> Result {
        return descendInto(markup)
    }
    
    mutating func visitText(_ text: Text) -> Result {
        
        if let base = base, let baseRaw = baseRaw, let baseSearchRange = baseSearchRange {
            
            /// Find range of text in base string
            let range = baseRaw.range(of: text.string, options: [], range: baseSearchRange, locale: nil)
            
            if range.location != NSNotFound {
                
                /// Update start of search range
                ///     End should always be the end of the string
                self.baseSearchRange = NSRange(location: range.location, length: baseRaw.length - range.location)
                
                /// Return substring of the base string
                return base.attributedSubstring(from: range)
                
            } else {
                fatalError() /// Feels scary to have fatalError() here but never seems to cause any problems.
            }
            
        } else {
            
            /// If there's no base string, just convert the plainText
            return NSAttributedString(string: text.string)
        }
    }
    
    mutating func visitLink(_ link: Link) -> Result {
        
        guard let str = descendInto(link) else { return nil }
        
        if let destination = link.destination, let url = URL(string: destination) {
            return str.addingHyperlink(url, for: nil)
        } else {
            return str
        }
    }
    
    mutating func visitEmphasis(_ emphasis: Emphasis) -> Result {
        
        /// Notes:
        /// - We're misusing emphasis (which is usually italic) as a semibold. We're using the semibold, because for the small hint texts in the UI, bold looks way to strong. This is a very unsemantic and hacky solution. It works for now, but just keep this in mind.
        /// - I tried using Italics in different places in the UI, and it always looked really bad. Also Chinese, Korean, and Japanese don't have italics. Edit: Actually on GitHub they do seem to have italics: https://github.com/dokuwiki/dokuwiki/issues/4080
        
        guard let str = descendInto(emphasis) else { return nil }
//        return str.addingItalic(for: nil)
        return str.addingWeight(.semibold, for: nil)
    }
    
    mutating func visitStrong(_ strong: Strong) -> Result {
        
        guard let str = descendInto(strong) else { return nil }
//        return str.addingBold(for: nil)
        return str.addingWeight(.bold, for: nil)
    }
    
    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> Result {
        return NSAttributedString(string: "\n")
    }
    mutating func visitLineBreak(_ lineBreak: LineBreak) -> Result {
        /// Notes:
        /// - I've never seen this be called. `\n\n` will start a new paragraph.
        /// - That's because even a siingle newline char starts a new paragraph (at least for NSParagraphStyle). We should be using the "Unicode Line Separator" for simple linebreaks in UI text.
        ///   - See: https://stackoverflow.com/questions/4404286/how-is-a-paragraph-defined-in-an-nsattributedstring
        return NSAttributedString(string: "\n\n")
    }
    
    mutating func visitParagraph(_ paragraph: Paragraph) -> Result {
        
        /// Note: Why the isTopLevel restriction?
        
        guard let str = descendInto(paragraph) else { return nil }
        
        var isLast = false
        if let peerCount = paragraph.parent?.childCount, paragraph.indexInParent == peerCount - 1 {
            isLast = true
        }
        let isTopLevel = paragraph.parent is Document
        if isTopLevel && !isLast {
            return str.appending(NSAttributedString(string: "\n\n"))
        } else {
            return str
        }
    }
    
    mutating func visitListItem(_ listItem: ListItem) -> Result {
        
        var str = NSAttributedString(string: String(format: "%d. ", listItem.indexInParent+1))
        str = str.appending(descendInto(listItem) ?? NSAttributedString(string: ""))
        var isLast = false
        if let peerCount = listItem.parent?.childCount, listItem.indexInParent == peerCount - 1{
            isLast = true
        }
        if !isLast {
            return str.appending(NSAttributedString(string: "\n"))
        } else {
            return str
        }
    }
}
