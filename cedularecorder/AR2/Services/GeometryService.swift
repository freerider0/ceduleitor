import Foundation
import simd

struct AR2PlaneIntersection {
    let point: SIMD3<Float>
    let wall1ID: UUID
    let wall2ID: UUID
}

class AR2GeometryService {
    private let polygonClosingService = AR2PolygonClosingService()

    func calculateRoomArea(walls: [AR2Wall]) -> Float {
        // TODO: Implement using shoelace formula
        return 0.0
    }

    func findIntersections(between walls: [AR2Wall]) -> [AR2PlaneIntersection] {
        let intersections: [AR2PlaneIntersection] = []
        // TODO: Implement intersection logic
        return intersections
    }

    func completePolygon(from segments: [AR2WallSegment]) -> AR2RoomPolygon? {
        // Use the new polygon closing service
        return polygonClosingService.updatePolygon(segments: segments)
    }

    func calculateWallVertices(wall: AR2Wall) -> (topLeft: SIMD3<Float>, topRight: SIMD3<Float>,
                                               bottomLeft: SIMD3<Float>, bottomRight: SIMD3<Float>) {
        let halfWidth = wall.extent.width / 2
        let halfHeight = wall.extent.height / 2

        let tl = wall.transform * SIMD4<Float>(-halfWidth, halfHeight, 0, 1)
        let tr = wall.transform * SIMD4<Float>(halfWidth, halfHeight, 0, 1)
        let bl = wall.transform * SIMD4<Float>(-halfWidth, -halfHeight, 0, 1)
        let br = wall.transform * SIMD4<Float>(halfWidth, -halfHeight, 0, 1)

        return (tl.xyz, tr.xyz, bl.xyz, br.xyz)
    }
}

extension SIMD4 where Scalar == Float {
    var xyz: SIMD3<Float> {
        SIMD3(x, y, z)
    }
}