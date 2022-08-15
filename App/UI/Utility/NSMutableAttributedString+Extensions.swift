//
// --------------------------------------------------------------------------
// NSMutableAttributedString+Extensions.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Foundation
import Down

@objc extension NSAttributedString {
    
    @objc static func label(markdown: String) -> NSAttributedString? {
        
        if #available(macOS 13.0, *) {
            return NSMutableAttributedString(coolMarkdown: markdown)
        } else {
            return self.createString(coolMarkDown2: markdown, secondary: false)
        }
    }
    @objc static func secondaryLabel(markdown: String) -> NSAttributedString? {
        if #available(macOS 13.0, *), false {
            var string = NSAttributedString(coolMarkdown: markdown)
            string = string.settingSecondaryButtonTextColor(forSubstring: string.string)
            string = string.settingFontSize(11)
            return string
        } else {
            return self.createString(coolMarkDown2: markdown, secondary: true)
        }
    }
    
    private static func createString(coolMarkDown2 md: String, secondary: Bool) -> NSAttributedString? {
        
        /// Tries to emulate `NSMutableAttributedString+Additions + attributedStringWithCoolMarkdown:` but available on older macOS versions.
        
        let opt: DownOptions = [.hardBreaks]
        var config = DownStylerConfiguration()

        var f = StaticFontCollection()
        f.body = DownFont.labelFont(ofSize: secondary ? 11 : 13)
        f.listItemPrefix = DownFont.monospacedDigitSystemFont(ofSize: secondary ? 11 : 13, weight: .regular)
        config.fonts = f
        
        var c = StaticColorCollection()
        c.body = secondary ? .secondaryLabelColor : .labelColor
        config.colors = c
        
        var p = StaticParagraphStyleCollection()
        let pStyle = NSMutableParagraphStyle()
        pStyle.alignment = .center
        pStyle.paragraphSpacing = secondary ? 11 : 13
        pStyle.lineSpacing = secondary  ? 1.0 : 0.0
        p.body = pStyle
        config.paragraphStyles = p
        
        var l = ListItemOptions()
        l.alignment = .natural
        l.spacingAbove = 0.0
        l.spacingBelow = secondary ? 4.0 : 5.0
        l.spacingAfterPrefix = secondary ? 6.0 : 8.0
        config.listItemOptions = l
        
        do {
            return try Down(markdownString: md).toAttributedString(opt, styler: DownStyler(configuration: config))
        } catch {
            return nil
        }
    }
}
