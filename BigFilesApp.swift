//
//  BigFilesApp.swift
//  BigFiles
//
//  Created by Bastiaan Quast on 3/21/25.
//

import SwiftUI

@main
struct BigFilesApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
    }
}
