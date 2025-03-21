import Foundation

class FileSystemAccessor {
    func scanDirectory(at url: URL, parentPath: String?) async throws -> FileItem {
        let fileManager = FileManager.default
        let resourceKeys: [URLResourceKey] = [.fileSizeKey, .isDirectoryKey]
        
        // Get values for the resource keys
        let resourceValues = try url.resourceValues(forKeys: Set(resourceKeys))
        let isDirectory = resourceValues.isDirectory ?? false
        
        // Compute the full path
        let name = url.lastPathComponent
        let path = parentPath != nil ? "\(parentPath!)/\(name)" : name
        
        var children: [FileItem] = []
        var totalSize: Int64 = 0
        
        if isDirectory {
            // Get the contents of the directory
            let directoryContents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: resourceKeys, options: [])
            
            // Process each file/directory in parallel
            let results = await withTaskGroup(of: (FileItem?, Int64).self) { group in
                for fileURL in directoryContents {
                    group.addTask {
                        do {
                            let item = try await self.scanDirectory(at: fileURL, parentPath: path)
                            return (item, item.size)
                        } catch {
                            return (nil, 0)
                        }
                    }
                }
                
                var items: [FileItem] = []
                var totalDirectorySize: Int64 = 0
                
                for await (item, size) in group {
                    if let item = item {
                        items.append(item)
                        totalDirectorySize += size
                    }
                }
                
                return (items, totalDirectorySize)
            }
            
            children = results.0.sorted(by: { $0.size > $1.size })
            totalSize = results.1
        } else {
            // For files, just get the file size
            if let fileSize = resourceValues.fileSize {
                totalSize = Int64(fileSize)
            }
        }
        
        return FileItem(
            name: name,
            path: path,
            url: url,
            size: totalSize,
            isDirectory: isDirectory,
            children: children
        )
    }
} 