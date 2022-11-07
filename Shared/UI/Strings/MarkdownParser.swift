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
        
//        print("Transforming Markdown doc to attributed string: \(document)")
        
        var walker = ToAttributed()
        walker.visit(document)
        
        let walkerResult = walker.string
        
        return walkerResult /// Remember to fill out base before using this in UI or trying to calculate it's size. (What's wrong with using it in the UI before filling out base?)
    }
    
}

struct ToAttributed: MarkupWalker {
    
    var string: NSMutableAttributedString = NSMutableAttributedString(string: "")
    
    mutating func visitLink(_ link: Link) -> () {
        
        let str: NSAttributedString
        if let destination = link.destination, let url = URL(string: destination) {
            str = NSAttributedString.hyperlink(from: link.plainText, with: url)
        } else {
            str = NSAttributedString(string: link.plainText)
        }
        
        string.append(str)
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
    mutating func visitLineBreak(_ lineBreak: LineBreak) -> () {
        /// I've never seen this be called. `\n\n` will start a new paragraph.
        string.append(NSAttributedString(string: "\n\n"))
    }
    
    mutating func visitParagraph(_ paragraph: Paragraph) -> () {
        
        /// Note: Why the isTopLevel restriction?
        
        descendInto(paragraph)
        
        var isLast = false
        if let peerCount = paragraph.parent?.childCount, paragraph.indexInParent == peerCount - 1 {
            isLast = true
        }
        let isTopLevel = paragraph.parent is Document
        if isTopLevel && !isLast {
            string.append(NSAttributedString(string: "\n\n"))
        }
    }
    
    mutating func visitListItem(_ listItem: ListItem) -> () {
        
        string.append(NSAttributedString(string: String(format: "%d. ", listItem.indexInParent+1)))
        descendInto(listItem)
        
        var isLast = false
        if let peerCount = listItem.parent?.childCount, listItem.indexInParent == peerCount - 1{
            isLast = true
        }
        if !isLast {
            string.append(NSAttributedString(string: "\n"))
        }
    }
}
