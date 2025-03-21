//
//  ContentView.swift
//  BigFiles
//
//  Created by Bastiaan Quast on 3/21/25.
//

import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var fileTree = FileTree()
    @State private var currentPath: URL?
    @State private var isScanning = false
    @State private var showingFileCount = false
    
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
                
                if let currentItem = fileTree.currentItem {
                    Text("\(currentItem.formattedSize) • \(currentItem.children.count) items")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.trailing, 8)
                }
                
                if isScanning {
                    ProgressView()
                        .scaleEffect(0.7)
                        .padding(.trailing, 5)
                    Text("Scanning...")
                        .font(.system(size: 12))
                }
            }
            .padding(10)
            .background(
                VisualEffectView(material: .menu, blendingMode: .behindWindow)
                    .edgesIgnoringSafeArea(.top)
            )
            
            // Breadcrumb navigation
            if !fileTree.breadcrumbs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        Button(action: {
                            if fileTree.breadcrumbs.count > 1 {
                                navigateToDirectory(fileTree.breadcrumbs.first!)
                            }
                        }) {
                            Image(systemName: "house")
                                .font(.system(size: 12))
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        .disabled(fileTree.breadcrumbs.count <= 1)
                        
                        Text("/")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                        
                        ForEach(Array(fileTree.breadcrumbs.enumerated()), id: \.element.id) { index, crumb in
                            if index > 0 {
                                Text("/")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 12))
                            }
                            
                            Button(action: {
                                navigateToDirectory(crumb)
                            }) {
                                if crumb == fileTree.breadcrumbs.last {
                                    Text(crumb.name)
                                        .foregroundColor(.primary)
                                        .fontWeight(.semibold)
                                        .font(.system(size: 12))
                                } else {
                                    Text(crumb.name)
                                        .foregroundColor(.blue)
                                        .font(.system(size: 12))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 6)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
            }
            
            // Main content
            if let currentItem = fileTree.currentItem {
                ZStack {
                    RectangularPieChartView(item: currentItem, onItemClick: { clickedItem in
                        if clickedItem.isDirectory {
                            navigateToDirectory(clickedItem)
                        }
                    })
                    
                    // Up button (only in subdirectories)
                    if fileTree.breadcrumbs.count > 1 {
                        VStack {
                            HStack {
                                Spacer()
                                Button(action: {
                                    if fileTree.breadcrumbs.count > 1 {
                                        let parentIndex = fileTree.breadcrumbs.count - 2
                                        navigateToDirectory(fileTree.breadcrumbs[parentIndex])
                                    }
                                }) {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                        .shadow(radius: 2)
                                        .padding(12)
                                        .background(Circle().fill(Color.black.opacity(0.2)))
                                }
                                .buttonStyle(.plain)
                                .padding()
                            }
                            Spacer()
                        }
                    }
                }
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

// Helper for NSVisualEffectView to get macOS native blur
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

#Preview {
    ContentView()
}
