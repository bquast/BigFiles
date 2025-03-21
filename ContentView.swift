//
//  ContentView.swift
//  BigFiles
//
//  Created by Bastiaan Quast on 3/21/25.
//

import SwiftUI
import CoreData
import AppKit

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var fileTree = FileTree()
    @State private var currentPath: URL?
    @State private var isScanning = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Top toolbar
            HStack {
                Button(action: {
                    selectFolder()
                }) {
                    Label("Select Folder", systemImage: "folder")
                }
                .padding(.trailing, 8)
                
                if let path = currentPath {
                    Text(path.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .font(.system(size: 12))
                }
                
                Spacer()
                
                if isScanning {
                    ProgressView()
                        .scaleEffect(0.7)
                        .padding(.trailing, 5)
                    Text("Scanning...")
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
            
            // Breadcrumb navigation
            if !fileTree.breadcrumbs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(fileTree.breadcrumbs) { crumb in
                            Button(action: {
                                navigateToDirectory(crumb)
                            }) {
                                if crumb == fileTree.breadcrumbs.last {
                                    Text(crumb.name)
                                        .foregroundColor(.primary)
                                        .fontWeight(.semibold)
                                } else {
                                    HStack(spacing: 2) {
                                        Text(crumb.name)
                                            .foregroundColor(.blue)
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 10))
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
            }
            
            // Main content
            if let currentItem = fileTree.currentItem {
                RectangularPieChartView(item: currentItem, onItemClick: { clickedItem in
                    if clickedItem.isDirectory {
                        navigateToDirectory(clickedItem)
                    }
                })
            } else {
                VStack {
                    Spacer()
                    Text("Select a folder to analyze disk usage")
                        .font(.title2)
                    Spacer()
                }
            }
        }
    }
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            currentPath = url
            isScanning = true
            
            Task {
                await fileTree.scanDirectory(at: url)
                isScanning = false
            }
        }
    }
    
    private func navigateToDirectory(_ item: FileItem) {
        guard item.isDirectory else { return }
        
        // If the item already has children loaded, just update the view
        if !item.children.isEmpty {
            fileTree.navigateToItem(item)
            return
        }
        
        // Otherwise, we need to scan this directory
        isScanning = true
        Task {
            await fileTree.expandDirectory(item)
            isScanning = false
        }
    }
}

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
