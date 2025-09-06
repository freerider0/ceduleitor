import Foundation
import ARKit
import RealityKit
import simd

// ================================================================================
// MARK: - Data Models
// ================================================================================

/// Represents the final room shape with corners on the floor
struct RoomShape {
    let corners: [simd_float3]  // Floor-level coordinates
    let isClosed: Bool
    
    /// Calculate area using Shoelace formula
    var area: Float {
        guard corners.count >= 3 else { return 0 }
        
        var sum: Float = 0
        for i in 0..<corners.count {
            let j = (i + 1) % corners.count
            sum += corners[i].x * corners[j].z
            sum -= corners[j].x * corners[i].z
        }
        return abs(sum) / 2.0
    }
    
    /// Calculate perimeter by summing distances between corners
    var perimeter: Float {
        guard corners.count >= 2 else { return 0 }
        
        var total: Float = 0
        for i in 0..<corners.count {
            let j = (i + 1) % corners.count
            total += simd_distance(corners[i], corners[j])
        }
        return total
    }
    
    /// Get coordinates as tuples for display
    var coordinateList: [(x: Float, y: Float, z: Float)] {
        return corners.map { (x: $0.x, y: $0.y, z: $0.z) }
    }
}

/// Mode for capturing room corners
enum DetectionMode {
    case cornerPointing  // Direct pointing at corners
    case wallIntersection // Calculate intersection of walls
}

/// Current state of wall detection in wall mode
enum WallDetectionState {
    case searching        // Looking for wall
    case wallDetected     // Wall plane found
    case firstWallStored  // One wall captured, need second
    case intersectionReady // Two walls ready to calculate corner
}

/// Represents a captured wall plane
struct CapturedWall {
    let planeEquation: simd_float4  // ax + by + cz + d = 0
    let anchor: ARPlaneAnchor?
    let normal: simd_float3
    let point: simd_float3
    var isUsed: Bool = false  // Mark as used after calculating intersection
}

// ================================================================================
// MARK: - Room Shape Detector Service
// ================================================================================

/// Main service for detecting and capturing room shapes
/// Supports both direct corner pointing and wall intersection modes
class RoomShapeDetector: ObservableObject {
    
    // MARK: - Published Properties (for SwiftUI)
    
    @Published var mode: DetectionMode = .cornerPointing
    @Published var corners: [simd_float3] = []
    @Published var statusMessage: String = "Point at a corner to begin"
    @Published var canClose: Bool = false
    @Published var isComplete: Bool = false
    @Published var currentShape: RoomShape?
    @Published var wallDetectionState: WallDetectionState = .searching
    @Published var capturedWallsCount: Int = 0  // Track walls for UI feedback
    
    // Preview position for real-time feedback
    @Published var previewPosition: simd_float3?
    @Published var showPreview: Bool = false
    
    // MARK: - Private Properties
    
    private var capturedWalls: [CapturedWall] = []
    private var floorHeight: Float = 0.0
    private let closeThreshold: Float = 0.5  // Distance in meters to auto-suggest closing
    private let minPoints = 3  // Minimum corners for a valid shape
    private let geometryBuilder = RoomGeometryBuilder()  // Intelligent geometry builder
    
    // MARK: - Initialization
    
    init() {
        updateStatus()
    }
    
    // ================================================================================
    // MARK: - Public Methods
    // ================================================================================
    
    /// Reset everything for a new room capture
    func reset() {
        corners.removeAll()
        capturedWalls.removeAll()
        capturedWallsCount = 0
        floorHeight = 0.0
        statusMessage = "Point at a corner to begin"
        canClose = false
        isComplete = false
        currentShape = nil
        wallDetectionState = .searching
        previewPosition = nil
        showPreview = false
    }
    
    /// Switch between corner and wall modes (allowed anytime)
    func switchMode(_ newMode: DetectionMode) {
        mode = newMode
        updateStatus()
        
        // Reset wall state when switching modes
        if newMode == .cornerPointing {
            wallDetectionState = .searching
        }
    }
    
    // ================================================================================
    // MARK: - Preview Updates (Called every frame)
    // ================================================================================
    
