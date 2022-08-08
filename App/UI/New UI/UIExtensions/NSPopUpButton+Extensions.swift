//
//  NSPopUpButton+Extensions.swift
//  tabTestStoryboards
//
//  Created by Noah Nübling on 12/30/21.
//

import Cocoa
import ReactiveSwift
import ReactiveCocoa

extension Reactive where Base : NSPopUpButton {
    
    var selectedIdentifier: BindingTarget<NSUserInterfaceItemIdentifier> { base.selectedIdentifier }
    var selectedIdentifiers: Signal<NSUserInterfaceItemIdentifier?, Never> { base.selectedIdentifiers }
}

extension NSPopUpButton {
    
    /// Reactive
    
    fileprivate var selectedIdentifier: BindingTarget<NSUserInterfaceItemIdentifier> {
        return BindingTarget<NSUserInterfaceItemIdentifier>(lifetime: self.reactive.lifetime) {
            self.selectItem(withIdentifier: $0)
        }
    }
    fileprivate var selectedIdentifiers: Signal<NSUserInterfaceItemIdentifier?, Never> {
        self.reactive.selectedItems.map { $0.identifier }
    }
    
    /// With identifier base extensions
    
    func item(withIdentifier identifier: NSUserInterfaceItemIdentifier) -> NSMenuItem? {
        
        for item in self.itemArray {
            if item.identifier == identifier {
                return item
            }
        }
        return nil
    }
    
    func selectItem(withIdentifier identifier: NSUserInterfaceItemIdentifier) {
        
        let item = item(withIdentifier: identifier)
        
        if item == nil {
            fatalError("No item with identifier \(identifier)") /// Would be better to throw error but that's too annoying in Swift
        }
        
        select(item)
    }
    
}
