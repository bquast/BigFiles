//
//  Persistence.swift
//  BigFiles
//
//  Created by Bastiaan Quast on 3/21/25.
//

import SwiftUI

// This is a minimal placeholder to keep the project references intact
// The actual functionality has been removed as we're not using Core Data
struct PersistenceController {
    static let shared = PersistenceController()
    static let preview = PersistenceController()
    
    struct ViewContext {}
    
    class Container {
        let viewContext = ViewContext()
    }
    
    let container = Container()
    
    init(inMemory: Bool = false) {
        // No initialization needed
    }
}
