import Foundation
import RealityKit
import ARKit
import UIKit

class AR2PolygonVisualizationService {

    // Create visualization for polygon on floor or ceiling
    func createPolygonVisualization(
        segments: [AR2WallSegment],
        vertices: [SIMD2<Float>],
        isClosed: Bool,
        at height: Float
    ) -> Entity {
        let container = Entity()

        // Create glowing tubes between consecutive vertices to form polygon
        if vertices.count >= 2 {
            for i in 0..<vertices.count - 1 {
                let startVertex = vertices[i]
                let endVertex = vertices[i + 1]
                print("DEBUG AR Tube \(i): from vertex(\(startVertex.x), \(startVertex.y)) to vertex(\(endVertex.x), \(endVertex.y))")
                let tube = createGlowingTube(
                    from: SIMD3(startVertex.x, height, startVertex.y),
                    to: SIMD3(endVertex.x, height, endVertex.y)
                )
                container.addChild(tube)
            }

            // If closed, connect last vertex back to first
            if isClosed && vertices.count > 2 {
                let lastVertex = vertices[vertices.count - 1]
                let firstVertex = vertices[0]
                print("DEBUG AR Tube closing: from vertex(\(lastVertex.x), \(lastVertex.y)) to vertex(\(firstVertex.x), \(firstVertex.y))")
                let tube = createGlowingTube(
                    from: SIMD3(lastVertex.x, height, lastVertex.y),
                    to: SIMD3(firstVertex.x, height, firstVertex.y)
                )
                container.addChild(tube)
            }
        }

        // Create glowing spheres at vertices
        for (i, vertex) in vertices.enumerated() {
            print("DEBUG AR Vertex \(i): (\(vertex.x), \(vertex.y))")
            let sphere = createGlowingSphere(at: SIMD3(vertex.x, height, vertex.y))
            container.addChild(sphere)
        }

        // If polygon is closed, add filled surface
        if isClosed && vertices.count >= 3 {
            let fill = createPolygonFill(vertices: vertices, at: height)
            container.addChild(fill)
        }

        return container
    }

    // Create a glowing tube between two points
    private func createGlowingTube(from: SIMD3<Float>, to: SIMD3<Float>) -> ModelEntity {
        let distance = simd_distance(from, to)
        let cylinder = MeshResource.generateCylinder(height: distance, radius: 0.03)

        // Simple bright green material
        let material = UnlitMaterial(color: .green)

        let entity = ModelEntity(mesh: cylinder, materials: [material])

        // Position at midpoint
        entity.position = (from + to) / 2

        // Rotate cylinder to align with the line between from and to
        // Cylinder's default orientation is along Y-axis
        let direction = normalize(to - from)

        // Calculate rotation to align Y-axis with our direction
        let up = SIMD3<Float>(0, 1, 0)
        let dot = simd_dot(up, direction)

        if abs(dot - 1.0) < 0.001 {
            // Already aligned with Y axis
        } else if abs(dot + 1.0) < 0.001 {
            // Opposite direction
            entity.orientation = simd_quatf(angle: .pi, axis: SIMD3<Float>(1, 0, 0))
        } else {
            let axis = normalize(simd_cross(up, direction))
            let angle = acos(dot)
            entity.orientation = simd_quatf(angle: angle, axis: axis)
        }

        return entity
    }

    // Create a glowing sphere at a vertex
    private func createGlowingSphere(at position: SIMD3<Float>) -> ModelEntity {
        let sphere = MeshResource.generateSphere(radius: 0.05)

        // Simple bright green material
        let material = UnlitMaterial(color: .green)

        let entity = ModelEntity(mesh: sphere, materials: [material])
        entity.position = position

        return entity
    }

    // Create filled polygon surface
    private func createPolygonFill(vertices: [SIMD2<Float>], at height: Float) -> ModelEntity {
        // Convert 2D vertices to 3D
        let positions = vertices.map { SIMD3($0.x, height, $0.y) }

        // Create mesh descriptor for polygon
        var descriptor = MeshDescriptor()
        descriptor.positions = .init(positions)

        // Create polygon primitive (anticlockwise for correct face orientation)
        let vertexCount = UInt8(positions.count)
        let indices = Array(0..<UInt32(positions.count))
        descriptor.primitives = .polygons([vertexCount], indices)

        // Generate mesh
        guard let mesh = try? MeshResource.generate(from: [descriptor]) else {
            return ModelEntity()
        }

        // Create semi-transparent green material
        let material = UnlitMaterial(color: UIColor.green.withAlphaComponent(0.3))

        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.components.set(OpacityComponent(opacity: 0.3))

        return entity
    }
}