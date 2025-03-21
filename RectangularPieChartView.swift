import SwiftUI

struct RectangularPieChartView: View {
    let item: FileItem
    let onItemClick: (FileItem) -> Void
    
    private let colors: [Color] = [
        .red, .orange, .yellow, .green, .blue, .purple, .pink,
        .mint, .teal, .cyan, .indigo
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color(nsColor: .windowBackgroundColor)
                
                // Chart
                if !item.children.isEmpty {
                    TreemapView(
                        items: item.children,
                        size: geometry.size,
                        colors: colors,
                        onItemClick: onItemClick
                    )
                } else {
                    Text("Empty folder")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
}

struct TreemapView: View {
    let items: [FileItem]
    let size: CGSize
    let colors: [Color]
    let onItemClick: (FileItem) -> Void
    
    var body: some View {
        ZStack {
            // Calculate layout
            let layout = calculateTreemapLayout(items: items, rect: CGRect(origin: .zero, size: size))
            
            // Render rectangles
            ForEach(Array(zip(items.indices, items)), id: \.1.id) { index, item in
                if let rect = layout[index] {
                    TreemapCell(
                        item: item,
                        rect: rect,
                        color: colors[index % colors.count],
                        onClick: { onItemClick(item) }
                    )
                }
            }
        }
    }
    
    private func calculateTreemapLayout(items: [FileItem], rect: CGRect) -> [Int: CGRect] {
        var result = [Int: CGRect]()
        
        // Empty check
        if items.isEmpty { return result }
        
        // Get the total size
        let totalSize = items.reduce(0) { $0 + $1.size }
        guard totalSize > 0 else { return result }
        
        // Sort items by size (largest first)
        let sortedItems = items.sorted { $0.size > $1.size }
        
        // Use the "squarified" treemap algorithm
        var currentRect = rect
        var currentTotal: Int64 = 0
        var currentItems: [(index: Int, item: FileItem)] = []
        
        for item in sortedItems {
            let originalIndex = items.firstIndex(where: { $0.id == item.id })!
            currentItems.append((originalIndex, item))
            currentTotal += item.size
            
            // Check if we've processed all items or need to start a new row
            if currentTotal >= totalSize / 2 || item == sortedItems.last {
                // Calculate the aspect ratio for this group
                let groupSize = currentItems.reduce(0) { $0 + $1.item.size }
                let groupRatio = Double(groupSize) / Double(totalSize)
                
                // Determine which dimension to split
                let useWidth = currentRect.width >= currentRect.height
                let length = useWidth ? currentRect.width : currentRect.height
                
                // Assign rectangles to items in this group
                var offset: CGFloat = 0
                for (index, item) in currentItems {
                    let itemRatio = Double(item.size) / Double(groupSize)
                    let itemLength = CGFloat(itemRatio) * length
                    
                    let itemRect: CGRect
                    if useWidth {
                        itemRect = CGRect(
                            x: currentRect.minX + offset,
                            y: currentRect.minY,
                            width: itemLength,
                            height: CGFloat(groupRatio) * currentRect.height
                        )
                    } else {
                        itemRect = CGRect(
                            x: currentRect.minX,
                            y: currentRect.minY + offset,
                            width: CGFloat(groupRatio) * currentRect.width,
                            height: itemLength
                        )
                    }
                    
                    result[index] = itemRect
                    offset += itemLength
                }
                
                // Update the remaining rectangle for the next group
                if useWidth {
                    currentRect = CGRect(
                        x: currentRect.minX,
                        y: currentRect.minY + CGFloat(groupRatio) * currentRect.height,
                        width: currentRect.width,
                        height: currentRect.height * (1 - CGFloat(groupRatio))
                    )
                } else {
                    currentRect = CGRect(
                        x: currentRect.minX + CGFloat(groupRatio) * currentRect.width,
                        y: currentRect.minY,
                        width: currentRect.width * (1 - CGFloat(groupRatio)),
                        height: currentRect.height
                    )
                }
                
                // Reset for the next group
                currentTotal = 0
                currentItems = []
            }
        }
        
        return result
    }
}

struct TreemapCell: View {
    let item: FileItem
    let rect: CGRect
    let color: Color
    let onClick: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        Rectangle()
            .fill(color.opacity(isHovering && item.isDirectory ? 0.8 : 0.6))
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .overlay(
                Rectangle()
                    .stroke(Color.white, lineWidth: 1)
                    .opacity(0.3)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
            )
            .overlay(
                RectangleLabel(item: item, rect: rect)
            )
            .onHover { hovering in
                self.isHovering = hovering
            }
            .onTapGesture {
                onClick()
            }
            .brightness(isHovering && item.isDirectory ? 0.1 : 0)
            .animation(.easeInOut(duration: 0.15), value: isHovering)
            .help(item.isDirectory ? "Click to navigate to \(item.name)" : "\(item.name) (\(item.formattedSize))")
    }
}

struct RectangleLabel: View {
    let item: FileItem
    let rect: CGRect
    
    var body: some View {
        // Only show labels on rectangles large enough to display text
        if rect.width > 80 && rect.height > 40 {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: min(14, max(10, rect.width / 20))))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundColor(.white)
                    .shadow(color: .black, radius: 1)
                
                Text(item.formattedSize)
                    .font(.system(size: min(12, max(8, rect.width / 25))))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black, radius: 1)
            }
            .padding(6)
            .frame(width: rect.width - 12, height: rect.height - 12, alignment: .topLeading)
        }
    }
} 