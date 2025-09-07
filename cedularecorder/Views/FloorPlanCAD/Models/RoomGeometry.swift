import UIKit
import simd

class RoomGeometry {
    
    // MARK: - Properties
    private var corners3D: [simd_float3] = []
    var isClosed: Bool = false
    
    // Computed property for 2D corners
    var corners2D: [CGPoint] {
        return corners3D.map { corner in
            // Convert 3D to 2D (using x and z, ignoring y for floor plan)
            CGPoint(x: CGFloat(corner.x * 100), y: CGFloat(corner.z * 100)) // Scale to pixels
        }
    }
    
    var area: CGFloat {
        guard corners2D.count >= 3 else { return 0 }
        
        var area: CGFloat = 0
        let points = corners2D
        
        for i in 0..<points.count {
            let j = (i + 1) % points.count
            area += points[i].x * points[j].y
            area -= points[j].x * points[i].y
        }
        
        return abs(area) / 2.0 / 10000 // Convert to square meters
    }
    
    var perimeter: CGFloat {
        guard corners2D.count >= 2 else { return 0 }
        
        var perimeter: CGFloat = 0
        let points = corners2D
        
        for i in 0..<points.count {
            let j = (i + 1) % points.count
            if !isClosed && j == 0 { break }
            
            let distance = hypot(points[j].x - points[i].x, points[j].y - points[i].y)
            perimeter += distance
        }
        
        return perimeter / 100 // Convert to meters
    }
    
    // MARK: - Methods
    func setCorners(_ corners: [simd_float3]) {
        self.corners3D = corners
        self.isClosed = corners.count >= 3
    }
    
    func addCorner(at point: CGPoint) {
        let corner3D = simd_float3(Float(point.x / 100), 0, Float(point.y / 100))
        corners3D.append(corner3D)
    }
    
    func moveCorner(at index: Int, to point: CGPoint) {
        guard index < corners3D.count else { return }
        corners3D[index] = simd_float3(Float(point.x / 100), 0, Float(point.y / 100))
    }
    
    func deleteCorner(at index: Int) {
        guard index < corners3D.count else { return }
        corners3D.remove(at: index)
    }
    
    func wallLength(from index: Int) -> CGFloat {
        guard index < corners2D.count - 1 || (isClosed && index < corners2D.count) else { return 0 }
        
        let start = corners2D[index]
        let end = corners2D[(index + 1) % corners2D.count]
        
        return hypot(end.x - start.x, end.y - start.y) / 100 // Convert to meters
    }
}