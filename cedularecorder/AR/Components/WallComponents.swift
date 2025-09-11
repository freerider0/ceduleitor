import RealityKit
import ARKit
import SwiftUI

// MARK: - User Selection Component
/// Minimal component - just tracks if user selected this wall
struct UserTrackedComponent: Component {
    var isTracked: Bool = false
    var trackingColor: UIColor = .white
}

// MARK: - Wall Model for UI
/// Simple model for displaying walls in the minimap
struct WallModel: Identifiable {
    let id = UUID()
    let startPoint: SIMD3<Float>
    let endPoint: SIMD3<Float>
    let color: Color
}

// That's it! Everything else comes from ARKit/RealityKit:
// - ARPlaneAnchor provides: classification, extent (width/height), identifier
// - OpacityComponent provides: opacity control  
// - ModelComponent provides: mesh and materials
// - Transform provides: position, rotation, scale