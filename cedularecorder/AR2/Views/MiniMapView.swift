import SwiftUI
import Foundation

struct AR2MiniMapView: View {
    @ObservedObject var coordinator: AR2WallCoordinator
    @State private var mapScale: CGFloat = 30.0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                    )

                // Map content that will be rotated and translated
                ZStack {
                    Canvas { context, size in
                        context.translateBy(x: size.width / 2, y: size.height / 2)
                        context.scaleBy(x: mapScale, y: mapScale)

                        drawGrid(context: context, size: size)

                        if let roomPolygon = coordinator.currentRoomPolygon {
                            drawRoomPolygon(context: context, polygon: roomPolygon)
                        }

                        for segment in coordinator.getWallSegmentsForMiniMap() {
                            drawWallSegment(context: context, segment: segment)
                        }
                    }
                }
                // Apply transformations without mirror (rotation handles it now)
                .offset(
                    x: CGFloat(coordinator.userPosition.x) * mapScale,  // No negation - walls are already negated
                    y: CGFloat(coordinator.userPosition.y) * mapScale   // No negation - walls are already negated
                )
                .rotationEffect(Angle(radians: Double(coordinator.userRotation)), anchor: .center)
                .animation(.linear(duration: 0.033), value: coordinator.userPosition)
                .animation(.linear(duration: 0.033), value: coordinator.userRotation)

                // Fixed position indicators (not transformed with map)
                // Direction cone FIRST (behind user dot)
                ZStack {
                    AR2DirectionCone()
                    AR2UserPositionIndicator()
                }
                .position(
                    x: geometry.size.width / 2,
                    y: geometry.size.height / 2
                )
                .allowsHitTesting(false)

                VStack {
                    HStack {
                        Button(action: { mapScale *= 1.2 }) {
                            Image(systemName: "plus.magnifyingglass")
                                .font(.caption)
                                .padding(4)
                                .background(.ultraThinMaterial)
                                .clipShape(SwiftUI.Circle())
                        }

                        Button(action: { mapScale *= 0.8 }) {
                            Image(systemName: "minus.magnifyingglass")
                                .font(.caption)
                                .padding(4)
                                .background(.ultraThinMaterial)
                                .clipShape(SwiftUI.Circle())
                        }
                    }
                    .padding(8)

                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    // MARK: - Drawing Functions

    private func drawGrid(context: GraphicsContext, size: CGSize) {
        let gridSpacing: CGFloat = 1.0
        let gridCount = 10

        for i in -gridCount...gridCount {
            let offset = CGFloat(i) * gridSpacing

            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: offset, y: -size.height/2/mapScale))
                    path.addLine(to: CGPoint(x: offset, y: size.height/2/mapScale))
                },
                with: .color(.gray.opacity(0.2)),
                lineWidth: 0.5 / mapScale
            )

            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: -size.width/2/mapScale, y: offset))
                    path.addLine(to: CGPoint(x: size.width/2/mapScale, y: offset))
                },
                with: .color(.gray.opacity(0.2)),
                lineWidth: 0.5 / mapScale
            )
        }
    }

    private func drawWallSegment(context: GraphicsContext, segment: AR2WallSegment) {
        context.stroke(
            Path { path in
                // Negate X to flip horizontally (since we removed mirror)
                // Y is Z coordinate, negate for screen (forward is up)
                path.move(to: CGPoint(x: -CGFloat(segment.start.x), y: -CGFloat(segment.start.y)))
                path.addLine(to: CGPoint(x: -CGFloat(segment.end.x), y: -CGFloat(segment.end.y)))
            },
            with: .color(segment.color),
            lineWidth: 3.0 / mapScale
        )
    }

    private func drawRoomPolygon(context: GraphicsContext, polygon: AR2RoomPolygon) {
        guard polygon.vertices.count >= 2 else { return }

        let path = Path { path in
            // Negate X to flip horizontally (since we removed mirror)
            // Y is Z coordinate, negate for screen
            path.move(to: CGPoint(x: -CGFloat(polygon.vertices[0].x), y: -CGFloat(polygon.vertices[0].y)))
            for vertex in polygon.vertices.dropFirst() {
                path.addLine(to: CGPoint(x: -CGFloat(vertex.x), y: -CGFloat(vertex.y)))
            }
            if polygon.isClosed {
                path.closeSubpath()
            }
        }

        if polygon.isComplete() {
            context.fill(path, with: .color(.green.opacity(0.2)))
        }

        context.stroke(path, with: .color(.green), lineWidth: 2.0 / mapScale)
    }

}

// MARK: - User Position Indicator
struct AR2UserPositionIndicator: View {
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

// MARK: - Direction Cone (Metal Gear Solid Style)
struct AR2DirectionCone: View {
    @State private var scanlineOffset: CGFloat = 0
    @State private var pulseAnimation = false

    var body: some View {
        // Classic MGS vision cone
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)

            // MGS cone parameters
            let coneLength: CGFloat = 70
            let coneAngle: CGFloat = .pi / 4  // 45 degrees each side = 90 degree FOV

            // Calculate cone points from center
            let leftAngle = -coneAngle
            let rightAngle = coneAngle

            let leftPoint = CGPoint(
                x: center.x + sin(leftAngle) * coneLength,
                y: center.y - cos(leftAngle) * coneLength
            )
            let rightPoint = CGPoint(
                x: center.x + sin(rightAngle) * coneLength,
                y: center.y - cos(rightAngle) * coneLength
            )

            // Create cone path
            let conePath = Path { path in
                path.move(to: center)
                path.addLine(to: leftPoint)

                // Add arc for rounded cone end (MGS style)
                path.addArc(
                    center: center,
                    radius: coneLength,
                    startAngle: Angle(radians: -(.pi/2 + coneAngle)),
                    endAngle: Angle(radians: -(.pi/2 - coneAngle)),
                    clockwise: false
                )

                path.addLine(to: rightPoint)
                path.closeSubpath()
            }

            // Draw gradient fill (MGS blue-green)
            context.fill(
                conePath,
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0, green: 1, blue: 0.8, opacity: 0.4),  // Cyan-green
                        Color(red: 0, green: 0.8, blue: 1, opacity: 0.2),  // Fading cyan
                        Color(red: 0, green: 0.6, blue: 0.8, opacity: 0.05) // Almost transparent
                    ]),
                    startPoint: center,
                    endPoint: CGPoint(x: center.x, y: center.y - coneLength)
                )
            )

            // Add soft glow effect (no lines, just light)
            context.drawLayer { ctx in
                ctx.addFilter(.blur(radius: 5))
                ctx.fill(conePath, with: .color(.green.opacity(0.3)))
            }
        }
        .frame(width: 150, height: 150)
        .onAppear {
            pulseAnimation = true
            // Scanning animation
            withAnimation(Animation.linear(duration: 2).repeatForever(autoreverses: true)) {
                scanlineOffset = 1.0
            }
        }
    }
}
