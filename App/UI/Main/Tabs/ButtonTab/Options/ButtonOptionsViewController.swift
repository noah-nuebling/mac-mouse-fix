//
// --------------------------------------------------------------------------
// ButtonOptionsViewController.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Cocoa
import ReactiveCocoa
import ReactiveSwift

class ButtonOptionsViewController: NSViewController {

    /// Vars
    
    static var instance: ButtonOptionsViewController? = nil
    
    var lockPointer = ConfigValue<Bool>(configPath: "General.lockPointerDuringDrag")
    
    /// IB outlets & actions
    
    @IBOutlet weak var doneButton: NSButton!
    @IBOutlet weak var lockPointerButton: NSButton!
        
    @IBAction func done(_ sender: Any) {
        ButtonOptionsViewController.remove()
    }
    
    /// Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        lockPointerButton.reactive.boolValue <~ lockPointer
        lockPointer <~ lockPointerButton.reactive.boolValues
        
        /// Adjust views for Tahoe
        if #available(macOS 26.0, *) {
            self.view.prefersCompactControlSizeMetrics = true;
        }
    }
    
    /// Interface
    
    @objc static func add() {
        
        /// Create new instance every time. Otherwise the done button won't be blue after the first open
        instance?.nibBundle?.unload()
        instance = nil
        instance = ButtonOptionsViewController(nibName: "ButtonOptionsViewController", bundle: Bundle.main)
        
        /// Open sheet
        guard let tabViewController = MainAppState.shared.tabViewController else { assert(false); return }
        tabViewController.presentAsSheet(instance!)
    }
    
    @objc static func remove() {
        
        /// Close sheet
        guard let tabViewController = MainAppState.shared.tabViewController else { assert(false); return }
        tabViewController.dismiss(instance!)
    }
    
    
    
}
