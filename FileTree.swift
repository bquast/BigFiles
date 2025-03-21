import Foundation

class FileTree: ObservableObject {
    @Published var rootItem: FileItem?
    @Published var currentItem: FileItem?
    @Published var breadcrumbs: [FileItem] = []
    
    private let fileSystemAccessor = FileSystemAccessor()
    
    func scanDirectory(at url: URL) async {
        do {
            let newRootItem = try await fileSystemAccessor.scanDirectory(at: url, parentPath: nil)
            await MainActor.run {
                self.rootItem = newRootItem
                self.currentItem = newRootItem
                self.breadcrumbs = [newRootItem]
            }
        } catch {
            print("Error scanning directory: \(error)")
        }
    }
    
    func expandDirectory(_ item: FileItem) async {
        guard item.isDirectory, item.children.isEmpty else { return }
        
        do {
            let expandedItem = try await fileSystemAccessor.scanDirectory(at: item.url, parentPath: item.path)
            
            await MainActor.run {
                // Update the item's children
                self.updateItemChildren(item, with: expandedItem.children)
                self.navigateToItem(item)
            }
        } catch {
            print("Error expanding directory: \(error)")
        }
    }
    
    func navigateToItem(_ item: FileItem) {
        guard item.isDirectory else { return }
        
        self.currentItem = item
        
        // Update breadcrumbs
        if let index = breadcrumbs.firstIndex(where: { $0.path == item.path }) {
            breadcrumbs = Array(breadcrumbs[0...index])
        } else {
            breadcrumbs.append(item)
        }
    }
    
    private func updateItemChildren(_ item: FileItem, with children: [FileItem]) {
        guard let rootItem = rootItem else { return }
        
        // Find the item in the tree and update its children
        func updateChildren(in parent: inout FileItem) -> Bool {
            if parent.path == item.path {
                parent.children = children
                return true
            }
            
            for i in 0..<parent.children.count where parent.children[i].isDirectory {
                var child = parent.children[i]
                if updateChildren(in: &child) {
                    parent.children[i] = child
                    return true
                }
            }
            
            return false
        }
        
        var mutableRoot = rootItem
        if updateChildren(in: &mutableRoot) {
            self.rootItem = mutableRoot
        }
    }
}

struct FileItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let url: URL
    let size: Int64
    let isDirectory: Bool
    var children: [FileItem]
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
} 