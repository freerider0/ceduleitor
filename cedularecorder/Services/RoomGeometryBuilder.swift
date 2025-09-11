import Foundation
import ARKit
import simd

// ================================================================================
// MARK: - Room Geometry Builder
// ================================================================================

/// Intelligent geometry builder that creates room from mixed corner and wall inputs
class RoomGeometryBuilder {
    
    // MARK: - Data Structures
    
    /// Represents a wall derived from corners or captured directly
    struct Wall {
        let startCorner: simd_float3
        let endCorner: simd_float3
        let normal: simd_float3
        let planeEquation: simd_float4
        
        /// Create wall from two corners
        init(from start: simd_float3, to end: simd_float3) {
            self.startCorner = start
            self.endCorner = end
            
            // Calculate wall direction and normal
            let direction = simd_normalize(end - start)
            // Normal points to the right of the wall direction (assuming Y is up)
            self.normal = simd_normalize(simd_cross(simd_float3(0, 1, 0), direction))
            
            // Calculate plane equation ax + by + cz + d = 0
            let d = -simd_dot(normal, start)
            self.planeEquation = simd_float4(normal.x, normal.y, normal.z, d)
        }
        
        /// Create wall from plane equation
        init(planeEquation: simd_float4, point: simd_float3) {
            self.planeEquation = planeEquation
            self.normal = simd_normalize(simd_float3(planeEquation.x, planeEquation.y, planeEquation.z))
            
            // We don't know the exact corners yet
            self.startCorner = point
            self.endCorner = point
        }
        
        /// Check if a point lies on this wall (within tolerance)
        func contains(point: simd_float3, tolerance: Float = 0.1) -> Bool {
            let distance = abs(planeEquation.x * point.x + 
                             planeEquation.y * point.y + 
                             planeEquation.z * point.z + 
                             planeEquation.w)
            return distance < tolerance
        }
    }
    
    // MARK: - Properties
    
    private var corners: [simd_float3] = []
    private var implicitWalls: [Wall] = []
    private var capturedWallPlanes: [simd_float4] = []
    private var floorHeight: Float = 0.0
    
    // ================================================================================
    // MARK: - Corner Management
    // ================================================================================
    
    /// Add a corner and update implicit walls
    func addCorner(_ corner: simd_float3) {
        corners.append(corner)
        updateImplicitWalls()
    }
    
    /// Update walls derived from consecutive corners
    private func updateImplicitWalls() {
        implicitWalls.removeAll()
        
        guard corners.count >= 2 else { return }
        
        // Create walls from consecutive corners
        for i in 0..<corners.count - 1 {
            let wall = Wall(from: corners[i], to: corners[i + 1])
            implicitWalls.append(wall)
        }
    }
    
    // ================================================================================
    // MARK: - Wall-Based Corner Finding
    // ================================================================================
    
    /// Find corner from two wall planes
    func findCornerFromWalls(wall1: simd_float4, wall2: simd_float4) -> simd_float3? {
        print("🔧 DEBUG: findCornerFromWalls - floor: \(floorHeight)")
        
        // Check if we can use existing corners to constrain the intersection
        if let constrainedCorner = findConstrainedIntersection(wall1, wall2) {
            // Found constrained corner
            return constrainedCorner
        }
        
        // No constrained corner, trying pure geometric intersection
        // Otherwise calculate pure geometric intersection
        let result = calculateWallIntersection(wall1, wall2)
        if let corner = result {
            print("✅ DEBUG: Calculated corner at (\(String(format: "%.2f", corner.x)), \(String(format: "%.2f", corner.z)))")
        } else {
            // Failed to calculate geometric intersection
        }
        return result
    }
    
    /// Find intersection constrained by existing geometry
    private func findConstrainedIntersection(_ wall1: simd_float4, _ wall2: simd_float4) -> simd_float3? {
        // If we have existing corners, the new corner should align with them
        guard !corners.isEmpty else { return nil }
        
        // Calculate the intersection line of the two walls
        let n1 = simd_float3(wall1.x, wall1.y, wall1.z)
        let n2 = simd_float3(wall2.x, wall2.y, wall2.z)
        
        // The intersection is a vertical line (assuming walls are vertical)
        let lineDirection = simd_normalize(simd_cross(n1, n2))
        
        // If the line is not vertical enough, calculate normally
        if abs(lineDirection.y) > 0.1 {
            return nil
        }
        
        // Find a point on the intersection line
        // Use the floor height if we have it
        let intersectionPoint = findPointOnIntersectionLine(wall1, wall2, atHeight: floorHeight)
        
        return intersectionPoint
    }
    
    /// Calculate geometric intersection of two walls at floor level
    private func calculateWallIntersection(_ wall1: simd_float4, _ wall2: simd_float4) -> simd_float3? {
        // calculateWallIntersection
        let n1 = simd_float3(wall1.x, wall1.y, wall1.z)
        let n2 = simd_float3(wall2.x, wall2.y, wall2.z)
        
        // Check if walls are parallel
        let crossProduct = simd_cross(n1, n2)
        let crossLength = simd_length_squared(crossProduct)
        // Check cross product
        
        if crossLength < 0.0001 {
            // Walls are parallel
            return nil
        }
        
        // Find intersection at floor level
        let floorNormal = simd_float3(0, 1, 0)
        let det = simd_dot(n1, simd_cross(n2, floorNormal))
        // Check determinant
        
        if abs(det) < 0.0001 {
            // Determinant too small
            return nil
        }
        
        let d1 = -wall1.w
        let d2 = -wall2.w
        let d3 = -floorHeight
        // Calculate d values
        
        let point = (d1 * simd_cross(n2, floorNormal) +
                     d2 * simd_cross(floorNormal, n1) +
                     d3 * simd_cross(n1, n2)) / det
        
        let result = simd_float3(point.x, floorHeight, point.z)
        // Calculated intersection point
        
        return result
    }
    
