import Foundation
import UIKit

// MARK: - Room Shape Preset
/// Predefined room shapes that users can choose from
enum RoomShapePreset: String, CaseIterable {
    case rectangle = "Rectangle"
    case lShape = "L-Shape"
    case uShape = "U-Shape"
    case tShape = "T-Shape"
    case custom = "Custom"
    
    /// Icon for shape selector
    var icon: String {
        switch self {
        case .rectangle: return "rectangle"
        case .lShape: return "l.square"
        case .uShape: return "u.square"
        case .tShape: return "t.square"
        case .custom: return "scribble"
        }
    }
    
    /// Generate corners for preset shape with given size
    /// - Parameter size: Base size for the shape (width/height)
    /// - Returns: Array of corner points
    func generateCorners(size: CGFloat = 300) -> [CGPoint] {
        switch self {
        case .rectangle:
            // Simple rectangle
            return [
                CGPoint(x: 0, y: 0),
                CGPoint(x: size, y: 0),
                CGPoint(x: size, y: size),
                CGPoint(x: 0, y: size)
            ]
            
        case .lShape:
            // L-shaped room
            let halfSize = size / 2
            return [
                CGPoint(x: 0, y: 0),
                CGPoint(x: halfSize, y: 0),
                CGPoint(x: halfSize, y: halfSize),
                CGPoint(x: size, y: halfSize),
                CGPoint(x: size, y: size),
                CGPoint(x: 0, y: size)
            ]
            
        case .uShape:
            // U-shaped room
            let third = size / 3
            return [
                CGPoint(x: 0, y: 0),
                CGPoint(x: third, y: 0),
                CGPoint(x: third, y: size * 0.7),
                CGPoint(x: third * 2, y: size * 0.7),
                CGPoint(x: third * 2, y: 0),
                CGPoint(x: size, y: 0),
                CGPoint(x: size, y: size),
                CGPoint(x: 0, y: size)
            ]
            
        case .tShape:
            // T-shaped room
            let third = size / 3
            return [
                CGPoint(x: third, y: 0),
                CGPoint(x: third * 2, y: 0),
                CGPoint(x: third * 2, y: third),
                CGPoint(x: size, y: third),
                CGPoint(x: size, y: third * 2),
                CGPoint(x: third * 2, y: third * 2),
                CGPoint(x: third * 2, y: size),
                CGPoint(x: third, y: size),
                CGPoint(x: third, y: third * 2),
                CGPoint(x: 0, y: third * 2),
                CGPoint(x: 0, y: third),
                CGPoint(x: third, y: third)
            ]
            
        case .custom:
            // Empty array for custom drawing
            return []
        }
    }
    
    /// Get typical room type for this shape
    var suggestedRoomType: RoomType {
        switch self {
        case .rectangle: return .bedroom
        case .lShape: return .livingRoom
        case .uShape: return .kitchen
        case .tShape: return .hallway
        case .custom: return .other
        }
    }
}