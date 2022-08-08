//
//  NSArray+Extensions.swift
//  tabTestStoryboards
//
//  Created by Noah Nübling on 12/31/21.
//

import Cocoa

extension Array {

    func coolDescription(_ x: Any?) -> String {
        
        let d: String
        if let x = x as? NSObject {
            d = x.description
        } else {
            d = ""
        }
        return d
    }
    
    func prettyDebugDescription() -> String {
        var out = ""
        
        for i in 0..<self.count-1 {
            let x = self[i]
            out.append("\(coolDescription(x)),\n")
        }
        out.append(coolDescription(self.last))
        
        return out
        
    }
}
