//
// --------------------------------------------------------------------------
// AboutTabController.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Cocoa

class AboutTabController: NSViewController {

    @IBOutlet weak var versionField: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        versionField.stringValue = "\(Utility_App.bundleVersionShort()) (\(Utility_App.bundleVersion()))"
    }
    
    
    
}
