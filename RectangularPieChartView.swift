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
        ZStack(alignment: .topLeading) {
            // Base rectangle with stronger hover effect
            Rectangle()
                .fill(color.opacity(isHovering ? 1.0 : 0.6))
                .frame(width: rect.width, height: rect.height)
            
            // White border (much thicker on hover)
            Rectangle()
                .stroke(Color.white, lineWidth: isHovering ? 3 : 1)
                .opacity(isHovering ? 0.9 : 0.4)
                .frame(width: rect.width, height: rect.height)
            
            // Glow effect on hover
            if isHovering {
                Rectangle()
                    .stroke(Color.white, lineWidth: 2)
                    .blur(radius: 3)
                    .opacity(0.7)
                    .frame(width: rect.width, height: rect.height)
            }
            
            // Label
            if rect.width > 100 && rect.height > 50 {
                RectangleLabel(item: item, rect: rect, isHovering: isHovering)
                    .padding(8)
            } else if rect.width > 50 && rect.height > 30 {
                // Simplified label for smaller cells
                Text(item.name)
                    .font(.system(size: 10))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundColor(.white)
                    .shadow(color: .black, radius: 1, x: 1, y: 1)
                    .padding(4)
                    .frame(maxWidth: rect.width - 8)
                    .scaleEffect(isHovering ? 1.1 : 1.0)
            }
            
            // Hover indicator for small cells without visible labels
            if isHovering && (rect.width <= 50 || rect.height <= 30) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.7))
                        .frame(width: 20, height: 20)
                    
                    Circle()
                        .stroke(Color.black, lineWidth: 1)
                        .frame(width: 20, height: 20)
                }
                .shadow(radius: 2)
                .position(x: rect.width / 2, y: rect.height / 2)
            }
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
        .brightness(isHovering ? 0.15 : 0)
        .scaleEffect(isHovering ? 1.01 : 1.0, anchor: .center)
        .zIndex(isHovering ? 10 : 0)  // Bring hovered item to front
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                self.isHovering = hovering
            }
        }
        .onTapGesture {
            onClick()
        }
        .overlay(
            isHovering ? detailedTooltip : nil,
            alignment: .center
        )
        .help(item.isDirectory ? "Click to navigate to \(item.name)" : "\(item.name) (\(item.formattedSize))")
    }
    
    private var detailedTooltip: some View {
        // Only show detailed tooltip if rectangle is large enough
        Group {
            if rect.width > 150 && rect.height > 100 && !item.isDirectory {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 14, weight: .bold))
                        .lineLimit(2)
                    
                    Divider()
                    
                    HStack {
                        Text("Size:")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Text(item.formattedSize)
                            .font(.system(size: 12))
                    }
                    
                    // Show path only if it's not too long
                    if item.path.count < 60 {
                        HStack {
                            Text("Path:")
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                            Text(item.path)
                                .font(.system(size: 12))
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.8))
                        .shadow(color: .black.opacity(0.7), radius: 8)
                )
                .foregroundColor(.white)
                .frame(width: min(rect.width - 20, 250))
                .offset(y: rect.height / 4)
                .transition(.opacity)
            }
        }
    }
}

struct RectangleLabel: View {
    let item: FileItem
    let rect: CGRect
    let isHovering: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Semi-transparent background for better readability
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.black.opacity(isHovering ? 0.7 : 0.3))
                .frame(width: min(rect.width - 16, 200), height: 40)
                .overlay(
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.system(size: min(13, max(10, rect.width / 25))))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundColor(.white)
                            .shadow(color: .black, radius: 1)
                            .padding(.horizontal, 4)
                        
                        Text(item.formattedSize)
                            .font(.system(size: min(11, max(8, rect.width / 30))))
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(color: .black, radius: 1)
                            .padding(.horizontal, 4)
                    }
                    .padding(.vertical, 4)
                )
                .scaleEffect(isHovering ? 1.1 : 1.0)
                .shadow(color: isHovering ? .white.opacity(0.3) : .clear, radius: 3)
        }
        .frame(width: rect.width - 16, height: rect.height - 16, alignment: .topLeading)
    }
} 