    /// Update preview position based on current raycast
    /// This is called continuously to show real-time feedback
    func updatePreview(from raycastResult: ARRaycastResult?) {
        guard let result = raycastResult else {
            showPreview = false
            return
        }
        
        // Get the hit point
        let hitPoint = simd_float3(
            result.worldTransform.columns.3.x,
            result.worldTransform.columns.3.y,
            result.worldTransform.columns.3.z
        )
        
        // Update floor height from horizontal planes
        if let planeAnchor = result.anchor as? ARPlaneAnchor,
           planeAnchor.alignment == .horizontal {
            floorHeight = hitPoint.y
        }
        
        // For corner mode, show preview on floor
        if mode == .cornerPointing {
            previewPosition = simd_float3(hitPoint.x, floorHeight, hitPoint.z)
            showPreview = true
        }
    }
    
    /// Update wall detection state for visual feedback
    func updateWallDetection(wallDetected: Bool) {
        guard mode == .wallIntersection else { return }
        
        if capturedWalls.isEmpty {
            wallDetectionState = wallDetected ? .wallDetected : .searching
        } else if capturedWalls.count == 1 {
            wallDetectionState = wallDetected ? .intersectionReady : .firstWallStored
        }
    }
    
    // ================================================================================
    // MARK: - Corner Mode Methods
    // ================================================================================
    
    /// Add a corner by directly pointing at it
    func addCornerPoint(from raycastResult: ARRaycastResult) -> Bool {
        guard mode == .cornerPointing else { return false }
        
        // Get floor intersection
        let hitPoint = simd_float3(
            raycastResult.worldTransform.columns.3.x,
            raycastResult.worldTransform.columns.3.y,
            raycastResult.worldTransform.columns.3.z
        )
        
        // Update floor height if we hit a horizontal plane
        if let planeAnchor = raycastResult.anchor as? ARPlaneAnchor,
           planeAnchor.alignment == .horizontal {
            floorHeight = hitPoint.y
            geometryBuilder.setFloorHeight(floorHeight)
        }
        
        // Add corner at floor level
        let floorPoint = simd_float3(hitPoint.x, floorHeight, hitPoint.z)
        corners.append(floorPoint)
        geometryBuilder.addCorner(floorPoint)  // Update geometry builder
        
        updateStatus()
        return true
    }
    
    // ================================================================================
    // MARK: - Wall Mode Methods
    // ================================================================================
    
    /// Capture a wall plane for intersection calculation
    func captureWall(from raycastResult: ARRaycastResult) -> Bool {
        guard mode == .wallIntersection else { return false }
        
        // Check if this is a vertical plane
        guard let planeAnchor = raycastResult.anchor as? ARPlaneAnchor,
              planeAnchor.alignment == .vertical else {
            statusMessage = "Point at a wall"
            return false
        }
        
        // Extract plane information
        let transform = raycastResult.worldTransform
        let planeNormal = simd_float3(
            transform.columns.2.x,
            transform.columns.2.y,
            transform.columns.2.z
        )
        let planePoint = simd_float3(
            transform.columns.3.x,
            transform.columns.3.y,
            transform.columns.3.z
        )
        
        // Update floor height from the point
        if floorHeight == 0 {
            floorHeight = planePoint.y - 1.5 // Assume wall point is ~1.5m above floor
            geometryBuilder.setFloorHeight(floorHeight)
        }
        
        // Create plane equation: ax + by + cz + d = 0
        let d = -simd_dot(planeNormal, planePoint)
        let planeEquation = simd_float4(planeNormal.x, planeNormal.y, planeNormal.z, d)
        
        // Store the wall
        let wall = CapturedWall(
            planeEquation: planeEquation,
            anchor: planeAnchor,
            normal: planeNormal,
            point: planePoint
        )
        capturedWalls.append(wall)
        capturedWallsCount = capturedWalls.count  // Update published count
        
        // Update state based on number of walls captured
        if capturedWalls.count == 1 {
            wallDetectionState = .firstWallStored
            statusMessage = "First wall captured! Turn 90° to find perpendicular wall"
        } else if capturedWalls.count >= 2 {
            // Try to calculate intersection immediately
            if let corner = tryCalculateWallIntersection() {
                corners.append(corner)
                geometryBuilder.addCorner(corner)
                statusMessage = "Corner added! (\(corners.count) total)"
                wallDetectionState = .searching  // Ready for next wall
                updateStatus()
                return true
            } else {
                statusMessage = "Walls are parallel - find perpendicular wall"
                // Remove the parallel wall
                capturedWalls.removeLast()
                capturedWallsCount = capturedWalls.count  // Update count
                wallDetectionState = .firstWallStored
            }
        }
        
        updateStatus()
        return true
    }
    
