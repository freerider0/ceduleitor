import SwiftUI
import simd

// MARK: - Wall Model
struct WallModel: Identifiable {
    let id = UUID()
    let startPoint: SIMD3<Float>
    let endPoint: SIMD3<Float>
    let color: Color
}

// MARK: - Mini Map View
struct WallMiniMapView: View {
    let walls: [WallModel]
    let userPosition: SIMD3<Float>
    let userDirection: Float
    let roomPolygon: [SIMD3<Float>]  // Completed polygon vertices
    @State private var mapScale: CGFloat = 30.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black.opacity(0.8)
                
                // Rotating and panning map content
                ZStack {
                    // Grid overlay
                    WallGridOverlay(userPosition: userPosition, scale: mapScale)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                    
                    // Draw completed room polygon if available
                    if !roomPolygon.isEmpty {
                        RoomPolygonShape(vertices: roomPolygon, size: geometry.size, scale: mapScale)
                            .fill(Color.green.opacity(0.2))
                            .overlay(
                                RoomPolygonShape(vertices: roomPolygon, size: geometry.size, scale: mapScale)
                                    .stroke(Color.green, lineWidth: 2)
                            )
                    }
                    
                    // Draw walls - they should appear in front of the user
                    ForEach(walls) { wall in
                        WallPath(wall: wall, size: geometry.size, scale: mapScale)
                            .stroke(wall.color, lineWidth: 3)
                            .shadow(color: wall.color.opacity(0.5), radius: 2)
                    }
                    
                    // User indicator stays in center
                    UserPositionIndicator()
                        .position(
                            x: geometry.size.width / 2,
                            y: geometry.size.height / 2
                        )
                    
                    // North indicator
                    NorthIndicator()
                        .position(
                            x: geometry.size.width / 2,
                            y: 20
                        )
                }
                // Apply transformations: first offset, then rotate
                .offset(
                    x: -CGFloat(userPosition.x) * mapScale,
                    y: -CGFloat(userPosition.z) * mapScale  // Negative Z moves forward walls up
                )
                .rotationEffect(Angle(radians: Double(userDirection)), anchor: .center)
                .scaleEffect(x: -1)  // Mirror horizontally to fix rotation
                .animation(.linear(duration: 0.033), value: userPosition)
                .animation(.linear(duration: 0.033), value: userDirection)
                
                // Fixed UI elements (don't rotate)
                VStack {
                    Spacer()
                    // Scale controls
                    HStack {
                        Button(action: { mapScale = max(10, mapScale - 10) }) {
                            Image(systemName: "minus.circle")
                                .foregroundColor(.white)
                        }
                        
                        Text("\(Int(mapScale))x")
                            .font(.caption)
                            .foregroundColor(.white)
                        
                        Button(action: { mapScale = min(100, mapScale + 10) }) {
                            Image(systemName: "plus.circle")
                                .foregroundColor(.white)
                        }
                    }
                    .padding(8)
                }
                
                // Direction cone (always points up to show forward)
                DirectionCone()
                    .position(
                        x: geometry.size.width / 2,
                        y: geometry.size.height / 2
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - Wall Path Shape
struct WallPath: Shape {
    let wall: WallModel
    let size: CGSize
    let scale: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        
        // Convert world coordinates to screen coordinates
        // In AR: +X is right, +Z is backward (toward user), -Z is forward
        // In minimap: +X is right, +Y is down
        // So we want: forward walls (-Z) to appear up (-Y)
        let start = CGPoint(
            x: center.x + CGFloat(wall.startPoint.x) * scale,
            y: center.y - CGFloat(wall.startPoint.z) * scale  // Negative Z (forward) becomes negative Y (up)
        )
        let end = CGPoint(
            x: center.x + CGFloat(wall.endPoint.x) * scale,
            y: center.y - CGFloat(wall.endPoint.z) * scale  // Negative Z (forward) becomes negative Y (up)
        )
        
        // Draw wall line
        path.move(to: start)
        path.addLine(to: end)
        
        // Add end caps
        let capRadius: CGFloat = 3
        path.addEllipse(in: CGRect(
            x: start.x - capRadius,
            y: start.y - capRadius,
            width: capRadius * 2,
            height: capRadius * 2
        ))
        path.addEllipse(in: CGRect(
            x: end.x - capRadius,
            y: end.y - capRadius,
            width: capRadius * 2,
            height: capRadius * 2
        ))
        
        return path
    }
}

// MARK: - Grid Overlay
struct WallGridOverlay: Shape {
    let userPosition: SIMD3<Float>
    let scale: CGFloat
    let gridSpacing: CGFloat = 1.0 // 1 meter grid
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let gridSize = gridSpacing * scale
        let numberOfLines = Int(max(rect.width, rect.height) / gridSize) + 2
        
        // Vertical lines
        for i in -numberOfLines...numberOfLines {
            let x = rect.width / 2 + CGFloat(i) * gridSize
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
        }
        
        // Horizontal lines
        for i in -numberOfLines...numberOfLines {
            let y = rect.height / 2 + CGFloat(i) * gridSize
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
        }
        
        return path
    }
}

// MARK: - User Position Indicator
struct UserPositionIndicator: View {
    var body: some View {
        SwiftUI.Circle()
            .fill(Color.blue)
            .frame(width: 10, height: 10)
            .overlay(
                SwiftUI.Circle()
                    .stroke(Color.white, lineWidth: 2)
            )
    }
}

// MARK: - Direction Cone
struct DirectionCone: View {
    var body: some View {
        Path { path in
            // Triangle pointing up
            path.move(to: CGPoint(x: 0, y: -15))
            path.addLine(to: CGPoint(x: -8, y: 5))
            path.addLine(to: CGPoint(x: 8, y: 5))
            path.closeSubpath()
        }
        .fill(Color.white.opacity(0.8))
        .overlay(
            Path { path in
                path.move(to: CGPoint(x: 0, y: -15))
                path.addLine(to: CGPoint(x: -8, y: 5))
                path.addLine(to: CGPoint(x: 8, y: 5))
                path.closeSubpath()
            }
            .stroke(Color.blue, lineWidth: 2)
        )
    }
}

// MARK: - North Indicator
struct NorthIndicator: View {
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "arrow.up")
                .font(.caption2)
                .foregroundColor(.red)
            Text("N")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.red)
        }
    }
}

// MARK: - Room Polygon Shape
struct RoomPolygonShape: Shape {
    let vertices: [SIMD3<Float>]
    let size: CGSize
    let scale: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard vertices.count >= 3 else { return path }
        
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        
        // Convert first vertex to screen coordinates
        let firstPoint = CGPoint(
            x: center.x + CGFloat(vertices[0].x) * scale,
            y: center.y - CGFloat(vertices[0].z) * scale  // -Z (forward) becomes -Y (up)
        )
        path.move(to: firstPoint)
        
        // Draw lines to remaining vertices
        for i in 1..<vertices.count {
            let point = CGPoint(
                x: center.x + CGFloat(vertices[i].x) * scale,
                y: center.y - CGFloat(vertices[i].z) * scale
            )
            path.addLine(to: point)
        }
        
        // Close the polygon
        path.closeSubpath()
        
        // Add vertex dots
        for vertex in vertices {
            let point = CGPoint(
                x: center.x + CGFloat(vertex.x) * scale,
                y: center.y - CGFloat(vertex.z) * scale
            )
            path.addEllipse(in: CGRect(
                x: point.x - 4,
                y: point.y - 4,
                width: 8,
                height: 8
            ))
        }
        
        return path
    }
}