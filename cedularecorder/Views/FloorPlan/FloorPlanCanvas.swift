import SwiftUI

struct FloorPlanCanvas: View {
    @ObservedObject var viewModel: FloorPlanEditorViewModel
    let canvasSize: CGSize
    let zoomScale: CGFloat
    let dragOffset: CGSize
    @Binding var selectedCornerIndex: Int?
    let showingMeasurements: Bool
    
    var body: some View {
        Canvas { context, size in
            // Apply transformations
            context.translateBy(x: dragOffset.width, y: dragOffset.height)
            context.scaleBy(x: zoomScale, y: zoomScale)
            
            // Draw room polygon
            if viewModel.corners.count >= 2 {
                drawRoomPolygon(context: context)
            }
            
            // Draw measurements on walls
            if showingMeasurements && viewModel.corners.count >= 2 {
                drawWallMeasurements(context: context)
            }
            
            // Draw corner markers
            drawCornerMarkers(context: context)
            
            // Draw selection highlight
            if let selectedIndex = selectedCornerIndex,
               selectedIndex < viewModel.corners.count {
                drawSelectionHighlight(context: context, at: viewModel.corners[selectedIndex])
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
    }
    
    // MARK: - Drawing Functions
    
    private func drawRoomPolygon(context: GraphicsContext) {
        guard viewModel.corners.count >= 2 else { return }
        
        var path = Path()
        path.move(to: viewModel.corners[0])
        
        for i in 1..<viewModel.corners.count {
            path.addLine(to: viewModel.corners[i])
        }
        
        if viewModel.corners.count >= 3 {
            path.closeSubpath()
            
            // Fill with semi-transparent color
            context.fill(
                path,
                with: .color(Color.blue.opacity(0.1))
            )
        }
        
        // Draw outline
        context.stroke(
            path,
            with: .color(Color.blue),
            lineWidth: 2 / zoomScale
        )
    }
    
    private func drawWallMeasurements(context: GraphicsContext) {
        for i in 0..<viewModel.corners.count {
            let j = (i + 1) % viewModel.corners.count
            let start = viewModel.corners[i]
            let end = viewModel.corners[j]
            
            // Calculate midpoint
            let midpoint = CGPoint(
                x: (start.x + end.x) / 2,
                y: (start.y + end.y) / 2
            )
            
            // Calculate wall length
            let length = viewModel.wallLength(from: i, to: j)
            let text = String(format: "%.2f %@", length, viewModel.measurementUnit.symbol)
            
            // Calculate angle for text rotation
            let angle = atan2(end.y - start.y, end.x - start.x)
            
            // Draw background for better readability
            let textSize = CGSize(width: 60, height: 20)
            let backgroundRect = CGRect(
                x: midpoint.x - textSize.width / 2,
                y: midpoint.y - textSize.height / 2,
                width: textSize.width,
                height: textSize.height
            )
            
            context.fill(
                RoundedRectangle(cornerRadius: 4).path(in: backgroundRect),
                with: .color(Color.white.opacity(0.9))
            )
            
            // Draw measurement text
            context.draw(
                Text(text)
                    .font(.system(size: 12 / zoomScale))
                    .foregroundColor(.black),
                at: midpoint
            )
        }
    }
    
    private func drawCornerMarkers(context: GraphicsContext) {
        for (index, corner) in viewModel.corners.enumerated() {
            let isSelected = selectedCornerIndex == index
            let radius: CGFloat = (isSelected ? 8 : 6) / zoomScale
            
            // Draw corner circle
            let rect = CGRect(
                x: corner.x - radius,
                y: corner.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            
            // Fill color based on index
            let fillColor: Color
            if index == 0 {
                fillColor = .green // Start corner
            } else if isSelected {
                fillColor = .orange // Selected
            } else {
                fillColor = .blue // Normal
            }
            
            context.fill(
                SwiftUI.Circle().path(in: rect),
                with: .color(fillColor)
            )
            
            // Draw border
            context.stroke(
                SwiftUI.Circle().path(in: rect),
                with: .color(.white),
                lineWidth: 2 / zoomScale
            )
            
            // Draw corner number
            context.draw(
                Text("\(index + 1)")
                    .font(.system(size: 10 / zoomScale, weight: .bold))
                    .foregroundColor(.white),
                at: corner
            )
        }
    }
    
    private func drawSelectionHighlight(context: GraphicsContext, at point: CGPoint) {
        let radius: CGFloat = 12 / zoomScale
        
        // Draw pulsing ring
        let rect = CGRect(
            x: point.x - radius,
            y: point.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        
        context.stroke(
            SwiftUI.Circle().path(in: rect),
            with: .color(Color.orange.opacity(0.6)),
            lineWidth: 3 / zoomScale
        )
    }
}

// MARK: - Grid Overlay Component

struct GridOverlay: View {
    let size: CGSize
    let scale: CGFloat
    let offset: CGSize
    let gridSpacing: CGFloat = 50
    
    var body: some View {
        Canvas { context, _ in
            // Apply transformations
            context.translateBy(x: offset.width, y: offset.height)
            context.scaleBy(x: scale, y: scale)
            
            // Calculate visible grid range
            let startX = -offset.width / scale
            let startY = -offset.height / scale
            let endX = (size.width - offset.width) / scale
            let endY = (size.height - offset.height) / scale
            
            // Draw vertical lines
            var x = floor(startX / gridSpacing) * gridSpacing
            while x <= endX {
                var path = Path()
                path.move(to: CGPoint(x: x, y: startY))
                path.addLine(to: CGPoint(x: x, y: endY))
                
                let isMajor = Int(x / gridSpacing) % 5 == 0
                context.stroke(
                    path,
                    with: .color(Color.gray.opacity(isMajor ? 0.3 : 0.15)),
                    lineWidth: (isMajor ? 1 : 0.5) / scale
                )
                
                x += gridSpacing
            }
            
            // Draw horizontal lines
            var y = floor(startY / gridSpacing) * gridSpacing
            while y <= endY {
                var path = Path()
                path.move(to: CGPoint(x: startX, y: y))
                path.addLine(to: CGPoint(x: endX, y: y))
                
                let isMajor = Int(y / gridSpacing) % 5 == 0
                context.stroke(
                    path,
                    with: .color(Color.gray.opacity(isMajor ? 0.3 : 0.15)),
                    lineWidth: (isMajor ? 1 : 0.5) / scale
                )
                
                y += gridSpacing
            }
            
            // Draw origin marker
            let originRect = CGRect(x: -3, y: -3, width: 6, height: 6)
            context.fill(
                SwiftUI.Circle().path(in: originRect),
                with: .color(Color.red.opacity(0.5))
            )
        }
        .frame(width: size.width, height: size.height)
    }
}