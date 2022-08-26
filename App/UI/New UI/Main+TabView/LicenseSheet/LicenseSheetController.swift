//
// --------------------------------------------------------------------------
// LicenseSheetController.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Cocoa

@objc class LicenseSheetController: NSViewController {

    /// Vars
    
    private static var openInstance: LicenseSheetController? = nil
    
    /// IBActions & outlets
    
    @IBOutlet weak var licenseField: NSTextField!
    
    @IBAction func back(_ sender: Any) {
        LicenseSheetController.remove()
    }
    @IBAction func activateLicense(_ sender: Any) {
        
    }
    /// Init
    
    override func viewDidLoad() {
        super.viewDidLoad()
        /// Do view setup here.
    }
    
    /// Interface
    
    @objc static func add() {
        
        openInstance = LicenseSheetController()
        MainAppState.shared.tabViewController.presentAsSheet(openInstance!)
    }
    
    @objc static func remove() {
        
        MainAppState.shared.tabViewController.dismiss(openInstance!)
    }
    
}