    /// Try to calculate intersection from captured walls
    private func tryCalculateWallIntersection() -> simd_float3? {
        // Take the last two walls (regardless of used status)
        guard capturedWalls.count >= 2 else { return nil }
        
        let wall1 = capturedWalls[capturedWalls.count - 2]
        let wall2 = capturedWalls[capturedWalls.count - 1]
        
        // Check if walls are perpendicular (not parallel)
        let dotProduct = abs(simd_dot(wall1.normal, wall2.normal))
        if dotProduct > 0.9 {  // Walls are nearly parallel
            print("Walls are too parallel: dot product = \(dotProduct)")
            return nil
        }
        
        // Use geometry builder for intelligent intersection
        guard let intersection = geometryBuilder.findCornerFromWalls(
            wall1: wall1.planeEquation,
            wall2: wall2.planeEquation
        ) else {
            print("Failed to calculate intersection")
            return nil
        }
        
        print("Successfully calculated corner at: \(intersection)")
        
        // Clear captured walls after successful intersection
        capturedWalls.removeAll()
        capturedWallsCount = 0  // Reset count
        
        return intersection
    }
    
    /// Calculate where two wall planes intersect at floor level
    private func calculateWallIntersection(_ wall1: CapturedWall, _ wall2: CapturedWall) -> simd_float3? {
        let n1 = wall1.normal
        let n2 = wall2.normal
        
        // Check if walls are parallel
        let crossProduct = simd_cross(n1, n2)
        if simd_length_squared(crossProduct) < 0.0001 {
            print("Walls are parallel - no intersection")
            return nil
        }
        
        // The intersection line direction (not needed for floor intersection)
        _ = simd_normalize(crossProduct)
        
        // Find a point on the intersection line using the plane equations
        // We need to find where the two planes and the floor plane meet
        let floorNormal = simd_float3(0, 1, 0)
        
        // Calculate the triple scalar product (determinant)
        let det = simd_dot(n1, simd_cross(n2, floorNormal))
        
        if abs(det) < 0.0001 {
            print("Cannot find unique intersection point")
            return nil
        }
        
        // Calculate intersection point using Cramer's rule
        let d1 = -wall1.planeEquation.w
        let d2 = -wall2.planeEquation.w
        let d3 = -floorHeight
        
        let point = (d1 * simd_cross(n2, floorNormal) +
                     d2 * simd_cross(floorNormal, n1) +
                     d3 * simd_cross(n1, n2)) / det
        
        // Return point at floor level
        return simd_float3(point.x, floorHeight, point.z)
    }
    
    // ================================================================================
    // MARK: - Shape Management
    // ================================================================================
    
    /// Update status message and check if shape can be closed
    private func updateStatus() {
        let pointCount = corners.count
        
        if pointCount == 0 {
            statusMessage = mode == .cornerPointing ? 
                "Point at a corner to begin" : 
                "Point at a wall to begin"
            canClose = false
        } else if pointCount < minPoints {
            let remaining = minPoints - pointCount
            statusMessage = "Add \(remaining) more point\(remaining == 1 ? "" : "s")"
            canClose = false
        } else {
            canClose = true
            
            // Check if close to first point
            if let last = corners.last, let first = corners.first {
                let distance = simd_distance(last, first)
                if distance < closeThreshold {
                    statusMessage = "Near start - tap 'Close' to complete"
                } else {
                    statusMessage = mode == .cornerPointing ?
                        "Add corner or close shape" :
                        "Add wall intersection or close shape"
                }
            }
        }
    }
    
    /// Close the shape and finalize
    func closeShape() {
        guard canClose else { return }
        
        currentShape = RoomShape(
            corners: corners,
            isClosed: true
        )
        
        isComplete = true
        statusMessage = "Room captured! Area: \(String(format: "%.1f", currentShape?.area ?? 0))m²"
    }
    
    /// Remove the last added corner
    func undoLastPoint() {
        guard !corners.isEmpty else { return }
        corners.removeLast()
        updateStatus()
    }
    
    // ================================================================================
    // MARK: - Display Helpers
    // ================================================================================
    
    /// Get formatted coordinate display text
    func getCoordinateDisplay() -> String {
        guard let shape = currentShape else { return "No shape captured" }
        
        var result = "Room Shape Coordinates:\n\n"
        
        for (index, coord) in shape.coordinateList.enumerated() {
            result += String(format: "Corner %d: (%.2f, %.2f, %.2f)m\n", 
                           index + 1, coord.x, coord.y, coord.z)
        }
        
        result += String(format: "\nArea: %.2f m²\n", shape.area)
        result += String(format: "Perimeter: %.2f m\n", shape.perimeter)
        
        return result
    }
}