    /// Find a point on the intersection line of two planes at a given height
    private func findPointOnIntersectionLine(_ plane1: simd_float4, _ plane2: simd_float4, atHeight y: Float) -> simd_float3? {
        // Solve the system:
        // plane1: a1*x + b1*y + c1*z + d1 = 0
        // plane2: a2*x + b2*y + c2*z + d2 = 0
        // y = atHeight
        
        let a1 = plane1.x, b1 = plane1.y, c1 = plane1.z, d1 = plane1.w
        let a2 = plane2.x, b2 = plane2.y, c2 = plane2.z, d2 = plane2.w
        
        // Substitute y and solve for x and z
        let det = a1 * c2 - a2 * c1
        
        if abs(det) < 0.0001 {
            // Try different approach if determinant is too small
            return nil
        }
        
        let x = (c2 * (-d1 - b1 * y) - c1 * (-d2 - b2 * y)) / det
        let z = (a1 * (-d2 - b2 * y) - a2 * (-d1 - b1 * y)) / det
        
        return simd_float3(x, y, z)
    }
    
    // ================================================================================
    // MARK: - Smart Wall Detection
    // ================================================================================
    
    /// Detect if a captured wall plane aligns with existing corners
    func detectWallFromCorners(capturedPlane: simd_float4) -> Wall? {
        guard corners.count >= 2 else { return nil }
        
        let normal = simd_float3(capturedPlane.x, capturedPlane.y, capturedPlane.z)
        
        // Check which existing corners lie on this plane
        var cornersOnPlane: [simd_float3] = []
        
        for corner in corners {
            let distance = abs(capturedPlane.x * corner.x +
                             capturedPlane.y * corner.y +
                             capturedPlane.z * corner.z +
                             capturedPlane.w)
            
            if distance < 0.15 { // 15cm tolerance
                cornersOnPlane.append(corner)
            }
        }
        
        // If we have 2+ corners on this plane, we've found an existing wall
        if cornersOnPlane.count >= 2 {
            // Sort corners along the wall direction
            let sortedCorners = sortCorners(cornersOnPlane, alongPlane: normal)
            return Wall(from: sortedCorners.first!, to: sortedCorners.last!)
        }
        
        return nil
    }
    
    /// Sort corners along a wall plane
    private func sortCorners(_ corners: [simd_float3], alongPlane normal: simd_float3) -> [simd_float3] {
        guard corners.count > 1 else { return corners }
        
        // Find a direction along the plane (perpendicular to normal and up)
        let up = simd_float3(0, 1, 0)
        let alongWall = simd_normalize(simd_cross(normal, up))
        
        // Project corners onto this direction and sort
        return corners.sorted { corner1, corner2 in
            let proj1 = simd_dot(corner1, alongWall)
            let proj2 = simd_dot(corner2, alongWall)
            return proj1 < proj2
        }
    }
    
    // ================================================================================
    // MARK: - Corner Prediction
    // ================================================================================
    
    /// Predict next corner position based on existing geometry
    func predictNextCorner() -> simd_float3? {
        guard corners.count >= 2 else { return nil }
        
        // For rectangular rooms, predict based on perpendicularity
        let lastWall = Wall(from: corners[corners.count - 2], to: corners[corners.count - 1])
        
        // Common room dimensions (in meters)
        let typicalWallLengths: [Float] = [2.5, 3.0, 3.5, 4.0, 4.5, 5.0]
        
        // Try perpendicular direction
        let perpDirection = simd_float3(-lastWall.normal.z, 0, lastWall.normal.x)
        
        for length in typicalWallLengths {
            let predictedPoint = corners.last! + perpDirection * length
            
            // Check if this would close the shape nicely
            if corners.count >= 3 {
                let distanceToFirst = simd_distance(predictedPoint, corners[0])
                if distanceToFirst < 0.5 {
                    return corners[0] // Snap to first corner to close
                }
            }
            
            // Return first reasonable prediction
            if length == 3.0 || length == 4.0 {
                return predictedPoint
            }
        }
        
        return nil
    }
    
    // ================================================================================
    // MARK: - Geometry Validation
    // ================================================================================
    
    /// Check if the current corners form a valid room
    func isValidRoom() -> Bool {
        guard corners.count >= 3 else { return false }
        
        // Check if corners are roughly coplanar (on same floor)
        let heightVariation = corners.map { $0.y }.max()! - corners.map { $0.y }.min()!
        if heightVariation > 0.3 { // 30cm tolerance
            return false
        }
        
        // Check if corners form a closed shape (approximately)
        if corners.count >= 4 {
            let firstLastDistance = simd_distance(corners.first!, corners.last!)
            let totalPerimeter = zip(corners, corners.dropFirst() + [corners[0]])
                .map { simd_distance($0, $1) }
                .reduce(0, +)
            
            // If first-last distance is small relative to perimeter, it's closed
            if firstLastDistance < totalPerimeter * 0.1 {
                return true
            }
        }
        
        return true
    }
    
    // ================================================================================
    // MARK: - Public Interface
    // ================================================================================
    
    /// Get current corners
    func getCorners() -> [simd_float3] {
        return corners
    }
    
    /// Get implicit walls from corners
    func getWalls() -> [Wall] {
        return implicitWalls
    }
    
    /// Set floor height for calculations
    func setFloorHeight(_ height: Float) {
        self.floorHeight = height
    }
    
    /// Clear all geometry
    func reset() {
        corners.removeAll()
        implicitWalls.removeAll()
        capturedWallPlanes.removeAll()
        floorHeight = 0.0
    }
}