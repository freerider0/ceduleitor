import SwiftUI
import simd

// ================================================================================
// MARK: - Room Mini Map View
// ================================================================================

/// A bird's-eye view mini-map showing the room shape being built
struct RoomMiniMapView: View {
    @ObservedObject var detector: RoomShapeDetector
    
    // Map dimensions
    private let mapSize: CGFloat = 150
    private let padding: CGFloat = 20
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Title
            Text("Room Map")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            // Map container
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                
                // Grid lines
                GridPattern()
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                    .frame(width: mapSize - padding, height: mapSize - padding)
                
                // Room shape
                if !detector.corners.isEmpty {
                    GeometryReader { geometry in
                        RoomShapeOverlay(
                            corners: detector.corners,
                            isComplete: detector.isComplete,
                            size: geometry.size
                        )
                    }
                    .frame(width: mapSize - padding, height: mapSize - padding)
                }
                
                // Center indicator
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 4, height: 4)
            }
            .frame(width: mapSize, height: mapSize)
            
            // Scale indicator
            if let scale = calculateScale(detector.corners) {
                HStack(spacing: 2) {
                    Rectangle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 20, height: 1)
                    Text(String(format: "%.1fm", scale))
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.7))
                .shadow(color: .black.opacity(0.5), radius: 10)
        )
    }
    
    /// Calculate scale for the map
    private func calculateScale(_ corners: [simd_float3]) -> Float? {
        guard corners.count >= 2 else { return nil }
        
        let bounds = calculateBounds(corners)
        let maxDimension = max(bounds.max.x - bounds.min.x, bounds.max.z - bounds.min.z)
        
        // Return scale in meters for reference line
        return maxDimension / 4
    }
}

// ================================================================================
// MARK: - Room Shape Overlay
// ================================================================================

struct RoomShapeOverlay: View {
    let corners: [simd_float3]
    let isComplete: Bool
    let size: CGSize
    
    var body: some View {
        Canvas { context, canvasSize in
            guard !corners.isEmpty else { return }
            
            // Calculate bounds and scale
            let bounds = calculateBounds(corners)
            let scale = calculateScaleFactor(bounds: bounds, canvasSize: canvasSize)
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            
            // Transform corners to canvas coordinates
            let canvasPoints = corners.map { corner in
                transformToCanvas(
                    point: corner,
                    bounds: bounds,
                    scale: scale,
                    center: center
                )
            }
            
            // Draw room outline
            drawRoomOutline(
                context: &context,
                points: canvasPoints,
                isComplete: isComplete
            )
            
            // Draw corner markers
            drawCornerMarkers(
                context: &context,
                points: canvasPoints
            )
            
            // Draw current position indicator (last corner)
            if let lastPoint = canvasPoints.last {
                drawCurrentPosition(
                    context: &context,
                    point: lastPoint
                )
            }
        }
    }
    
    /// Transform 3D point to canvas coordinates
    private func transformToCanvas(
        point: simd_float3,
        bounds: (min: simd_float3, max: simd_float3),
        scale: CGFloat,
        center: CGPoint
    ) -> CGPoint {
        // Center the shape
        let centeredX = point.x - (bounds.min.x + bounds.max.x) / 2
        let centeredZ = point.z - (bounds.min.z + bounds.max.z) / 2
        
        // Apply scale and flip Y (Z becomes Y in top-down view)
        let x = CGFloat(centeredX) * scale + center.x
        let y = center.y - CGFloat(centeredZ) * scale // Flip Y
        
        return CGPoint(x: x, y: y)
    }
    
    /// Calculate scale factor to fit shape in canvas
    private func calculateScaleFactor(
        bounds: (min: simd_float3, max: simd_float3),
        canvasSize: CGSize
    ) -> CGFloat {
        let width = bounds.max.x - bounds.min.x
        let depth = bounds.max.z - bounds.min.z
        
        guard width > 0 && depth > 0 else { return 1 }
        
        let margin: CGFloat = 20
        let availableWidth = canvasSize.width - margin * 2
        let availableHeight = canvasSize.height - margin * 2
        
        let scaleX = availableWidth / CGFloat(width)
        let scaleZ = availableHeight / CGFloat(depth)
        
        return min(scaleX, scaleZ)
    }
    
    /// Draw room outline
    private func drawRoomOutline(
        context: inout GraphicsContext,
        points: [CGPoint],
        isComplete: Bool
    ) {
        guard points.count >= 2 else { return }
        
        var path = Path()
        path.move(to: points[0])
        
        for i in 1..<points.count {
            path.addLine(to: points[i])
        }
        
        if isComplete && points.count >= 3 {
            path.closeSubpath()
            
            // Fill completed shape
            context.fill(
                path,
                with: .color(.blue.opacity(0.2))
            )
        }
        
        // Draw outline
        context.stroke(
            path,
            with: .color(isComplete ? .green : .blue),
            lineWidth: 2
        )
    }
    
    /// Draw corner markers
    private func drawCornerMarkers(
        context: inout GraphicsContext,
        points: [CGPoint]
    ) {
        for (index, point) in points.enumerated() {
            // Corner dot
            let color = index == 0 ? Color.green : Color.blue
            
            context.fill(
                Circle().path(in: CGRect(
                    x: point.x - 4,
                    y: point.y - 4,
                    width: 8,
                    height: 8
                )),
                with: .color(color)
            )
            
            // Corner number
            context.draw(
                Text("\(index + 1)")
                    .font(.system(size: 8))
                    .foregroundColor(.white),
                at: CGPoint(x: point.x, y: point.y - 12)
            )
        }
    }
    
    /// Draw current position indicator
    private func drawCurrentPosition(
        context: inout GraphicsContext,
        point: CGPoint
    ) {
        // Pulsing ring around last corner
        context.stroke(
            Circle().path(in: CGRect(
                x: point.x - 8,
                y: point.y - 8,
                width: 16,
                height: 16
            )),
            with: .color(.yellow.opacity(0.6)),
            lineWidth: 1
        )
    }
}

// ================================================================================
// MARK: - Grid Pattern
// ================================================================================

struct GridPattern: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let gridSize: CGFloat = 20
        
        // Vertical lines
        var x = gridSize
        while x < rect.width {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
            x += gridSize
        }
        
        // Horizontal lines
        var y = gridSize
        while y < rect.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
            y += gridSize
        }
        
        return path
    }
}

// ================================================================================
// MARK: - Helper Functions
// ================================================================================

/// Calculate bounds of corner points
private func calculateBounds(_ corners: [simd_float3]) -> (min: simd_float3, max: simd_float3) {
    guard !corners.isEmpty else {
        return (min: simd_float3(0, 0, 0), max: simd_float3(1, 1, 1))
    }
    
    var minBounds = corners[0]
    var maxBounds = corners[0]
    
    for corner in corners {
        minBounds.x = min(minBounds.x, corner.x)
        minBounds.z = min(minBounds.z, corner.z)
        maxBounds.x = max(maxBounds.x, corner.x)
        maxBounds.z = max(maxBounds.z, corner.z)
    }
    
    // Add small margin if bounds are too small
    if maxBounds.x - minBounds.x < 0.1 {
        maxBounds.x += 0.5
        minBounds.x -= 0.5
    }
    if maxBounds.z - minBounds.z < 0.1 {
        maxBounds.z += 0.5
        minBounds.z -= 0.5
    }
    
    return (min: minBounds, max: maxBounds)
}