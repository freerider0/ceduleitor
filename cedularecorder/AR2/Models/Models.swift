import Foundation
import ARKit
import RealityKit
import simd
import SwiftUI

// MARK: - Core Types

enum AR2PlaneClassification: String, CaseIterable {
    case wall
    case door
    case window
    case floor
    case ceiling
    case table
    case seat
    case none

    var color: Color {
        switch self {
        case .wall: return .green
        case .door: return .blue
        case .window: return .yellow
        case .floor: return .gray
        case .ceiling: return .gray
        default: return .white
        }
    }
}

enum AR2PlaneAlignment {
    case horizontal
    case vertical
    case any
}

enum AR2TrackingState {
    case normal
    case limited(AR2TrackingStateReason)
    case notAvailable
}

enum AR2TrackingStateReason {
    case initializing
    case excessiveMotion
    case insufficientFeatures
    case relocalizing
}

// MARK: - Room Model

struct AR2Room: Identifiable, Codable {
    let id: UUID
    var name: String?
    var walls: Set<UUID> = []
    var isComplete: Bool = false
    var area: Float?

    var wallCount: Int {
        walls.count
    }
}

// MARK: - Wall Model

struct AR2Wall: Identifiable {
    let id: UUID
    var roomID: UUID?

    // ARKit Data (stored as-is)
    var transform: simd_float4x4
    var extent: ARPlaneExtent  // Modern API (iOS 16+)
    var center: SIMD3<Float>
    var classification: AR2PlaneClassification
    var alignment: AR2PlaneAlignment

    // Our State
    var entity: ModelEntity?
    var anchorEntity: AnchorEntity?  // To remove from scene
    var isTracked: Bool = false
    var intersectingWalls: Set<UUID> = []
    var adjacentRooms: Set<UUID> = []

    // Computed Properties
    var isWall: Bool {
        classification == .wall && alignment == .vertical
    }

    var isDoor: Bool {
        classification == .door
    }

    var isWindow: Bool {
        classification == .window
    }

    var isFloor: Bool {
        alignment == .horizontal
    }

    func get2DSegment() -> AR2WallSegment {
        // Get the anchor position from transform
        let anchorPosition = transform.columns.3

        // Apply center offset to get actual plane center in world space
        // Transform the local center offset by the rotation matrix
        let rotationMatrix = simd_float3x3(
            SIMD3(transform.columns.0.x, transform.columns.0.y, transform.columns.0.z),
            SIMD3(transform.columns.1.x, transform.columns.1.y, transform.columns.1.z),
            SIMD3(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z)
        )
        let worldCenter = rotationMatrix * center

        // Actual center in world space
        let actualCenterX = anchorPosition.x + worldCenter.x
        let actualCenterZ = anchorPosition.z + worldCenter.z

        // Get rotation from transform
        let rotation = atan2(transform.columns.0.z, transform.columns.0.x)

        let halfWidth = extent.width / 2
        let startX = actualCenterX - halfWidth * cos(rotation)
        let startZ = actualCenterZ - halfWidth * sin(rotation)
        let endX = actualCenterX + halfWidth * cos(rotation)
        let endZ = actualCenterZ + halfWidth * sin(rotation)

        // Store raw coordinates - we'll transform in the view
        return AR2WallSegment(
            start: SIMD2(startX, startZ),
            end: SIMD2(endX, endZ),
            color: classification.color,
            wallID: self.id
        )
    }
}

// MARK: - MiniMap Data

struct AR2WallSegment: Equatable {
    let start: SIMD2<Float>
    let end: SIMD2<Float>
    let color: Color
    let wallID: UUID?  // Optional ID to track which wall this segment came from

    init(start: SIMD2<Float>, end: SIMD2<Float>, color: Color, wallID: UUID? = nil) {
        self.start = start
        self.end = end
        self.color = color
        self.wallID = wallID
    }

    static func == (lhs: AR2WallSegment, rhs: AR2WallSegment) -> Bool {
        return lhs.start == rhs.start && lhs.end == rhs.end && lhs.wallID == rhs.wallID
    }
}

struct AR2RoomPolygon {
    var vertices: [SIMD2<Float>]
    var isClosed: Bool
    var debugInfo: AR2PolygonDebugInfo?

    func isComplete() -> Bool {
        vertices.count >= 3 && isClosed
    }

    func area() -> Float {
        guard isComplete() else { return 0 }

        var sum: Float = 0
        for i in 0..<vertices.count {
            let j = (i + 1) % vertices.count
            sum += vertices[i].x * vertices[j].y
            sum -= vertices[j].x * vertices[i].y
        }
        return abs(sum) / 2
    }
}

// Debug visualization data
struct AR2PolygonDebugInfo {
    struct Ray {
        let origin: SIMD2<Float>
        let direction: SIMD2<Float>
        let isFromEnd: Bool
        let segmentIndex: Int
    }

    struct PossibleVertex {
        let position: SIMD2<Float>
        let type: VertexType
    }

    enum VertexType {
        case rayIntersection
        case extended
        case mutual
    }

    var rays: [Ray] = []
    var possibleVertices: [PossibleVertex] = []
    var cleanedSegments: [AR2WallSegment] = []
    var extendedSegments: [AR2WallSegment] = []
}

struct AR2MiniMapData {
    var walls: [AR2WallSegment]
    var roomPolygon: AR2RoomPolygon?
    var userPosition: SIMD2<Float>
    var userDirection: Float
    var scale: Float = 30.0
}