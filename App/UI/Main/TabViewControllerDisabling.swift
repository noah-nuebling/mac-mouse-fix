//
//  TabViewControllerDisabling.swift
//  tabTestStoryboards
//
//  Created by Noah Nübling on 2/11/22.
//

import Foundation
import ReactiveSwift
import ReactiveCocoa

var alwaysEnabledTabs = ["general", "about"]

extension TabViewController {
    
    override func toolbarWillAddItem(_ notification: Notification) {
        
        let item = notification.userInfo!["item"] as! NSToolbarItem
        let id = item.itemIdentifier.rawValue
        
        /// Sync the isEnabled state of all tabs (except general and about) with the isEnabled state of the app
        ///     If we take too long here, there will be a blank space between the last 2 tabs (Ventura, MMF 3 Beta 4/5). This might have to do with hiding the pointer tab in TabViewController.viewDidAppear()
        if !(alwaysEnabledTabs.contains(id)) {
            
            item.autovalidates = false
            EnabledState.shared.producer.startWithValues { appIsEnabled in
                item.isEnabled = appIsEnabled
            }
        }
        
        /// Call super
        ///     Not sure if necessary
        super.toolbarWillAddItem(notification)
    }
}
