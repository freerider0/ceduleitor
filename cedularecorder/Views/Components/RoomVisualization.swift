import RealityKit
import ARKit
import simd

// ================================================================================
// MARK: - Room Visualization Component
// ================================================================================

/// Manages visualization of room corners and connecting lines
final class RoomVisualization {
    
    // MARK: - Properties
    
    private var cornerMarkers: [AnchorEntity] = []
    private var lineEntities: [AnchorEntity] = []
    private weak var arView: ARView?
    
    // MARK: - Setup
    
    func setup(in arView: ARView) {
        self.arView = arView
    }
    
    // ================================================================================
    // MARK: - Update Visualization
    // ================================================================================
    
    /// Update the complete room visualization
    func update(corners: [simd_float3], isComplete: Bool) {
        clearVisualization()
        
        guard let arView = arView else { return }
        
        // Add corner markers
        for (index, corner) in corners.enumerated() {
            addCornerMarker(at: corner, index: index, arView: arView)
        }
        
        // Add connecting lines
        if corners.count >= 2 {
            for i in 0..<corners.count - 1 {
                guard i < corners.count, i + 1 < corners.count else { continue }
                
                addLine(
                    from: corners[i],
                    to: corners[i + 1],
                    arView: arView
                )
            }
            
            // Add closing line if shape is complete
            if isComplete, corners.count >= 3,
               let first = corners.first,
               let last = corners.last {
                addLine(from: last, to: first, arView: arView)
            }
        }
    }
    
    /// Clear all visualization entities
    func clearVisualization() {
        cornerMarkers.forEach { $0.removeFromParent() }
        cornerMarkers.removeAll()
        lineEntities.forEach { $0.removeFromParent() }
        lineEntities.removeAll()
    }
    
    // ================================================================================
    // MARK: - Private Methods
    // ================================================================================
    
    /// Add a corner marker (flat circle with number)
    private func addCornerMarker(at position: simd_float3, index: Int, arView: ARView) {
        // Create flat circle
        let radius: Float = 0.1
        let mesh = MeshResource.generatePlane(
            width: radius * 2,
            depth: radius * 2,
            cornerRadius: radius
        )
        
        // Color: green for first, blue for others
        let color = index == 0 ?
            UIColor.green.withAlphaComponent(0.8) :
            UIColor.blue.withAlphaComponent(0.8)
        let material = SimpleMaterial(color: color, isMetallic: false)
        let circle = ModelEntity(mesh: mesh, materials: [material])
        
        // Rotate to lay flat
        circle.transform.rotation = simd_quatf(angle: -.pi/2, axis: [1, 0, 0])
        
        // Add number label
        let textMesh = MeshResource.generateText(
            "\(index + 1)",
            extrusionDepth: 0.01,
            font: .systemFont(ofSize: 0.15),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byClipping
        )
        let textMaterial = SimpleMaterial(color: .white, isMetallic: false)
        let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])
        textEntity.position = [0, 0.02, 0]
        
        // Create anchor
        let anchor = AnchorEntity(world: position)
        anchor.addChild(circle)
        anchor.addChild(textEntity)
        
        arView.scene.addAnchor(anchor)
        cornerMarkers.append(anchor)
    }
    
    /// Add a line between two points
    private func addLine(from start: simd_float3, to end: simd_float3, arView: ARView) {
        let distance = simd_distance(start, end)
        let midpoint = (start + end) / 2
        
        // Create cylinder as line
        let mesh = MeshResource.generateCylinder(height: distance, radius: 0.01)
        let material = SimpleMaterial(color: .yellow, isMetallic: false)
        let cylinder = ModelEntity(mesh: mesh, materials: [material])
        
        // Calculate rotation
        let direction = normalize(end - start)
        let up = simd_float3(0, 1, 0)
        
        if abs(dot(direction, up)) < 0.999 {
            let rotation = simd_quatf(from: up, to: direction)
            cylinder.transform.rotation = rotation
        }
        
        // Add distance label
        let distanceText = String(format: "%.2fm", distance)
        let textMesh = MeshResource.generateText(
            distanceText,
            extrusionDepth: 0.005,
            font: .systemFont(ofSize: 0.05),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byClipping
        )
        let textMaterial = SimpleMaterial(color: .white, isMetallic: false)
        let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])
        textEntity.position = [0, 0.1, 0]
        
        // Create anchor at midpoint
        let anchor = AnchorEntity(world: midpoint)
        anchor.addChild(cylinder)
        anchor.addChild(textEntity)
        
        arView.scene.addAnchor(anchor)
        lineEntities.append(anchor)
    }
}

// Helper extension already defined in RealityKitARView.swift