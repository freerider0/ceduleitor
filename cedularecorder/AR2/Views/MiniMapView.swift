import SwiftUI

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

                Canvas { context, size in
                    context.translateBy(x: size.width / 2, y: size.height / 2)

                    // Rotate map so user always faces up (Metal Gear Solid style)
                    context.rotate(by: Angle(radians: -Double(coordinator.userRotation)))

                    context.scaleBy(x: mapScale, y: mapScale)

                    drawGrid(context: context, size: size)

                    if let roomPolygon = coordinator.currentRoomPolygon {
                        drawRoomPolygon(context: context, polygon: roomPolygon)
                    }

                    for segment in coordinator.getWallSegmentsForMiniMap() {
                        drawWallSegment(context: context, segment: segment)
                    }

                    drawUserIndicator(
                        context: context,
                        position: coordinator.userPosition,
                        rotation: coordinator.userRotation
                    )
                }

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
                path.move(to: CGPoint(x: CGFloat(segment.start.x), y: CGFloat(segment.start.y)))
                path.addLine(to: CGPoint(x: CGFloat(segment.end.x), y: CGFloat(segment.end.y)))
            },
            with: .color(segment.color),
            lineWidth: 3.0 / mapScale
        )
    }

    private func drawRoomPolygon(context: GraphicsContext, polygon: AR2RoomPolygon) {
        guard polygon.vertices.count >= 2 else { return }

        let path = Path { path in
            path.move(to: CGPoint(x: CGFloat(polygon.vertices[0].x), y: CGFloat(polygon.vertices[0].y)))
            for vertex in polygon.vertices.dropFirst() {
                path.addLine(to: CGPoint(x: CGFloat(vertex.x), y: CGFloat(vertex.y)))
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

    private func drawUserIndicator(context: GraphicsContext, position: SIMD2<Float>, rotation: Float) {
        // MGS-style vision cone
        let coneLength: CGFloat = 2.0  // In world units (2 meters)
        let coneAngle: CGFloat = .pi / 4  // 45 degrees each side = 90 degree FOV

        // Since map rotates, cone always points up (no rotation needed)
        let leftPoint = CGPoint(
            x: CGFloat(position.x) - sin(coneAngle) * coneLength,
            y: CGFloat(position.y) - cos(coneAngle) * coneLength
        )
        let rightPoint = CGPoint(
            x: CGFloat(position.x) + sin(coneAngle) * coneLength,
            y: CGFloat(position.y) - cos(coneAngle) * coneLength
        )

        // Draw vision cone with gradient
        let conePath = Path { path in
            path.move(to: CGPoint(x: CGFloat(position.x), y: CGFloat(position.y)))
            path.addLine(to: leftPoint)
            path.addArc(
                center: CGPoint(x: CGFloat(position.x), y: CGFloat(position.y)),
                radius: coneLength,
                startAngle: Angle(radians: -.pi - coneAngle),
                endAngle: Angle(radians: -.pi + coneAngle),
                clockwise: false
            )
            path.addLine(to: rightPoint)
            path.closeSubpath()
        }

        context.fill(conePath, with: .color(.yellow.opacity(0.3)))
        context.stroke(conePath, with: .color(.yellow.opacity(0.8)), lineWidth: 1.0 / mapScale)

        // User dot
        context.fill(
            SwiftUI.Circle()
                .path(in: CGRect(x: CGFloat(position.x) - 0.15, y: CGFloat(position.y) - 0.15, width: 0.3, height: 0.3)),
            with: .color(.white)
        )
    }
}