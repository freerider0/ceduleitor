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

                        // Draw wall segments first
                        let segments = coordinator.getWallSegmentsForMiniMap()
                        for segment in segments {
                            drawWallSegment(context: context, segment: segment)
                        }

                        // Draw intersections
                        drawIntersections(context: context, segments: segments)

                        // Draw debug info if available
                        if let roomPolygon = coordinator.currentRoomPolygon {
                            if let debugInfo = roomPolygon.debugInfo {
                                // Draw rays from unconnected endpoints
                                for ray in debugInfo.rays {
                                    drawRay(context: context, ray: ray)
                                }

                                // Draw possible vertices
                                for vertex in debugInfo.possibleVertices {
                                    drawPossibleVertex(context: context, vertex: vertex)
                                }

                                // Draw cleaned segments in different color
                                for segment in debugInfo.cleanedSegments {
                                    drawCleanedSegment(context: context, segment: segment)
                                }

                                // Draw extended segments in a different color to show the result
                                for segment in debugInfo.extendedSegments {
                                    drawExtendedSegment(context: context, segment: segment)
                                }
                            }

                            // Draw the polygon last (on top)
                            drawRoomPolygon(context: context, polygon: roomPolygon)
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
        // Draw the line segment
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

        // Draw initial point (start) in yellow
        context.fill(
            Path { path in
                path.addEllipse(in: CGRect(
                    x: -CGFloat(segment.start.x) - 0.08,
                    y: -CGFloat(segment.start.y) - 0.08,
                    width: 0.16,
                    height: 0.16
                ))
            },
            with: .color(.yellow)
        )

        // Draw endpoint in orange
        context.fill(
            Path { path in
                path.addEllipse(in: CGRect(
                    x: -CGFloat(segment.end.x) - 0.08,
                    y: -CGFloat(segment.end.y) - 0.08,
                    width: 0.16,
                    height: 0.16
                ))
            },
            with: .color(.orange)
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

    private func drawRay(context: GraphicsContext, ray: AR2PolygonDebugInfo.Ray) {
        let rayLength: Float = 100.0  // Length of ray to draw (100 meters)
        let endPoint = ray.origin + ray.direction * rayLength

        // Use orange for endpoint rays, green for start point rays
        let rayColor: Color = ray.isFromEnd ? .orange : .green

        context.stroke(
            Path { path in
                path.move(to: CGPoint(x: -CGFloat(ray.origin.x), y: -CGFloat(ray.origin.y)))
                path.addLine(to: CGPoint(x: -CGFloat(endPoint.x), y: -CGFloat(endPoint.y)))
            },
            with: .color(rayColor.opacity(0.6)),
            style: StrokeStyle(lineWidth: 1.0 / mapScale, dash: [0.1, 0.1])
        )

        // Draw arrow head (pointing forward in ray direction)
        let arrowSize: Float = 0.2
        let arrowAngle: Float = 0.4  // radians (about 23 degrees)
        // Create arrow points going back from the endpoint
        let arrowPoint1 = endPoint - rotate2D(ray.direction * arrowSize, by: arrowAngle)
        let arrowPoint2 = endPoint - rotate2D(ray.direction * arrowSize, by: -arrowAngle)

        context.stroke(
            Path { path in
                path.move(to: CGPoint(x: -CGFloat(arrowPoint1.x), y: -CGFloat(arrowPoint1.y)))
                path.addLine(to: CGPoint(x: -CGFloat(endPoint.x), y: -CGFloat(endPoint.y)))
                path.addLine(to: CGPoint(x: -CGFloat(arrowPoint2.x), y: -CGFloat(arrowPoint2.y)))
            },
            with: .color(rayColor),
            lineWidth: 1.5 / mapScale
        )
    }

    private func drawPossibleVertex(context: GraphicsContext, vertex: AR2PolygonDebugInfo.PossibleVertex) {
        let color: Color = {
            switch vertex.type {
            case .rayIntersection: return .red
            case .mutual: return .orange
            case .extended: return .purple
            }
        }()

        context.fill(
            Path { path in
                path.addEllipse(in: CGRect(
                    x: -CGFloat(vertex.position.x) - 0.15,
                    y: -CGFloat(vertex.position.y) - 0.15,
                    width: 0.3,
                    height: 0.3
                ))
            },
            with: .color(color)
        )

        // Draw a ring around it
        context.stroke(
            Path { path in
                path.addEllipse(in: CGRect(
                    x: -CGFloat(vertex.position.x) - 0.2,
                    y: -CGFloat(vertex.position.y) - 0.2,
                    width: 0.4,
                    height: 0.4
                ))
            },
            with: .color(color.opacity(0.5)),
            lineWidth: 1.0 / mapScale
        )
    }

    private func drawCleanedSegment(context: GraphicsContext, segment: AR2WallSegment) {
        context.stroke(
            Path { path in
                path.move(to: CGPoint(x: -CGFloat(segment.start.x), y: -CGFloat(segment.start.y)))
                path.addLine(to: CGPoint(x: -CGFloat(segment.end.x), y: -CGFloat(segment.end.y)))
            },
            with: .color(.cyan.opacity(0.5)),
            lineWidth: 1.0 / mapScale
        )
    }

    private func drawExtendedSegment(context: GraphicsContext, segment: AR2WallSegment) {
        context.stroke(
            Path { path in
                path.move(to: CGPoint(x: -CGFloat(segment.start.x), y: -CGFloat(segment.start.y)))
                path.addLine(to: CGPoint(x: -CGFloat(segment.end.x), y: -CGFloat(segment.end.y)))
            },
            with: .color(.mint),
            lineWidth: 4.0 / mapScale
        )
    }

    private func rotate2D(_ vector: SIMD2<Float>, by angle: Float) -> SIMD2<Float> {
        let cosA = cos(angle)
        let sinA = sin(angle)
        return SIMD2<Float>(
            vector.x * cosA - vector.y * sinA,
            vector.x * sinA + vector.y * cosA
        )
    }

    private func drawIntersections(context: GraphicsContext, segments: [AR2WallSegment]) {
        // Find all intersections between segments
        var intersections: [SIMD2<Float>] = []

        for i in 0..<segments.count {
            for j in (i+1)..<segments.count {
                if let intersection = lineSegmentIntersection(
                    segments[i].start, segments[i].end,
                    segments[j].start, segments[j].end
                ) {
                    intersections.append(intersection)
                }
            }
        }

        // Draw intersection points in blue
        for intersection in intersections {
            context.fill(
                Path { path in
                    path.addEllipse(in: CGRect(
                        x: -CGFloat(intersection.x) - 0.1,
                        y: -CGFloat(intersection.y) - 0.1,
                        width: 0.2,
                        height: 0.2
                    ))
                },
                with: .color(.blue)
            )
        }
    }

    private func lineSegmentIntersection(_ p1: SIMD2<Float>, _ p2: SIMD2<Float>,
                                        _ p3: SIMD2<Float>, _ p4: SIMD2<Float>) -> SIMD2<Float>? {
        let d1 = p2 - p1
        let d2 = p4 - p3
        let denominator = d1.x * d2.y - d1.y * d2.x

        // Parallel lines
        if abs(denominator) < 0.0001 {
            return nil
        }

        let t = ((p3.x - p1.x) * d2.y - (p3.y - p1.y) * d2.x) / denominator
        let u = ((p3.x - p1.x) * d1.y - (p3.y - p1.y) * d1.x) / denominator

        // Check if intersection is within both segments
        if t >= 0 && t <= 1 && u >= 0 && u <= 1 {
            return p1 + t * d1
        }

        return nil
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
