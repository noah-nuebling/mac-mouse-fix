//
//  InputProcessing.swift
//  Mouse Remap Helper
//
//  Created by Noah Nübling on 26.07.18.
//  Copyright © 2018 Noah Nuebling Enterprises Ltd. All rights reserved.
//

import Cocoa
import Foundation



extension Array where Element: Equatable {
    mutating func remove(_ obj: Element) {
        self = self.filter { $0 != obj }
    }
}



var pressed_button_list = [Int] ()

@objc class InputProcessing: NSObject {
    public func buttonInput (button: Int, state: Int) {
        
        if state == 1 {
            pressed_button_list.append(button)
        }
        else {
            pressed_button_list.remove(button)
        }
        
        print(pressed_button_list)
    }
    
    
    
    
}
