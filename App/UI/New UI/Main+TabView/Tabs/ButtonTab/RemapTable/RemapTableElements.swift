//
// --------------------------------------------------------------------------
// RemapTableButton.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

import Cocoa

@objc class RemapTableButton: NSButton {

    @objc var host: NSTableCellView? = nil
}

@objc class RemapTableMenuItem: NSMenuItem {
    
    @objc var host: NSTableCellView? = nil
}
