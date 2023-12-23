//
// --------------------------------------------------------------------------
// NSAttributedString+Extensions.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Foundation
import Cocoa

extension NSAttributedString {
    
    func image(foregroundColor: NSColor? = nil, backgroundColor: NSColor? = nil) -> NSImage {
        
        /// Src: https://stackoverflow.com/a/64710386/10601702
        
        let size = self.size()
        let image = NSImage(size: size)
        if size.width == 0 || size.height == 0 { return image }
        image.lockFocus()
        let mutableStr = NSMutableAttributedString(attributedString: self)
        if let foregroundColor = foregroundColor,
           let backgroundColor = backgroundColor {
            mutableStr.setAttributes([.foregroundColor: foregroundColor,
                                      .backgroundColor: backgroundColor],
                                     range: .init(location: 0, length: length))
        }
        else
        if let foregroundColor = foregroundColor {
            mutableStr.setAttributes([.foregroundColor: foregroundColor],
                                     range: .init(location: 0, length: length))
        }
        else
        if let backgroundColor = backgroundColor {
            mutableStr.setAttributes([.backgroundColor: backgroundColor],
                                     range: .init(location: 0, length: length))
        }
        mutableStr.draw(in: .init(origin: .zero, size: size))
        image.unlockFocus()
        return image
    }
}
