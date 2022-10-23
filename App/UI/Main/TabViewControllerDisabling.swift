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
        if !alwaysEnabledTabs.contains(id) {
            
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
