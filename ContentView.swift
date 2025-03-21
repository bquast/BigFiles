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
    @State private var showInfoPanel = false
    @State private var hoveredItem: FileItem? = nil
    
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
                    Button(action: {
                        withAnimation {
                            showInfoPanel.toggle()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Text("\(currentItem.formattedSize) • \(currentItem.children.count) items")
                                .font(.system(size: 12))
                            Image(systemName: showInfoPanel ? "info.circle.fill" : "info.circle")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
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
                    HStack(spacing: 0) {
                        // Main treemap visualization
                        RectangularPieChartView(item: currentItem, onItemClick: { clickedItem in
                            if clickedItem.isDirectory {
                                navigateToDirectory(clickedItem)
                            } else {
                                // Just show hover info for non-directory items
                                hoveredItem = clickedItem
                            }
                        })
                        .frame(maxWidth: .infinity)
                        
                        // Info panel (optional)
                        if showInfoPanel {
                            DirectoryInfoPanel(
                                item: currentItem,
                                hoveredItem: hoveredItem,
                                onSelectItem: { selectedItem in
                                    if selectedItem.isDirectory {
                                        navigateToDirectory(selectedItem)
                                    }
                                }
                            )
                            .frame(width: 250)
                            .transition(.move(edge: .trailing))
                        }
                    }
                    
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
                                .offset(x: showInfoPanel ? -250 : 0)
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
            showInfoPanel = false
            
            Task {
                await fileTree.scanDirectory(at: url)
                isScanning = false
            }
        }
    }
    
    private func navigateToDirectory(_ item: FileItem) {
        guard item.isDirectory else { return }
        
        hoveredItem = nil
        
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

struct DirectoryInfoPanel: View {
    let item: FileItem
    let hoveredItem: FileItem?
    let onSelectItem: (FileItem) -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Directory info header
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Text(item.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    HStack {
                        Text(item.formattedSize)
                            .font(.subheadline)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text("\(item.children.count) items")
                            .font(.subheadline)
                    }
                    .padding(.top, 2)
                }
                .padding(.bottom, 4)
                
                Divider()
                
                if let hoveredItem = hoveredItem {
                    // Show details for hovered item
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Selected Item")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(hoveredItem.name)
                            .font(.headline)
                            .lineLimit(2)
                        
                        HStack {
                            Text("Size:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(hoveredItem.formattedSize)
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Text("Path:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(hoveredItem.path)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        
                        if hoveredItem.isDirectory {
                            Button("Open This Directory") {
                                onSelectItem(hoveredItem)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(NSColor.controlBackgroundColor))
                    )
                    
                    Divider()
                }
                
                // List largest items
                VStack(alignment: .leading, spacing: 8) {
                    Text("Largest Items")
                        .font(.headline)
                    
                    ForEach(item.children.sorted(by: { $0.size > $1.size }).prefix(10), id: \.id) { childItem in
                        Button(action: {
                            onSelectItem(childItem)
                        }) {
                            HStack {
                                Image(systemName: childItem.isDirectory ? "folder.fill" : "doc.fill")
                                    .foregroundColor(childItem.isDirectory ? .blue : .gray)
                                
                                VStack(alignment: .leading) {
                                    Text(childItem.name)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    
                                    Text(childItem.formattedSize)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if childItem.isDirectory {
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding()
        }
        .background(Color(NSColor.controlBackgroundColor))
        .frame(maxHeight: .infinity)
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
