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
        
        guard let arView = arView else { 
            return 
        }
        
        // Add corner markers
        for (index, corner) in corners.enumerated() {
            addCornerMarker(at: corner, index: index, totalCorners: corners.count, arView: arView)
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
    private func addCornerMarker(at position: simd_float3, index: Int, totalCorners: Int, arView: ARView) {
        // Create much larger, more visible flat circle
        let radius: Float = 0.25  // Increased significantly
        let mesh = MeshResource.generatePlane(
            width: radius * 2,
            depth: radius * 2,
            cornerRadius: radius
        )
        
        // Brighter colors with full opacity
        let color: UIColor
        if index == 0 {
            color = UIColor.systemGreen  // Brighter green
        } else if index == totalCorners - 1 {
            color = UIColor.systemOrange  // Brighter orange for latest
        } else {
            color = UIColor.systemBlue  // Brighter blue
        }
        
        let material = SimpleMaterial(color: color, isMetallic: false)
        let circle = ModelEntity(mesh: mesh, materials: [material])
        
        // Rotate to lay flat on floor
        circle.transform.rotation = simd_quatf(angle: -.pi/2, axis: [1, 0, 0])
        
        // Add much larger number label
        let textMesh = MeshResource.generateText(
            "\(index + 1)",
            extrusionDepth: 0.03,
            font: .systemFont(ofSize: 0.3, weight: .bold),  // Much larger font
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byClipping
        )
        let textMaterial = SimpleMaterial(color: .white, isMetallic: false)
        let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])
        textEntity.position = [0, 0.05, 0]  // Higher above floor
        
        // Add a taller, thicker vertical pole
        let poleMesh = MeshResource.generateCylinder(height: 1.0, radius: 0.02)  // Taller and thicker
        let poleMaterial = SimpleMaterial(color: color.withAlphaComponent(0.8), isMetallic: false)
        let poleEntity = ModelEntity(mesh: poleMesh, materials: [poleMaterial])
        poleEntity.position = [0, 0.5, 0]  // Half height up
        
        // Add a sphere at the top of the pole for better visibility
        let sphereMesh = MeshResource.generateSphere(radius: 0.05)
        let sphereMaterial = SimpleMaterial(color: color, isMetallic: true)
        let sphereEntity = ModelEntity(mesh: sphereMesh, materials: [sphereMaterial])
        sphereEntity.position = [0, 1.0, 0]  // At top of pole
        
        // Create anchor at exact floor position
        let anchor = AnchorEntity(world: position)
        anchor.addChild(circle)
        anchor.addChild(textEntity)
        anchor.addChild(poleEntity)
        anchor.addChild(sphereEntity)
        
        // Add pop-in animation for new corners with bounce
        if index == totalCorners - 1 {
            circle.scale = [0.1, 0.1, 0.1]
            poleEntity.scale = [1, 0.1, 1]
            sphereEntity.scale = [0.1, 0.1, 0.1]
            
            // Animate scale with overshoot for bounce effect
            circle.move(to: Transform(scale: [1.2, 1.2, 1.2]), relativeTo: circle, duration: 0.2)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                circle.move(to: Transform(scale: [1, 1, 1]), relativeTo: circle, duration: 0.1)
            }
            poleEntity.move(to: Transform(scale: [1, 1, 1]), relativeTo: poleEntity, duration: 0.3)
            sphereEntity.move(to: Transform(scale: [1.2, 1.2, 1.2]), relativeTo: sphereEntity, duration: 0.3)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                sphereEntity.move(to: Transform(scale: [1, 1, 1]), relativeTo: sphereEntity, duration: 0.1)
            }
        }
        
        
        arView.scene.addAnchor(anchor)
        cornerMarkers.append(anchor)
    }
    
    /// Add a line between two points
    private func addLine(from start: simd_float3, to end: simd_float3, arView: ARView) {
        let distance = simd_distance(start, end)
        let midpoint = (start + end) / 2
        
        // Create thicker cylinder as line
        let mesh = MeshResource.generateCylinder(height: distance, radius: 0.02)  // Thicker line
        let material = SimpleMaterial(color: UIColor.systemYellow, isMetallic: false)  // Brighter yellow
        let cylinder = ModelEntity(mesh: mesh, materials: [material])
        
        // Calculate rotation
        let direction = normalize(end - start)
        let up = simd_float3(0, 1, 0)
        
        if abs(dot(direction, up)) < 0.999 {
            let rotation = simd_quatf(from: up, to: direction)
            cylinder.transform.rotation = rotation
        }
        
        // Add larger distance label
        let distanceText = String(format: "%.2fm", distance)
        let textMesh = MeshResource.generateText(
            distanceText,
            extrusionDepth: 0.01,
            font: .systemFont(ofSize: 0.1, weight: .bold),  // Larger, bold text
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byClipping
        )
        let textMaterial = SimpleMaterial(color: .white, isMetallic: false)
        let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])
        textEntity.position = [0, 0.15, 0]
        
        // Create anchor at midpoint
        let anchor = AnchorEntity(world: midpoint)
        anchor.addChild(cylinder)
        anchor.addChild(textEntity)
        
        arView.scene.addAnchor(anchor)
        lineEntities.append(anchor)
    }
}

// Helper extension already defined in RealityKitARView.swift