import Foundation
import UIKit

// MARK: - Room Type
/// Defines different room types with associated colors and properties
enum RoomType: String, CaseIterable, Codable {
    case livingRoom = "Living Room"
    case bedroom = "Bedroom"
    case kitchen = "Kitchen"
    case bathroom = "Bathroom"
    case office = "Office"
    case diningRoom = "Dining Room"
    case hallway = "Hallway"
    case closet = "Closet"
    case garage = "Garage"
    case other = "Other"
    
    /// Color associated with each room type
    var color: UIColor {
        switch self {
        case .livingRoom: return .systemBlue
        case .bedroom: return .systemPurple
        case .kitchen: return .systemOrange
        case .bathroom: return .systemTeal
        case .office: return .systemGreen
        case .diningRoom: return .systemYellow
        case .hallway: return .systemGray
        case .closet: return .systemBrown
        case .garage: return .systemGray2
        case .other: return .systemGray3
        }
    }
}

// MARK: - Room Transform
/// Manages position, rotation, and scale of a room
struct RoomTransform: Codable {
    var position: CGPoint = .zero
    var rotation: CGFloat = 0  // In radians
    var scale: CGFloat = 1.0
    
    /// Apply transform to a point
    func apply(to point: CGPoint) -> CGPoint {
        // Scale
        var transformed = CGPoint(x: point.x * scale, y: point.y * scale)
        
        // Rotate
        let cos = cos(rotation)
        let sin = sin(rotation)
        let rotated = CGPoint(
            x: transformed.x * cos - transformed.y * sin,
            y: transformed.x * sin + transformed.y * cos
        )
        
        // Translate
        return CGPoint(
            x: rotated.x + position.x,
            y: rotated.y + position.y
        )
    }
}

// MARK: - Constraint Types
enum CADConstraintType: String, Codable {
    // Edge constraints
    case length = "Length"
    case horizontal = "Horizontal"
    case vertical = "Vertical"
    case perpendicular = "Perpendicular"
    case parallel = "Parallel"
    case angle = "Angle"
    
    // Point constraints
    case pointOnLine = "PointOnLine"
    case pointToPointDistance = "PointToPointDistance"
    case pointToLineDistance = "PointToLineDistance"
    case coincident = "Coincident"  // Two points at same location
}

// MARK: - Point Constraint
/// Represents a constraint for a point
struct PointConstraint: Codable {
    var pointIndex: Int  // Index of the point (corner index)
    var type: CADConstraintType  // Type of constraint
    var targetValue: CGFloat?  // Target value (for distance constraints)
    var referencePointIndex: Int?  // Reference point (for point-to-point)
    var referenceEdgeIndex: Int?  // Reference edge (for point-on-line)
    var isLocked: Bool = false  // Whether this constraint is locked
    
    init(pointIndex: Int, type: CADConstraintType, 
         targetValue: CGFloat? = nil,
         referencePointIndex: Int? = nil,
         referenceEdgeIndex: Int? = nil,
         isLocked: Bool = false) {
        self.pointIndex = pointIndex
        self.type = type
        self.targetValue = targetValue
        self.referencePointIndex = referencePointIndex
        self.referenceEdgeIndex = referenceEdgeIndex
        self.isLocked = isLocked
    }
}

// MARK: - Edge Constraint
/// Represents a constraint for an edge
struct EdgeConstraint: Codable {
    var edgeIndex: Int  // Index of the edge (corner[i] to corner[i+1])
    var type: CADConstraintType  // Type of constraint
    var targetValue: CGFloat?  // Target value (for length or angle constraints)
    var referenceEdgeIndex: Int?  // Reference edge (for parallel/perpendicular)
    var isLocked: Bool = false  // Whether this constraint is locked
    
    // Legacy support
    init(edgeIndex: Int, targetLength: CGFloat, isLocked: Bool = false) {
        self.edgeIndex = edgeIndex
        self.type = .length
        self.targetValue = targetLength
        self.referenceEdgeIndex = nil
        self.isLocked = isLocked
    }
    
    // New comprehensive init
    init(edgeIndex: Int, type: CADConstraintType, targetValue: CGFloat? = nil, 
         referenceEdgeIndex: Int? = nil, isLocked: Bool = false) {
        self.edgeIndex = edgeIndex
        self.type = type
        self.targetValue = targetValue
        self.referenceEdgeIndex = referenceEdgeIndex
        self.isLocked = isLocked
    }
}

// MARK: - Room Model
/// Represents a single room in the floor plan
class CADRoom: Identifiable, Codable {
    let id: UUID
    var name: String
    var type: RoomType
    var corners: [CGPoint]  // Local coordinates
    var height: Float  // In meters
    var transform: RoomTransform
    var mediaAttachments: [MediaAttachment]
    var edgeConstraints: [EdgeConstraint] = []  // Length constraints for edges
    var pointConstraints: [PointConstraint] = []  // Point constraints
    
    /// Computed property for room area in square meters
    var area: Double {
        guard corners.count >= 3 else { return 0 }
        
        var area: Double = 0
        for i in 0..<corners.count {
            let j = (i + 1) % corners.count
            area += Double(corners[i].x * corners[j].y)
            area -= Double(corners[j].x * corners[i].y)
        }
        
        return abs(area) / 2.0 / 10000  // Convert to m²
    }
    
    /// Computed property for room perimeter in meters
    var perimeter: Double {
        guard corners.count >= 2 else { return 0 }
        
        var perimeter: Double = 0
        for i in 0..<corners.count {
            let j = (i + 1) % corners.count
            let distance = hypot(
                Double(corners[j].x - corners[i].x),
                Double(corners[j].y - corners[i].y)
            )
            perimeter += distance
        }
        
        return perimeter / 100  // Convert to meters
    }
    
    /// Get transformed corners (world coordinates)
    var transformedCorners: [CGPoint] {
        return corners.map { transform.apply(to: $0) }
    }
    
    /// Check if point is inside room (in world coordinates)
    func contains(point: CGPoint) -> Bool {
        let transformed = transformedCorners
        guard transformed.count >= 3 else { return false }
        
        var inside = false
        var p1 = transformed.last!
        
        for p2 in transformed {
            if ((p2.y > point.y) != (p1.y > point.y)) &&
               (point.x < (p1.x - p2.x) * (point.y - p2.y) / (p1.y - p2.y) + p2.x) {
                inside = !inside
            }
            p1 = p2
        }
        
        return inside
    }
    
    /// Get bounding box in world coordinates
    var boundingBox: CGRect {
        let transformed = transformedCorners
        guard !transformed.isEmpty else { return .zero }
        
        let minX = transformed.map { $0.x }.min()!
        let maxX = transformed.map { $0.x }.max()!
        let minY = transformed.map { $0.y }.min()!
        let maxY = transformed.map { $0.y }.max()!
        
        return CGRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )
    }
    
    // MARK: - Initialization
    init(name: String = "New Room",
         type: RoomType = .other,
         corners: [CGPoint] = [],
         height: Float = 2.5) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.corners = corners
        self.height = height
        self.transform = RoomTransform()
        self.mediaAttachments = []
        self.edgeConstraints = []
    }
    
    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id, name, type, corners, height, transform, mediaAttachments, edgeConstraints
    }
}