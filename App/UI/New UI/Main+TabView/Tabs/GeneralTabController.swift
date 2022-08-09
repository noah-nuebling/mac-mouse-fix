//
//  GeneralTabController.swift
//  tabTestStoryboards
//
//  Created by Noah Nübling on 23.07.21.
//

import Cocoa
import ReactiveSwift
import ReactiveCocoa

class GeneralTabController: NSViewController {
    
    /// Convenience
    var enabled: MutableProperty<Bool> { MainAppState.shared.appIsEnabled }
    
    /// Config
    var showInMenubar: MutableProperty<Bool> = MutableProperty(false)
    var checkForUpdates: MutableProperty<Bool> = MutableProperty(false)
    var getBetaVersions: MutableProperty<Bool> = MutableProperty(false)
    
    /// Outlets
    
    @IBOutlet var mainView: NSView!
    
    @IBOutlet weak var masterStack: CollapsingStackView!
    
    @IBOutlet weak var enableToggle: NSControl!
    
    @IBOutlet weak var menuBarToggle: NSButton!
    
    @IBOutlet weak var updatesToggle: NSButton!
    @IBOutlet weak var betaToggle: NSButton!
    
    @IBOutlet weak var mainHidableSection: CollapsingStackView!
    @IBOutlet weak var updatesExtraSection: NSView!
    
    
    @IBOutlet weak var enabledHint: NSTextField!
    @IBOutlet weak var updatesHint: NSTextField!
    

    override func viewDidLoad() {
        super.viewDidLoad()
        
        /// Load data
        enabled.value = false
        showInMenubar.value = false
        checkForUpdates.value = false
        getBetaVersions.value = false
        
        /// Replace enable checkBox with NSSwitch on newer macOS versions
        if #available(macOS 10.15, *) {

            let state = enableToggle.value(forKey: "state")

            let switchView = NSSwitch()
            
            let superView = enableToggle.superview as! NSStackView
            superView.replaceSubview(enableToggle, with: switchView)
            self.enableToggle = switchView

            self.enableToggle.setValue(state, forKey: "state")
            
            switchView.setContentCompressionResistancePriority(.required, for: .vertical)
        }
        
        /// Declare signals
        
        /// MMF enabled binding
        ///     Should this be happending in the backend?
        enabled.producer.startWithValues { enabled in
            var error: NSError?
            HelperServices.enableHelper(asUserAgent: enabled, error: &error)
            if #available(macOS 13, *) {
                if error?.code == 1 {
                    let message = NSAttributedString(markdown: "Mac Mouse Fix was **disabled** in System Settings.\nTo enable Mac Mouse Fix:\n\n1. Go to [Login Items Settings](x-apple.systempreferences:com.apple.LoginItems-Settings.extension)\n2. Switch on \'Mac Mouse Fix.app\'")
                    if let window = NSApp.mainWindow { /// When this is called right on app start, then there's no window
                        ToastNotificationController.attachNotification(withMessage: message, to: window, forDuration: 0.0)
                    }
                }
            }
        }
        
        /// UI <-> data bindings
        
        enabled <~ enableToggle.reactive.boolValues
        showInMenubar <~ menuBarToggle.reactive.boolValues
        checkForUpdates <~ updatesToggle.reactive.boolValues
        getBetaVersions <~ betaToggle.reactive.boolValues
        
        enableToggle.reactive.boolValue <~ enabled
        menuBarToggle.reactive.boolValue <~ showInMenubar
        updatesToggle.reactive.boolValue <~ checkForUpdates
        betaToggle.reactive.boolValue <~ getBetaVersions
        
        mainHidableSection.reactive.isCollapsed <~ enabled.negate()
        updatesExtraSection.reactive.isCollapsed <~ checkForUpdates.negate()
        
        /// Labels
        
        enabledHint.stringValue = NSLocalizedString("Mac Mouse Fix will stay enabled after you\nclose it", comment: "")
        updatesHint.stringValue = NSLocalizedString("You'll see new updates when you open this window", comment: "")
        
//        updatesHint.reactiveAnimator(type: .fade).stringValue <~ checkForUpdates.map { checkUpdates in
//            return checkUpdates ?
//                NSLocalizedString("You'll see new updates when you open this window", comment: "")
//                : NSLocalizedString("You won't see updates", comment: "")
//        }
        
    }
}
