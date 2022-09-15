//
// --------------------------------------------------------------------------
// MarkdownParser.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

/// I want to create simple NSAttributed strings with bold and links defined by markup so they can be localized.
/// In macOS 13.0 there's a great standard lib method for this, but we also want this on older versions of macOS.
/// We found the library Down. but it's complicated to set up and doesn't end up looking like a native label string just with some bold and links added.
/// Sooo we're bulding our own parser. Wish me luck.
/// Edit: Works perfectly! Wasn't even that bad.

import Foundation
import Markdown
import CocoaLumberjackSwift

@objc class MarkdownParser: NSObject {
 
    @objc static func attributedString(markdown: String) -> NSAttributedString? {
        
        let document = Document(parsing: markdown, source: URL(string: ""), options: [])
        if document.isEmpty { return nil }
        print("THE DOC: \(document.debugDescription())")
        
        var walker = ToAttributed()
        walker.visit(document)
        
        let walkerResult = walker.string
        
        return walkerResult.fillingOutBase()
    }
    
}

struct ToAttributed: MarkupWalker {
    
    var string: NSMutableAttributedString = NSMutableAttributedString(string: "")
    
    mutating func visitLink(_ link: Link) -> () {
        string.append(NSAttributedString(string: link.plainText))
        if let destination = link.destination, let url = URL(string: destination) {
            string = string.addingLink(with: url, forSubstring: link.plainText) as! NSMutableAttributedString
        }
    }
    
    mutating func visitEmphasis(_ emphasis: Emphasis) -> () {
        string.append(NSAttributedString(string: emphasis.plainText))
        string = string.addingItalic(forSubstring: emphasis.plainText) as! NSMutableAttributedString

    }
    
    mutating func visitStrong(_ strong: Strong) -> () {
        string.append(NSAttributedString(string: strong.plainText))
        string = string.addingBold(forSubstring: strong.plainText) as! NSMutableAttributedString
    }
    
    mutating func visitText(_ text: Text) -> () {
        string.append(NSAttributedString(string: text.string))
    }
    
    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> () {
        string.append(NSAttributedString(string: "\n"))
    }
    mutating func visitParagraph(_ paragraph: Paragraph) -> () {
        descendInto(paragraph)
        let isLast = paragraph.indexInParent == (paragraph.parent?.childCount ?? 0) - 1 
        let isTopLevel = paragraph.parent is Document
        if isTopLevel && !isLast {
            string.append(NSAttributedString(string: "\n"))
        }
    }
    mutating func visitLineBreak(_ lineBreak: LineBreak) -> () {
        string.append(NSAttributedString(string: "\n\n"))
    }
    
    mutating func visitListItem(_ listItem: ListItem) -> () {
        let num = listItem.indexInParent + 1
        string.append(NSAttributedString(string: String(format: "\n%d. ", num)))
        descendInto(listItem)
    }
}
