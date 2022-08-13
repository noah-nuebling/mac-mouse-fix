//
// --------------------------------------------------------------------------
// ButtonTabController.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Foundation

@objc class ButtonTabController: NSViewController {
    
    ///
    /// Outlets
    ///
    
    /// AddView
    
    @IBOutlet var addFieldController: AddViewController!
    
    @IBOutlet weak var addField: NSBox!
    @IBOutlet weak var plusIcon: NSImageView!
    
    /// TableView
    
    @IBOutlet var tableController: RemapTableController!
    
    @IBOutlet weak var scrollView: MFScrollView!
    @IBOutlet weak var clipView: NSClipView!
    @IBOutlet weak var tableView: RemapTableView!
    
    /// Buttons
    
    @IBOutlet weak var optionsButton: NSButton!
    @IBOutlet weak var restoreDefaultButton: NSButton!
    
    ///
    /// Init
    ///
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
    }
    
}
